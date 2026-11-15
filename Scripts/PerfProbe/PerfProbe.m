// PerfProbe: a frame-time probe for any of the v57 Mac apps, loaded with DYLD_INSERT_LIBRARIES (a build without the
// hardened runtime: Debug, or ENABLE_HARDENED_RUNTIME=NO). It needs nothing from the app.
//
// It watches the main run loop: every stretch the main thread spends awake (from waking to going back to sleep, so
// a frame's SwiftUI update, layout and Core Animation commit count) is one iteration. Runs that scroll record every
// iteration; other work is recorded as stalls (iterations over the threshold) under the last mark.
//
// Commands arrive as a distributed notification named `dev.v57.perfprobe.<pid>` whose object is the command
// (Scripts/perf.sh posts them). Results go to the path the command names, or to the app's temporary folder when it
// can't write there (a sandboxed app), and end with a line `DONE`.
//
//   list:<path>                        windows and scroll views (index, frame, content size, document class)
//   scroll:<sv>:<pt per tick>:<ticks>:<path>   steady scroll of scroll view <sv> by wheel events at 120 Hz
//   walk:<sv>:<pt per tick>:<path>     scroll to the end and back at 120 Hz (stops after 20000 ticks)
//   fling:<sv>:<start pt>:<flings>:<path>     flings: a speed that decays by 5% a tick, down then up, repeated
//                                      (each fling down and up takes about 3 s at 8000 pt: keep <flings> small)
//   stop                               ends the running scroll, walk or fling (its report is written)
//   place:off | place:<x>,<y>          moves the main window (off: past the screens, out of the pointer's reach)
//   insert:<text> / delete             types into the main window's first responder (insertText:, deleteBackward:)
//   reset / mark:<name> / threshold:<ms> / report:<path>   stalls of whatever runs between (an app's hooks, clicks)
//   idle:<seconds>:<path>              CPU time (all threads) and main-thread wakeups over that time
//   layout:<path>                      time of one forced layout and display of every window
//   views:<path>                       NSViews in each window by class (SwiftUI hosts one per platform view)
//   select:<table index>:<row>         selects a row of the n-th NSTableView/NSOutlineView (a List)
//   size:<width>x<height>              the main window's content size
//   mode:direct|wheel                  scroll by setting the clip view's offset (default: what a trackpad's scroll ends
//                                      in, SwiftUI's update and layout for it) or with trackpad-phased wheel events
//
// Wheel events (2026-11-15, macOS 27) don't work off-screen: phaseless ones are smoothed by AppKit on the display
// link, which runs slowly then, and phased ones barely moved a SwiftUI scroll view; so runs set the offset.
//
// <sv> is an index from `list`, or `main` (the largest vertical scroll view that can scroll).

#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import <mach/mach.h>
#import <sys/resource.h>

static const double kFrameMs = 1000.0 / 120.0;

@interface PerfProbe : NSObject
@end

static NSTextView *PPFirstEditableTextView(NSView *view) {
  if ([view isKindOfClass:[NSTextView class]] && ((NSTextView *)view).isEditable && !view.isHiddenOrHasHiddenAncestor)
    return (NSTextView *)view;
  for (NSView *sub in view.subviews) {
    NSTextView *found = PPFirstEditableTextView(sub);
    if (found) return found;
  }
  return nil;
}

@implementation PerfProbe {
  double _awakeSince;
  double _threshold;
  NSString *_mark;
  double _resetAt;
  NSMutableArray<NSDictionary *> *_stalls;
  NSInteger _iterations;
  double _awakeTotal;
  // A scroll run.
  NSMutableArray<NSNumber *> *_runTimes;  // iteration ms while a run goes
  NSTimer *_timer;
  NSScrollView *_target;
  NSString *_runPath;
  NSString *_runKind;
  double _step;
  double _velocity;
  NSInteger _ticks;
  NSInteger _ticksLeft;
  NSInteger _flingsLeft;
  int _direction;
  double _remainder;
  double _startOffset;
  double _maxOffset;
  double _travelled;
  double _runStarted;
  BOOL _reachedEnd;
  BOOL _direct;      // set the offset (default) instead of sending wheel events (`mode:wheel`)
  int _phase;        // the next wheel event's phase: 0 none sent yet, 1 began, 2 changed
  BOOL _momentum;    // a fling's momentum part
  NSInteger _dragTicks;
}

