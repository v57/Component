// PerfProbeIOS: PerfProbe for apps in the iOS Simulator, loaded with SIMCTL_CHILD_DYLD_INSERT_LIBRARIES (any Debug
// build). It needs nothing from the app and never touches the Mac's screen or pointer.
//
// As on the Mac, every stretch the main thread spends awake (from waking to going back to sleep: a frame's SwiftUI
// update, layout and Core Animation commit) is one iteration, and a run records each iteration while it scrolls.
//
// A simulated app can't get the Mac's distributed notifications, so commands go through a file: Scripts/perf-ios.sh
// writes the command to /tmp/perfprobe-ios/<pid>.cmd and posts the Darwin notification `dev.v57.perfprobe` inside the
// simulator (`simctl spawn <udid> notifyutil -p`). Results go to the path the command names and end with `DONE`.
//
//   list:<path>                                  windows and scroll views (index, frame, content size, class)
//   scroll:<sv>:<pt per tick>:<ticks>:<path>     steady scroll of scroll view <sv> at 120 Hz (sets the offset)
//   walk:<sv>:<pt per tick>:<path>               to the end and back at 120 Hz (stops after 20000 ticks)
//   idle:<seconds>:<path>                        CPU time (all threads) and main-thread wakeups over that time
//
// <sv> is an index from `list`, or `main` (the largest vertical scroll view that can scroll).

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <notify.h>
#import <sys/resource.h>

static const double kFrameMs = 1000.0 / 120.0;

@interface PerfProbeIOS : NSObject
@end

@implementation PerfProbeIOS {
  double _awakeSince;
  NSInteger _iterations;
  double _awakeTotal;
  NSMutableArray<NSNumber *> *_runTimes;
  NSTimer *_timer;
  __weak UIScrollView *_target;
  NSString *_runKind;
  NSString *_runPath;
  double _step;
  NSInteger _ticksLeft;
  NSInteger _ticks;
  NSInteger _direction;
  BOOL _reachedEnd;
  double _startOffset;
  double _maxOffset;
  double _travelled;
  double _runStarted;
  int _token;
}

+ (instancetype)shared {
  static PerfProbeIOS *probe;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ probe = [PerfProbeIOS new]; });
  return probe;
}