+ (instancetype)shared {
  static PerfProbe *probe;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ probe = [PerfProbe new]; });
  return probe;
}

- (instancetype)init {
  self = [super init];
  _threshold = kFrameMs + 0.5;
  _mark = @"";
  _direct = YES;
  _stalls = [NSMutableArray array];
  _resetAt = CACurrentMediaTime();
  return self;
}

- (void)install {
  CFRunLoopObserverRef wake = CFRunLoopObserverCreateWithHandler(
      // A pass that starts without having slept (the outer loop going on after a nested one returned) counts too.
      NULL, kCFRunLoopAfterWaiting | kCFRunLoopBeforeTimers | kCFRunLoopBeforeSources, true, LONG_MIN,
      ^(CFRunLoopObserverRef o, CFRunLoopActivity a) {
        if (a == kCFRunLoopAfterWaiting || self->_awakeSince == 0) self->_awakeSince = CACurrentMediaTime();
      });
  // Only going to sleep ends an iteration: a nested run loop's exit used to, and the work after it on the same pass
  // (Markdown parsing a 3.5 MB note for 86 s as an open event's document came in) went uncounted.
  CFRunLoopObserverRef sleep = CFRunLoopObserverCreateWithHandler(
      NULL, kCFRunLoopBeforeWaiting, true, LONG_MAX,
      ^(CFRunLoopObserverRef o, CFRunLoopActivity a) { [self wentToSleep]; });
  CFRunLoopAddObserver(CFRunLoopGetMain(), wake, kCFRunLoopCommonModes);
  CFRunLoopAddObserver(CFRunLoopGetMain(), sleep, kCFRunLoopCommonModes);
  NSString *name = [NSString stringWithFormat:@"dev.v57.perfprobe.%d", getpid()];
  [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                      selector:@selector(received:)
                                                          name:name
                                                        object:nil
                                            suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
  fprintf(stderr, "PerfProbe: listening on %s\n", name.UTF8String);
}

- (void)wentToSleep {
  if (_awakeSince == 0) return;
  double now = CACurrentMediaTime();
  double ms = (now - _awakeSince) * 1000;
  double since = _awakeSince;
  _awakeSince = 0;
  _iterations += 1;
  _awakeTotal += ms;
  if (_runTimes) [_runTimes addObject:@(ms)];
  if (ms > _threshold) {
    [_stalls addObject:@{@"mark" : _mark, @"at" : @(round((since - _resetAt) * 1000)), @"ms" : @(round(ms * 10) / 10)}];
  }
}

- (void)received:(NSNotification *)note {
  NSString *command = [note.object isKindOfClass:NSString.class] ? note.object : @"";
  [self run:command];
}

// MARK: - Commands

- (void)run:(NSString *)command {
  NSArray<NSString *> *parts = [command componentsSeparatedByString:@":"];
  NSString *verb = parts.firstObject;
  NSString *(^arg)(NSUInteger) = ^NSString *(NSUInteger i) { return i < parts.count ? parts[i] : @""; };
  // The path is everything after the fixed arguments (a path may hold no colon here, but stay safe).
  NSString *(^tail)(NSUInteger) = ^NSString *(NSUInteger i) {
    return i < parts.count ? [[parts subarrayWithRange:NSMakeRange(i, parts.count - i)] componentsJoinedByString:@":"]
                           : @"";
  };
  if ([verb isEqual:@"reset"]) {
    [_stalls removeAllObjects];
    _iterations = 0;
    _awakeTotal = 0;
    _resetAt = CACurrentMediaTime();
    _mark = @"";
  } else if ([verb isEqual:@"mark"]) {
    _mark = tail(1);
  } else if ([verb isEqual:@"threshold"]) {
    _threshold = arg(1).doubleValue ?: _threshold;
  } else if ([verb isEqual:@"report"]) {
    [self reportStalls:tail(1)];
  } else if ([verb isEqual:@"list"]) {
    [self list:tail(1)];
  } else if ([verb isEqual:@"scroll"]) {
    [self startRun:@"scroll" view:arg(1) step:arg(2).doubleValue ticks:arg(3).integerValue path:tail(4)];
  } else if ([verb isEqual:@"walk"]) {
    [self startRun:@"walk" view:arg(1) step:arg(2).doubleValue ticks:20000 path:tail(3)];
  } else if ([verb isEqual:@"fling"]) {
    _flingsLeft = MAX(1, arg(3).integerValue);
    [self startRun:@"fling" view:arg(1) step:arg(2).doubleValue ticks:100000 path:tail(4)];
  } else if ([verb isEqual:@"insert"] || [verb isEqual:@"delete"]) {
    // As a key press types into the main window's first responder (a text view's insertText: and deleteBackward:).
    NSWindow *window = [self mainWindow];
    NSResponder *responder = window.firstResponder;
    if (![responder isKindOfClass:[NSTextView class]]) {
      // A background window has no focused editor: the first editable text view takes the focus (NSResponder's own
      // insertText: would only pass the text up the chain).
      NSTextView *editor = PPFirstEditableTextView(window.contentView);
      if (editor && [window makeFirstResponder:editor]) responder = editor;
    }
    if ([verb isEqual:@"insert"]) {
      if ([responder respondsToSelector:@selector(insertText:)]) [(id)responder insertText:tail(1)];
    } else {
      [responder tryToPerform:@selector(deleteBackward:) with:nil];
    }
  } else if ([verb isEqual:@"stop"]) {
    if (_timer) [self finishRun];
  } else if ([verb isEqual:@"mode"]) {
    _direct = ![arg(1) isEqual:@"wheel"];
  } else if ([verb isEqual:@"idle"]) {
    [self idle:arg(1).doubleValue path:tail(2)];
  } else if ([verb isEqual:@"views"]) {
    [self views:tail(1)];
  } else if ([verb isEqual:@"layout"]) {
    [self layout:tail(1)];
  } else if ([verb isEqual:@"select"]) {
    [self select:arg(1).integerValue row:arg(2).integerValue];
  } else if ([verb isEqual:@"size"]) {
    NSArray *wh = [arg(1) componentsSeparatedByString:@"x"];
    NSWindow *window = [self mainWindow];
    if (wh.count == 2 && window) [window setContentSize:NSMakeSize([wh[0] doubleValue], [wh[1] doubleValue])];
  } else if ([verb isEqual:@"place"]) {
    // `place off` puts the window past every screen's right edge, where no pointer reaches it: hover follows the
    // user's pointer, which made runs differ by where it rested. `place <x>,<y>` puts its origin there.
    NSWindow *window = [self mainWindow];
    NSPoint origin = NSZeroPoint;
    if ([arg(1) isEqual:@"off"]) {
      CGFloat right = 0;
      for (NSScreen *screen in NSScreen.screens) right = MAX(right, NSMaxX(screen.frame));
      origin = NSMakePoint(right + 400, 0);
    } else {
      NSArray *xy = [arg(1) componentsSeparatedByString:@","];
      if (xy.count == 2) origin = NSMakePoint([xy[0] doubleValue], [xy[1] doubleValue]);
    }
    [window setFrameOrigin:origin];
  }
}

- (void)write:(NSString *)text to:(NSString *)path {
  NSString *body = [text stringByAppendingString:@"DONE\n"];
  NSError *error;
  if (path.length && [body writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error]) return;
  NSString *fallback = [NSTemporaryDirectory()
      stringByAppendingPathComponent:path.length ? path.lastPathComponent : @"perfprobe.txt"];
  [body writeToFile:fallback atomically:YES encoding:NSUTF8StringEncoding error:nil];
  fprintf(stderr, "PerfProbe: wrote %s\n", fallback.UTF8String);
}

// MARK: - Windows and scroll views

- (NSArray<NSWindow *> *)windows {
  NSMutableArray *found = [NSMutableArray array];
  for (NSWindow *window in NSApp.orderedWindows) {
    if (window.isVisible && window.contentView && ![window isKindOfClass:NSPanel.class]) [found addObject:window];
  }
  return found;
}

- (NSWindow *)mainWindow {
  NSWindow *best;
  for (NSWindow *window in [self windows]) {
    if (!best || window.frame.size.width * window.frame.size.height > best.frame.size.width * best.frame.size.height)
      best = window;
  }
  return best;
}

- (NSArray<NSScrollView *> *)scrollViews {
  NSMutableArray *found = [NSMutableArray array];
  __block void (^collect)(NSView *);
  __block __weak void (^weakCollect)(NSView *);
  collect = ^(NSView *view) {
    if ([view isKindOfClass:NSScrollView.class]) {
      NSScrollView *scroll = (NSScrollView *)view;
      if (!scroll.isHiddenOrHasHiddenAncestor && scroll.documentView && scroll.bounds.size.width >= 40 &&
          scroll.bounds.size.height >= 40)
        [found addObject:scroll];
    }
    for (NSView *sub in view.subviews) weakCollect(sub);
  };
  weakCollect = collect;
  for (NSWindow *window in [self windows]) collect(window.contentView);
  return found;
}

// The offsets a vertical scroll view can show: from its top inset to its end.
static double Lower(NSScrollView *scroll) { return -scroll.contentView.contentInsets.top; }
static double Upper(NSScrollView *scroll) {
  NSEdgeInsets inset = scroll.contentView.contentInsets;
  return MAX(-inset.top, scroll.documentView.frame.size.height + inset.bottom - scroll.contentView.bounds.size.height);
}

static double Extent(NSScrollView *scroll) {
  NSSize content = scroll.documentView.frame.size;
  NSSize clip = scroll.contentView.bounds.size;
  NSEdgeInsets inset = scroll.contentView.contentInsets;
  return MAX(0, content.height + inset.bottom + inset.top - clip.height);
}

- (NSScrollView *)scrollView:(NSString *)which {
  NSArray<NSScrollView *> *all = [self scrollViews];
  if ([which isEqual:@"main"] || which.length == 0) {
    NSScrollView *best;
    for (NSScrollView *scroll in all) {
      if (Extent(scroll) < 20) continue;
      if (!best || scroll.bounds.size.width * scroll.bounds.size.height >
                       best.bounds.size.width * best.bounds.size.height)
        best = scroll;
    }
    return best;
  }
  NSInteger index = which.integerValue;
  return index >= 0 && index < (NSInteger)all.count ? all[index] : nil;
}

- (void)list:(NSString *)path {
  NSMutableString *text = [NSMutableString string];
  NSArray<NSWindow *> *windows = [self windows];
  for (NSWindow *window in windows) {
    [text appendFormat:@"window %ld \"%@\" %.0fx%.0f visible=%d occlusion=%lu\n", (long)window.windowNumber,
                       window.title, window.frame.size.width, window.frame.size.height, window.isVisible,
                       (unsigned long)window.occlusionState];
  }
  NSInteger i = 0;
  for (NSScrollView *scroll in [self scrollViews]) {
    NSRect frame = [scroll convertRect:scroll.bounds toView:nil];
    NSSize content = scroll.documentView.frame.size;
    NSInteger depth = 0;
    for (NSView *v = scroll.superview; v; v = v.superview)
      if ([v isKindOfClass:NSScrollView.class]) depth += 1;
    [text appendFormat:@"%ld %@ in window %ld at %.0f,%.0f %.0fx%.0f content %.0fx%.0f extent %.0f depth %ld doc %@\n",
                       (long)i, NSStringFromClass(scroll.class), (long)scroll.window.windowNumber, frame.origin.x,
                       frame.origin.y, frame.size.width, frame.size.height, content.width, content.height,
                       Extent(scroll), (long)depth, NSStringFromClass(scroll.documentView.class)];
    i += 1;
  }
  NSInteger t = 0;
  for (NSTableView *table in [self tables]) {
    [text appendFormat:@"table %ld %@ rows %ld\n", (long)t, NSStringFromClass(table.class), (long)table.numberOfRows];
    t += 1;
  }
  [self write:text to:path];
}

// MARK: - Scroll runs

- (double)offset {
  return _target.contentView.bounds.origin.y;
}

- (void)startRun:(NSString *)kind view:(NSString *)which step:(double)step ticks:(NSInteger)ticks path:(NSString *)path {
  [_timer invalidate];
  _target = [self scrollView:which];
  if (!_target) {
    [self write:[NSString stringWithFormat:@"error no scroll view %@\n", which] to:path];
    return;
  }
  _runKind = kind;
  _runPath = path;
  _step = step;
  _velocity = step;
  _dragTicks = 0;
  _ticks = 0;
  _ticksLeft = ticks;
  _direction = 1;
  _remainder = 0;
  _travelled = 0;
  _reachedEnd = NO;
  _phase = 0;
  _momentum = NO;
  _startOffset = [self offset];
  _maxOffset = _startOffset;
  _runTimes = [NSMutableArray array];
  _runStarted = CACurrentMediaTime();
  _timer = [NSTimer timerWithTimeInterval:1.0 / 120
                                   target:self
                                 selector:@selector(tick:)
                                 userInfo:nil
                                  repeats:YES];
  _timer.tolerance = 0;
  [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (void)send:(double)pixels phase:(int64_t)phase momentum:(int64_t)momentum {
  CGEventRef cg = CGEventCreateScrollWheelEvent2(NULL, kCGScrollEventUnitPixel, 2, (int32_t)-pixels, 0, 0);
  CGEventSetIntegerValueField(cg, kCGScrollWheelEventScrollPhase, phase);
  CGEventSetIntegerValueField(cg, kCGScrollWheelEventMomentumPhase, momentum);
  NSEvent *event = [NSEvent eventWithCGEvent:cg];
  CFRelease(cg);
  [_target scrollWheel:event];
}

- (void)wheel:(double)delta {
  double total = delta + _remainder;
  double pixels = trunc(total);
  _remainder = total - pixels;
  if (pixels == 0) return;
  double before = [self offset];
  if (_direct) {
    NSClipView *clip = _target.contentView;
    NSPoint origin = clip.bounds.origin;
    origin.y = MIN(MAX(origin.y + pixels, Lower(_target)), Upper(_target));
    [clip scrollToPoint:origin];
    [_target reflectScrolledClipView:clip];
  } else if (_momentum) {
    [self send:pixels phase:0 momentum:_phase == 0 ? kCGMomentumScrollPhaseBegin : kCGMomentumScrollPhaseContinue];
    _phase = 2;
  } else {
    [self send:pixels phase:_phase == 0 ? kCGScrollPhaseBegan : kCGScrollPhaseChanged momentum:0];
    _phase = 2;
  }
  _travelled += fabs([self offset] - before);
}

// Ends the gesture (or its momentum) the wheel events are part of.
- (void)endGesture {
  if (_direct || _phase == 0) return;
  if (_momentum) [self send:0 phase:0 momentum:kCGMomentumScrollPhaseEnd];
  else [self send:0 phase:kCGScrollPhaseEnded momentum:0];
  _phase = 0;
  _momentum = NO;
}

- (void)tick:(NSTimer *)timer {
  if (!_target.window || _ticksLeft <= 0) return [self finishRun];
  _ticksLeft -= 1;
  _ticks += 1;
  double offset = [self offset];
  _maxOffset = MAX(_maxOffset, offset);
  if ([_runKind isEqual:@"scroll"]) {
    [self wheel:_step];
  } else if ([_runKind isEqual:@"walk"]) {
    if (_direction == 1 && offset >= Upper(_target) - 1) {
      _direction = -1;
      _reachedEnd = YES;
      [self endGesture];
    }
    if (_direction == -1 && offset <= Lower(_target) + 0.5) return [self finishRun];
    [self wheel:_step * _direction];
  } else {  // fling
    // A flick: 4 ticks of drag at the start speed, then momentum decaying by 5% a tick; then the other way.
    if (fabs(_velocity) < 1) {
      [self endGesture];
      _direction = -_direction;
      if (_direction == 1) _flingsLeft -= 1;
      if (_flingsLeft <= 0) return [self finishRun];
      _velocity = _step;
      _dragTicks = 0;
    }
    if (_dragTicks == 4) {
      [self endGesture];
      _momentum = YES;
    }
    _dragTicks += 1;
    [self wheel:_velocity * _direction];
    if (_dragTicks > 4) _velocity *= 0.95;
  }
}

static double Percentile(NSArray<NSNumber *> *sorted, double p) {
  if (sorted.count == 0) return 0;
  NSUInteger index = MIN(sorted.count - 1, (NSUInteger)floor(p * (sorted.count - 1) + 0.5));
  return sorted[index].doubleValue;
}

- (NSString *)summary:(NSArray<NSNumber *> *)times {
  NSArray *sorted = [times sortedArrayUsingSelector:@selector(compare:)];
  NSInteger over = 0, over16 = 0;
  double total = 0;
  for (NSNumber *n in times) {
    total += n.doubleValue;
    if (n.doubleValue > kFrameMs) over += 1;
    if (n.doubleValue > 2 * kFrameMs) over16 += 1;
  }
  return [NSString stringWithFormat:@"iterations %lu p50 %.2f p95 %.2f p99 %.2f max %.2f ms, over 8.3 ms %ld, over 16.7 ms %ld, "
                                    @"awake %.0f ms",
                                    (unsigned long)times.count, Percentile(sorted, 0.5), Percentile(sorted, 0.95),
                                    Percentile(sorted, 0.99), Percentile(sorted, 1), (long)over, (long)over16, total];
}

- (void)finishRun {
  [self endGesture];
  [_timer invalidate];
  _timer = nil;
  NSArray *times = _runTimes ?: @[];
  _runTimes = nil;
  double seconds = CACurrentMediaTime() - _runStarted;
  NSSize content = _target.documentView.frame.size;
  NSMutableString *text = [NSMutableString string];
  [text appendFormat:@"%@ ticks %ld in %.2f s, travelled %.0f pt (offset %.0f → %.0f, max %.0f, extent %.0f, content "
                     @"%.0fx%.0f)%@\n",
                     _runKind, (long)_ticks, seconds, _travelled, _startOffset, [self offset], _maxOffset,
                     Extent(_target), content.width, content.height,
                     [_runKind isEqual:@"walk"] && !_reachedEnd ? @" [did not reach the end]" : @""];
  [text appendFormat:@"%@\n", [self summary:times]];
  // The worst iterations in order of time, to tell a one-off from a pattern.
  NSMutableArray *worst = [NSMutableArray array];
  [times enumerateObjectsUsingBlock:^(NSNumber *n, NSUInteger i, BOOL *stop) {
    if (n.doubleValue > kFrameMs) [worst addObject:[NSString stringWithFormat:@"#%lu %.1f", (unsigned long)i, n.doubleValue]];
  }];
  if (worst.count) [text appendFormat:@"over: %@\n", [[worst subarrayWithRange:NSMakeRange(0, MIN(worst.count, 60))] componentsJoinedByString:@" "]];
  NSString *path = _runPath;
  _target = nil;
  [self write:text to:path];
}

// MARK: - Stalls, idle, layout

- (void)reportStalls:(NSString *)path {
  NSMutableString *text = [NSMutableString string];
  double total = 0;
  NSMutableDictionary<NSString *, NSMutableArray *> *byMark = [NSMutableDictionary dictionary];
  NSMutableArray *order = [NSMutableArray array];
  for (NSDictionary *stall in _stalls) {
    NSString *mark = stall[@"mark"];
    if (!byMark[mark]) {
      byMark[mark] = [NSMutableArray array];
      [order addObject:mark];
    }
    [byMark[mark] addObject:stall];
    total += [stall[@"ms"] doubleValue];
  }
  [text appendFormat:@"iterations %ld awake %.0f ms stalls %lu (%.0f ms)\n", (long)_iterations, _awakeTotal,
                     (unsigned long)_stalls.count, total];
  for (NSString *mark in order) {
    double sum = 0, worst = 0;
    NSMutableArray *list = [NSMutableArray array];
    for (NSDictionary *stall in byMark[mark]) {
      double ms = [stall[@"ms"] doubleValue];
      sum += ms;
      worst = MAX(worst, ms);
      [list addObject:[NSString stringWithFormat:@"%.1f", ms]];
    }
    [text appendFormat:@"%@: %lu stalls, %.0f ms, worst %.1f [%@]\n", mark.length ? mark : @"-",
                       (unsigned long)byMark[mark].count, sum, worst,
                       [[list subarrayWithRange:NSMakeRange(0, MIN(list.count, 40))] componentsJoinedByString:@" "]];
  }
  [self write:text to:path];
}

static double ProcessCPUSeconds(void) {
  struct rusage usage;
  getrusage(RUSAGE_SELF, &usage);
  return usage.ru_utime.tv_sec + usage.ru_utime.tv_usec / 1e6 + usage.ru_stime.tv_sec + usage.ru_stime.tv_usec / 1e6;
}

- (void)idle:(double)seconds path:(NSString *)path {
  double cpu = ProcessCPUSeconds();
  NSInteger iterations = _iterations;
  double awake = _awakeTotal;
  double started = CACurrentMediaTime();
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    double elapsed = CACurrentMediaTime() - started;
    double used = ProcessCPUSeconds() - cpu;
    NSString *text = [NSString
        stringWithFormat:@"idle %.1f s: CPU %.1f%% (%.0f ms, all threads), main-thread wakeups %.1f/s, main awake %.0f ms\n",
                         elapsed, used / elapsed * 100, used * 1000, (self->_iterations - iterations) / elapsed,
                         self->_awakeTotal - awake];
    [self write:text to:path];
  });
}

- (void)layout:(NSString *)path {
  NSMutableString *text = [NSMutableString string];
  for (NSWindow *window in [self windows]) {
    double start = CACurrentMediaTime();
    [window.contentView setNeedsLayout:YES];
    [window layoutIfNeeded];
    double laid = CACurrentMediaTime();
    [window.contentView setNeedsDisplay:YES];
    [window displayIfNeeded];
    double done = CACurrentMediaTime();
    [text appendFormat:@"window \"%@\": layout %.1f ms, display %.1f ms\n", window.title, (laid - start) * 1000,
                       (done - laid) * 1000];
  }
  [self write:text to:path];
}

- (void)views:(NSString *)path {
  NSMutableString *text = [NSMutableString string];
  for (NSWindow *window in [self windows]) {
    NSCountedSet *classes = [NSCountedSet set];
    __block NSInteger total = 0;
    __block void (^walk)(NSView *);
    __block __weak void (^weakWalk)(NSView *);
    walk = ^(NSView *view) {
      total += 1;
      [classes addObject:NSStringFromClass(view.class)];
      for (NSView *sub in view.subviews) weakWalk(sub);
    };
    weakWalk = walk;
    walk(window.contentView.superview ?: window.contentView);
    [text appendFormat:@"window \"%@\": %ld views\n", window.title, (long)total];
    NSArray *sorted = [classes.allObjects sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
      return [@([classes countForObject:b]) compare:@([classes countForObject:a])];
    }];
    for (NSString *name in [sorted subarrayWithRange:NSMakeRange(0, MIN(sorted.count, 25))])
      [text appendFormat:@"%6lu %@\n", (unsigned long)[classes countForObject:name], name];
  }
  [self write:text to:path];
}

- (NSArray<NSTableView *> *)tables {
  NSMutableArray *found = [NSMutableArray array];
  for (NSScrollView *scroll in [self scrollViews]) {
    if ([scroll.documentView isKindOfClass:NSTableView.class]) [found addObject:scroll.documentView];
  }
  return found;
}

- (void)select:(NSInteger)index row:(NSInteger)row {
  NSArray<NSTableView *> *tables = [self tables];
  if (index < 0 || index >= (NSInteger)tables.count) return;
  NSTableView *table = tables[index];
  if (row < 0 || row >= table.numberOfRows) return;
  [table selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
  [table scrollRowToVisible:row];
}

@end

__attribute__((constructor)) static void PerfProbeLoad(void) {
  // Only in apps: the injected variable reaches helper tools the app starts too.
  if (![[NSBundle mainBundle].bundlePath hasSuffix:@".app"]) return;
  dispatch_async(dispatch_get_main_queue(), ^{ [[PerfProbe shared] install]; });
}