- (void)install {
  CFRunLoopObserverRef wake = CFRunLoopObserverCreateWithHandler(
      NULL, kCFRunLoopAfterWaiting | kCFRunLoopBeforeTimers | kCFRunLoopBeforeSources, true, LONG_MIN,
      ^(CFRunLoopObserverRef o, CFRunLoopActivity a) {
        if (a == kCFRunLoopAfterWaiting || self->_awakeSince == 0) self->_awakeSince = CACurrentMediaTime();
      });
  CFRunLoopObserverRef sleep = CFRunLoopObserverCreateWithHandler(
      NULL, kCFRunLoopBeforeWaiting, true, LONG_MAX,
      ^(CFRunLoopObserverRef o, CFRunLoopActivity a) { [self wentToSleep]; });
  CFRunLoopAddObserver(CFRunLoopGetMain(), wake, kCFRunLoopCommonModes);
  CFRunLoopAddObserver(CFRunLoopGetMain(), sleep, kCFRunLoopCommonModes);
  notify_register_dispatch("dev.v57.perfprobe", &_token, dispatch_get_main_queue(), ^(int token) {
    NSString *file = [NSString stringWithFormat:@"/tmp/perfprobe-ios/%d.cmd", getpid()];
    NSString *command = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
    if (!command.length) return;
    [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
    [self run:[command stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
  });
  fprintf(stderr, "PerfProbeIOS: listening (pid %d)\n", getpid());
}

- (void)wentToSleep {
  if (_awakeSince == 0) return;
  double ms = (CACurrentMediaTime() - _awakeSince) * 1000;
  _awakeSince = 0;
  _iterations += 1;
  _awakeTotal += ms;
  if (_runTimes) [_runTimes addObject:@(ms)];
}

- (void)run:(NSString *)command {
  NSArray<NSString *> *parts = [command componentsSeparatedByString:@":"];
  NSString *verb = parts.firstObject;
  NSString *(^arg)(NSUInteger) = ^NSString *(NSUInteger i) { return i < parts.count ? parts[i] : @""; };
  NSString *(^tail)(NSUInteger) = ^NSString *(NSUInteger i) {
    return i < parts.count ? [[parts subarrayWithRange:NSMakeRange(i, parts.count - i)] componentsJoinedByString:@":"]
                           : @"";
  };
  if ([verb isEqual:@"list"]) {
    [self list:tail(1)];
  } else if ([verb isEqual:@"scroll"]) {
    [self startRun:@"scroll" view:arg(1) step:arg(2).doubleValue ticks:arg(3).integerValue path:tail(4)];
  } else if ([verb isEqual:@"walk"]) {
    [self startRun:@"walk" view:arg(1) step:arg(2).doubleValue ticks:20000 path:tail(3)];
  } else if ([verb isEqual:@"idle"]) {
    [self idle:arg(1).doubleValue path:tail(2)];
  }
}

- (void)write:(NSString *)text to:(NSString *)path {
  [[text stringByAppendingString:@"DONE\n"] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

// MARK: - Views

- (NSArray<UIWindow *> *)windows {
  NSMutableArray *windows = [NSMutableArray array];
  for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
    if (![scene isKindOfClass:UIWindowScene.class]) continue;
    for (UIWindow *window in ((UIWindowScene *)scene).windows) {
      if (!window.hidden) [windows addObject:window];
    }
  }
  return windows;
}

static void Collect(UIView *view, NSMutableArray *into) {
  if (view.hidden || view.alpha < 0.01) return;
  if ([view isKindOfClass:UIScrollView.class]) [into addObject:view];
  for (UIView *sub in view.subviews) Collect(sub, into);
}

- (NSArray<UIScrollView *> *)scrollViews {
  NSMutableArray *views = [NSMutableArray array];
  for (UIWindow *window in [self windows]) Collect(window, views);
  return views;
}

static double Lower(UIScrollView *s) { return -s.adjustedContentInset.top; }
static double Upper(UIScrollView *s) {
  return MAX(Lower(s), s.contentSize.height + s.adjustedContentInset.bottom - s.bounds.size.height);
}
static double Extent(UIScrollView *s) { return Upper(s) - Lower(s); }

- (UIScrollView *)scrollView:(NSString *)which {
  NSArray *views = [self scrollViews];
  if ([which isEqual:@"main"]) {
    UIScrollView *best = nil;
    for (UIScrollView *s in views) {
      if (Extent(s) > (best ? Extent(best) : 0)) best = s;
    }
    return best;
  }
  NSInteger index = which.integerValue;
  return index >= 0 && index < (NSInteger)views.count ? views[index] : nil;
}

- (void)list:(NSString *)path {
  NSMutableString *text = [NSMutableString string];
  for (UIWindow *window in [self windows]) {
    [text appendFormat:@"window %@ %.0fx%.0f key=%d\n", NSStringFromClass(window.class), window.bounds.size.width,
                       window.bounds.size.height, window.isKeyWindow];
  }
  [[self scrollViews] enumerateObjectsUsingBlock:^(UIScrollView *s, NSUInteger i, BOOL *stop) {
    CGRect frame = [s convertRect:s.bounds toView:nil];
    [text appendFormat:@"%lu %@ at %.0f,%.0f %.0fx%.0f content %.0fx%.0f extent %.0f\n", (unsigned long)i,
                       NSStringFromClass(s.class), frame.origin.x, frame.origin.y, frame.size.width,
                       frame.size.height, s.contentSize.width, s.contentSize.height, Extent(s)];
  }];
  [self write:text to:path];
}

// MARK: - Runs

- (void)startRun:(NSString *)kind view:(NSString *)which step:(double)step ticks:(NSInteger)ticks path:(NSString *)path {
  UIScrollView *target = [self scrollView:which];
  if (!target) return [self write:@"no such scroll view\n" to:path];
  _target = target;
  _runKind = kind;
  _runPath = path;
  _step = step;
  _ticksLeft = ticks;
  _ticks = 0;
  _direction = 1;
  _reachedEnd = NO;
  _startOffset = target.contentOffset.y;
  _maxOffset = _startOffset;
  _travelled = 0;
  _runTimes = [NSMutableArray array];
  _runStarted = CACurrentMediaTime();
  _timer = [NSTimer timerWithTimeInterval:1.0 / 120 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
  [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (void)move:(double)delta {
  UIScrollView *s = _target;
  double from = s.contentOffset.y;
  double to = MIN(MAX(from + delta, Lower(s)), Upper(s));
  [s setContentOffset:CGPointMake(s.contentOffset.x, to) animated:NO];
  _travelled += fabs(to - from);
}

- (void)tick:(NSTimer *)timer {
  UIScrollView *s = _target;
  if (!s.window || _ticksLeft <= 0) return [self finishRun];
  _ticksLeft -= 1;
  _ticks += 1;
  double offset = s.contentOffset.y;
  _maxOffset = MAX(_maxOffset, offset);
  if ([_runKind isEqual:@"walk"]) {
    if (_direction == 1 && offset >= Upper(s) - 1) {
      _direction = -1;
      _reachedEnd = YES;
    }
    if (_direction == -1 && offset <= Lower(s) + 0.5) return [self finishRun];
  }
  [self move:_step * _direction];
}

static double Percentile(NSArray<NSNumber *> *sorted, double p) {
  if (sorted.count == 0) return 0;
  NSUInteger index = MIN(sorted.count - 1, (NSUInteger)floor(p * (sorted.count - 1) + 0.5));
  return sorted[index].doubleValue;
}

- (void)finishRun {
  [_timer invalidate];
  _timer = nil;
  NSArray *times = _runTimes ?: @[];
  _runTimes = nil;
  NSArray *sorted = [times sortedArrayUsingSelector:@selector(compare:)];
  NSInteger over = 0, over16 = 0;
  double total = 0;
  for (NSNumber *n in times) {
    total += n.doubleValue;
    if (n.doubleValue > kFrameMs) over += 1;
    if (n.doubleValue > 2 * kFrameMs) over16 += 1;
  }
  UIScrollView *s = _target;
  NSMutableString *text = [NSMutableString string];
  [text appendFormat:@"%@ ticks %ld in %.2f s, travelled %.0f pt (offset %.0f → %.0f, max %.0f, extent %.0f, content "
                     @"%.0fx%.0f)%@\n",
                     _runKind, (long)_ticks, CACurrentMediaTime() - _runStarted, _travelled, _startOffset,
                     s.contentOffset.y, _maxOffset, s ? Extent(s) : 0, s.contentSize.width, s.contentSize.height,
                     [_runKind isEqual:@"walk"] && !_reachedEnd ? @" [did not reach the end]" : @""];
  [text appendFormat:@"iterations %lu p50 %.2f p95 %.2f p99 %.2f max %.2f ms, over 8.3 ms %ld, over 16.7 ms %ld, "
                     @"awake %.0f ms\n",
                     (unsigned long)times.count, Percentile(sorted, 0.5), Percentile(sorted, 0.95),
                     Percentile(sorted, 0.99), Percentile(sorted, 1), (long)over, (long)over16, total];
  NSMutableArray *worst = [NSMutableArray array];
  [times enumerateObjectsUsingBlock:^(NSNumber *n, NSUInteger i, BOOL *stop) {
    if (n.doubleValue > kFrameMs) [worst addObject:[NSString stringWithFormat:@"#%lu %.1f", (unsigned long)i, n.doubleValue]];
  }];
  if (worst.count) {
    [text appendFormat:@"over: %@\n",
                       [[worst subarrayWithRange:NSMakeRange(0, MIN(worst.count, 60))] componentsJoinedByString:@" "]];
  }
  _target = nil;
  [self write:text to:_runPath];
}

// MARK: - Idle

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
    [self write:[NSString stringWithFormat:@"idle %.1f s: CPU %.1f%% (%.0f ms, all threads), main-thread wakeups "
                                           @"%.1f/s, main awake %.0f ms\n",
                                           elapsed, used / elapsed * 100, used * 1000,
                                           (self->_iterations - iterations) / elapsed, self->_awakeTotal - awake]
             to:path];
  });
}

@end

__attribute__((constructor)) static void PerfProbeIOSLoad(void) {
  if (![[NSBundle mainBundle].bundlePath hasSuffix:@".app"]) return;
  dispatch_async(dispatch_get_main_queue(), ^{ [[PerfProbeIOS shared] install]; });
}
