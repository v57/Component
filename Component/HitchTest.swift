import SwiftUI

#if DEBUG
  import QuartzCore
  #if os(iOS)
    import UIKit
  #elseif os(macOS)
    import AppKit
  #endif

  // MARK: - Options

  /// `--hitch-test <report path>` (DEBUG): walks the catalog's pages, scrolls every scroll view on each to its end and
  /// back in real time, and writes the main-thread hitches per page to the report. `--hitch-pages a,b,c` picks the
  /// pages (`Page` raw values; all of them by default), `--hitch-speed <pt/s>` the scroll speed (1500), and
  /// `--hitch-settle <s>` how long a page must run without a hitch to count as open (1.0). `Scripts/hitch-test.sh`
  /// builds, runs and prints it.
  struct HitchTestOptions {
    var reportPath: String
    var pages: [Page]
    var unknownPages: [String] = []
    var speed = 1500.0
    var settle = 1.0
    /// Scroll with scroll-wheel events, as a trackpad does, instead of setting the offset (the Mac; `--hitch-direct`
    /// sets it). The scroll view and SwiftUI move the content themselves, so a jump is what a user would see.
    var events = true

    init?(_ arguments: [String]) {
      func value(after flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
      }
      guard let path = value(after: "--hitch-test") else { return nil }
      reportPath = path
      pages = Page.allCases
      if let list = value(after: "--hitch-pages") {
        let ids = list.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        pages = ids.compactMap(Page.init(rawValue:))
        unknownPages = ids.filter { Page(rawValue: $0) == nil }
      }
      if let speed = value(after: "--hitch-speed").flatMap(Double.init), speed > 0 { self.speed = speed }
      if let settle = value(after: "--hitch-settle").flatMap(Double.init), settle >= 0 { self.settle = settle }
      if arguments.contains("--hitch-direct") { events = false }
    }
  }

  extension View {
    /// Runs the hitch test once the window is up, when the app was launched with `--hitch-test`.
    func hitchTest(_ model: CatalogModel) -> some View {
      onAppear { HitchTest.start(model) }
    }
  }

  // MARK: - Stats

  /// Frames and hitches in one phase. A hitch is a display-link gap longer than 1.5 frames (a main-thread stall).
  struct HitchStats {
    var frames = 0
    var hitches = 0
    var missed = 0
    var hitchMs = 0.0
    var worst = 0.0

    /// Counts a gap of `gap` seconds at a frame of `frame` seconds; returns the frames it missed.
    @discardableResult mutating func hitch(gap: Double, frame: Double) -> Int {
      let missed = max(1, Int((gap / frame).rounded()) - 1)
      hitches += 1
      self.missed += missed
      hitchMs += gap * 1000
      worst = max(worst, gap * 1000)
      return missed
    }

    mutating func add(_ other: HitchStats) {
      frames += other.frames
      hitches += other.hitches
      missed += other.missed
      hitchMs += other.hitchMs
      worst = max(worst, other.worst)
    }

    var scrollSummary: String {
      "frames \(frames), hitches \(hitches), missed \(missed), worst \(ms(worst)) ms"
    }
  }

  private func ms(_ value: Double) -> String { String(format: "%.0f", value) }
  private func seconds(_ value: Double) -> String { String(format: "%.2f", value) }
  private func describe(_ rect: CGRect) -> String {
    String(format: "%.0f,%.0f %.0fx%.0f", rect.minX, rect.minY, rect.width, rect.height)
  }
  private func describe(_ size: CGSize) -> String { String(format: "%.0fx%.0f", size.width, size.height) }

  /// One entry of the report: a page (its opening and its scrolling) or the catalog's sidebar.
  @MainActor final class HitchBlock {
    let name: String
    var open: HitchStats?
    var settle: Double?
    var scroll = HitchStats()
    var scrollers = 0
    /// The window didn't show when the page opened (macOS may throttle the display link then).
    var occluded = false
    var lines: [String] = []

    init(_ name: String, opens: Bool) {
      self.name = name
      open = opens ? HitchStats() : nil
    }

    var summary: String {
      var text = name.padding(toLength: max(16, name.count + 2), withPad: " ", startingAt: 0)
      if let open {
        text += "open: \(open.hitches) hitches worst \(ms(open.worst)) ms, settled \(seconds(settle ?? 0)) s | "
      }
      return text + "scroll: \(scroll.scrollSummary) (\(scrollers) scrollers)" + (occluded ? " [window occluded]" : "")
    }
  }

  /// A scroll view being walked: down (or right) to its end and back.
  @MainActor final class HitchScroller {
    weak var view: HitchScrollView?
    let number: Int
    let vertical: Bool
    let isSidebar: Bool
    var stats = HitchStats()
    var start: CGFloat = 0
    var position: CGFloat = 0
    var towardEnd = true
    var startedAt: CFTimeInterval = 0
    var line = 0
    var notes: [String] = []
    /// Times the offset moved between frames without the test moving it (content above changed height, or the
    /// scroll view anchored it): what a user sees as the page jumping or bouncing back.
    var jumps = 0
    var jumpTotal: CGFloat = 0
    var worstJump: CGFloat = 0

    init(_ view: HitchScrollView, number: Int, vertical: Bool, isSidebar: Bool) {
      self.view = view
      self.number = number
      self.vertical = vertical
      self.isSidebar = isSidebar
    }

    var label: String { "#\(number) \(vertical ? "V" : "H")" }
  }

  // MARK: - Test

  /// Drives the hitch test from a display link: launch, then for each page open it, wait for it to settle, and scroll
  /// each of its scroll views (the sidebar once, on the first page).
  @MainActor final class HitchTest: NSObject {
    private static var current: HitchTest?

    static func start(_ model: CatalogModel) {
      guard current == nil, let options = HitchTestOptions(ProcessInfo.processInfo.arguments) else { return }
      let test = HitchTest(model: model, options: options)
      current = test
      Task { await test.run() }
    }

    private enum Stage {
      case launching, opening
      case revealing(until: CFTimeInterval)
      case scrolling, done
    }

    private let model: CatalogModel
    private let options: HitchTestOptions
    private var report: FileHandle?
    private var link: CADisplayLink?
    private weak var window: HitchWindow?
    private var stage = Stage.launching
    private var last: CFTimeInterval = 0
    private var phaseStart: CFTimeInterval = 0
    private var firstFrame: CFTimeInterval?
    private var lastHitch: CFTimeInterval?
    private var launch = HitchStats()
    private var pageIndex = -1
    private var block: HitchBlock?
    private var pageBlock: HitchBlock?
    private var queue: [HitchScroller] = []
    private var scroller: HitchScroller?
    private var finished: [HitchBlock] = []
    private var sidebarDone = false

    private init(model: CatalogModel, options: HitchTestOptions) {
      self.model = model
      self.options = options
    }

    private func run() async {
      let url = URL(fileURLWithPath: options.reportPath)
      try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      FileManager.default.createFile(atPath: url.path, contents: nil)
      report = try? FileHandle(forWritingTo: url)
      model.opensOnPage = true
      while HitchPlatform.window() == nil { try? await Task.sleep(for: .milliseconds(100)) }
      guard let window = HitchPlatform.window() else { return }
      self.window = window
      let link = HitchPlatform.displayLink(window, target: self, selector: #selector(tick(_:)))
      let fps = Float(HitchPlatform.maximumFramesPerSecond(window))
      link.preferredFrameRateRange = CAFrameRateRange(minimum: fps, maximum: fps, preferred: fps)
      link.add(to: .main, forMode: .common)
      self.link = link
      phaseStart = CACurrentMediaTime()
      var header = [
        "Component hitch test · \(HitchPlatform.device) · \(ProcessInfo.processInfo.operatingSystemVersionString)",
        "window \(describe(HitchPlatform.bounds(window).size)) · screen \(Int(fps)) Hz"
          + " · speed \(ms(options.speed)) pt/s"
          + " · settle \(seconds(options.settle)) s · \(options.pages.count) pages · \(Date().formatted(.iso8601))",
      ]
      if !options.unknownPages.isEmpty {
        header.append("WARNING: unknown pages \(options.unknownPages.joined(separator: ","))")
      }
      write(header + [""])
    }

    @objc private func tick(_ link: CADisplayLink) {
      let now = link.timestamp
      var frame = link.targetTimestamp - link.timestamp
      if frame <= 0 { frame = link.duration }
      let gap = last > 0 ? now - last : 0
      last = now
      if frame > 0, gap > frame * 1.5 { hitch(gap: gap, frame: frame, at: now) }
      advance(now: now, dt: gap)
    }

    private func hitch(gap: Double, frame: Double, at now: CFTimeInterval) {
      let text =
        "\(ms(gap * 1000)) ms (\(Int((gap / frame).rounded()) - 1) missed, "
        + "frame \(String(format: "%.1f", frame * 1000)) ms)"
      switch stage {
      case .launching:
        launch.hitch(gap: gap, frame: frame)
        lastHitch = now
      case .opening:
        block?.open?.hitch(gap: gap, frame: frame)
        lastHitch = now
        block?.lines.append("  hitch open \(text) at +\(seconds(now - phaseStart)) s")
      case .revealing, .scrolling:
        guard let scroller, let block else { return }
        scroller.stats.hitch(gap: gap, frame: frame)
        let at = if case .revealing = stage { "revealing" } else { "at offset \(ms(scroller.position))" }
        block.lines.append("    hitch scroll \(scroller.label) \(text) \(at)")
      case .done:
        break
      }
    }

    private func advance(now: CFTimeInterval, dt: Double) {
      switch stage {
      case .launching:
        if settled(now) {
          var lines = [
            "launch          \(launch.hitches) hitches worst \(ms(launch.worst)) ms, settled "
              + "\(seconds((lastHitch ?? phaseStart) - phaseStart)) s"
          ]
          if let window, let warning = HitchPlatform.visibilityWarning(window) { lines.append("WARNING: \(warning)") }
          write(lines + [""])
          openNextPage()
        }
      case .opening:
        if firstFrame == nil { firstFrame = now }
        if settled(now) {
          block?.settle = (lastHitch ?? firstFrame ?? now) - phaseStart
          beginScrolling(now)
        }
      case .revealing(let until):
        if now >= until, let scroller {
          beginScroller(scroller, now: now)
        }
      case .scrolling:
        step(now: now, dt: dt)
      case .done:
        break
      }
    }

    /// The phase ran `settle` seconds without a hitch (or gave up after 10).
    private func settled(_ now: CFTimeInterval) -> Bool {
      let quiet = now - max(phaseStart, lastHitch ?? 0)
      return (quiet >= options.settle && now - phaseStart >= options.settle) || now - phaseStart > 10
    }

    // MARK: Pages

    private func openNextPage() {
      if let pageBlock { finish(pageBlock) }
      pageIndex += 1
      guard pageIndex < options.pages.count else { return complete() }
      let page = options.pages[pageIndex]
      let block = HitchBlock(page.rawValue, opens: true)
      if let window, let warning = HitchPlatform.visibilityWarning(window) {
        block.occluded = true
        block.lines.append("  WARNING: \(warning)")
      }
      self.block = block
      pageBlock = block
      lastHitch = nil
      firstFrame = nil
      stage = .opening
      phaseStart = CACurrentMediaTime()
      model.page = page
    }

    private func beginScrolling(_ now: CFTimeInterval) {
      guard let window else { return complete() }
      let windowHeight = HitchPlatform.bounds(window).height
      var found: [(view: HitchScrollView, vertical: Bool, frame: CGRect, depth: Int, sidebar: Bool)] = []
      var skipped: [String] = []
      for view in HitchPlatform.scrollViews(in: window) {
        let reason: String? =
          if !view.hitchIsShown { "hidden" } else if view.hitchAxis == nil { "fits" } else { nil }
        let frame = view.hitchFrame
        let depth = view.hitchDepth
        let sidebar = depth == 0 && frame.minX < 20 && frame.width <= 400 && frame.height >= windowHeight / 2
        if sidebar && (sidebarDone || reason != nil) { continue }
        guard reason == nil, let vertical = view.hitchAxis else {
          skipped.append(
            "  skipped \(type(of: view)) at \(describe(frame)) content \(describe(view.hitchContentSize)): "
              + (reason ?? "")
          )
          continue
        }
        found.append((view, vertical, frame, depth, sidebar))
      }
      found.sort { a, b in
        if a.sidebar != b.sidebar { return a.sidebar }
        if a.depth != b.depth { return a.depth < b.depth }
        return a.frame.minY != b.frame.minY ? a.frame.minY < b.frame.minY : a.frame.minX < b.frame.minX
      }
      queue = found.enumerated().map { index, item in
        HitchScroller(item.view, number: index + 1, vertical: item.vertical, isSidebar: item.sidebar)
      }
      let sidebars = found.filter(\.sidebar).count
      pageBlock?.lines.append(
        "  found \(found.count - sidebars) scrollers\(sidebars > 0 ? " and the catalog sidebar" : "")")
      pageBlock?.lines.append(contentsOf: skipped)
      nextScroller(now)
    }

    // MARK: Scrolling

    private func nextScroller(_ now: CFTimeInterval) {
      guard !queue.isEmpty else {
        scroller = nil
        return openNextPage()
      }
      let next = queue.removeFirst()
      scroller = next
      if next.isSidebar {
        block = HitchBlock("catalog-sidebar", opens: false)
      } else {
        block = pageBlock
      }
      guard let view = next.view, view.hitchIsShown else {
        block?.lines.append("  scroller \(next.label) gone before its turn")
        return finishScroller(now)
      }
      if !view.hitchIsOnScreen {
        view.hitchReveal()
        next.notes.append("revealed")
        stage = .revealing(until: now + 0.3)
      } else {
        beginScroller(next, now: now)
      }
    }

    private func beginScroller(_ scroller: HitchScroller, now: CFTimeInterval) {
      guard let view = scroller.view else { return finishScroller(now) }
      let limits = view.hitchLimits(vertical: scroller.vertical)
      scroller.start = min(max(view.hitchOffset(vertical: scroller.vertical), limits.lower), limits.upper)
      scroller.position = scroller.start
      scroller.towardEnd = true
      scroller.startedAt = now
      scroller.line = block?.lines.count ?? 0
      block?.lines.append("")
      stage = .scrolling
    }

    private func step(now: CFTimeInterval, dt: Double) {
      guard let scroller else { return }
      guard let view = scroller.view, view.hitchIsShown else {
        scroller.notes.append("left the window")
        return finishScroller(now)
      }
      scroller.stats.frames += 1
      // Where the view is now against where the last frame put it: a jump is the page moving on its own. Scrolling
      // goes on from there, as a user's scroll would.
      let actual = view.hitchOffset(vertical: scroller.vertical)
      let jump = actual - scroller.position
      if abs(jump) > 3 {
        scroller.jumps += 1
        scroller.jumpTotal += abs(jump)
        scroller.worstJump = max(scroller.worstJump, abs(jump))
        if scroller.jumps <= 40, let block {
          block.lines.append(
            "    jump \(scroller.label) \(ms(jump)) pt at offset \(ms(scroller.position)), content "
              + "\(describe(view.hitchContentSize))")
        }
        scroller.position = actual
      }
      let limits = view.hitchLimits(vertical: scroller.vertical)
      let end = view.hitchEndsAtUpper(vertical: scroller.vertical) ? limits.upper : limits.lower
      let target = scroller.towardEnd ? end : scroller.start
      let distance = CGFloat(options.speed * min(dt, 0.1))
      let position =
        target > scroller.position
        ? min(scroller.position + distance, target) : max(scroller.position - distance, target)
      if !(options.events && view.hitchScroll(by: position - scroller.position, vertical: scroller.vertical)) {
        view.setHitchOffset(position, vertical: scroller.vertical)
      }
      scroller.position = position
      if position == target {
        if scroller.towardEnd {
          scroller.towardEnd = false
        } else {
          return finishScroller(now)
        }
      }
      if now - scroller.startedAt > 60 {
        scroller.notes.append("timed out")
        finishScroller(now)
      }
    }

    private func finishScroller(_ now: CFTimeInterval) {
      if let scroller, let block {
        if let view = scroller.view, case .scrolling = stage {
          let notes = scroller.notes.isEmpty ? "" : " [\(scroller.notes.joined(separator: ", "))]"
          let line =
            "  scroller \(scroller.label) \(type(of: view)) at \(describe(view.hitchFrame)) content "
            + "\(describe(view.hitchContentSize)) depth \(view.hitchDepth): \(scroller.stats.scrollSummary), "
            + "jumps \(scroller.jumps) (\(ms(scroller.jumpTotal)) pt, worst \(ms(scroller.worstJump)) pt), "
            + "\(seconds(now - scroller.startedAt)) s\(notes)"
          if scroller.line < block.lines.count { block.lines[scroller.line] = line } else { block.lines.append(line) }
        }
        block.scroll.add(scroller.stats)
        block.scrollers += 1
        if scroller.isSidebar {
          sidebarDone = true
          finish(block)
        }
      }
      nextScroller(now)
    }

    // MARK: Report

    private func finish(_ block: HitchBlock) {
      finished.append(block)
      write([block.summary] + block.lines)
      if block === pageBlock { pageBlock = nil }
    }

    private func complete() {
      stage = .done
      link?.invalidate()
      link = nil
      var total = HitchStats()
      var open = HitchStats()
      var worstPage = ""
      var worstScroll = 0.0
      for block in finished {
        total.add(block.scroll)
        if let stats = block.open { open.add(stats) }
        if block.scroll.worst > worstScroll {
          worstScroll = block.scroll.worst
          worstPage = block.name
        }
      }
      let pages = finished.filter { $0.open != nil }
      let occluded = pages.filter(\.occluded).count
      let settles = pages.compactMap(\.settle)
      let slowest = pages.max { ($0.settle ?? 0) < ($1.settle ?? 0) }
      write(
        ["", "SUMMARY"] + finished.map(\.summary) + [
          "",
          "TOTAL  \(pages.count) pages · open: \(open.hitches) hitches, \(ms(open.hitchMs)) ms in hitches, worst "
            + "\(ms(open.worst)) ms, settle avg \(seconds(settles.reduce(0, +) / Double(max(1, settles.count)))) s, "
            + "max \(seconds(slowest?.settle ?? 0)) s (\(slowest?.name ?? "-")) · scroll: \(total.scrollSummary), "
            + "\(ms(total.hitchMs)) ms in hitches (worst on \(worstPage.isEmpty ? "-" : worstPage))"
            + (occluded > 0 ? " · WARNING: window occluded on \(occluded) pages" : ""),
          "DONE",
        ])
      try? report?.close()
      report = nil
      HitchPlatform.finish()
    }

    private func write(_ lines: [String]) {
      guard let report else { return }
      try? report.write(contentsOf: Data((lines.joined(separator: "\n") + "\n").utf8))
      try? report.synchronize()
    }
  }

  // MARK: - Platform

  #if os(iOS)
    typealias HitchWindow = UIWindow
    typealias HitchScrollView = UIScrollView

    enum HitchPlatform {
      static var device: String {
        ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? UIDevice.current.model
      }

      static func window() -> UIWindow? {
        UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
      }

      static func bounds(_ window: UIWindow) -> CGRect { window.bounds }

      static func maximumFramesPerSecond(_ window: UIWindow) -> Int {
        window.windowScene?.screen.maximumFramesPerSecond ?? 60
      }

      static func displayLink(_ window: UIWindow, target: Any, selector: Selector) -> CADisplayLink {
        CADisplayLink(target: target, selector: selector)
      }

      static func visibilityWarning(_ window: UIWindow) -> String? { nil }

      static func scrollViews(in window: UIWindow) -> [UIScrollView] {
        var found: [UIScrollView] = []
        func collect(_ view: UIView) {
          if let scroll = view as? UIScrollView { found.append(scroll) }
          view.subviews.forEach(collect)
        }
        collect(window)
        return found
      }

      static func finish() {}
    }

    extension UIScrollView {
      /// In a window, not hidden (itself or an ancestor), and big enough to scroll.
      var hitchIsShown: Bool {
        guard window != nil, bounds.width >= 40, bounds.height >= 40 else { return false }
        var view: UIView? = self
        while let current = view {
          if current.isHidden || current.alpha < 0.01 { return false }
          view = current.superview
        }
        return true
      }

      /// Its frame in the window.
      var hitchFrame: CGRect { convert(bounds, to: nil) }

      var hitchContentSize: CGSize { contentSize }

      /// How many scroll views it sits in.
      var hitchDepth: Int {
        var depth = 0
        var view = superview
        while let current = view {
          if current is UIScrollView { depth += 1 }
          view = current.superview
        }
        return depth
      }

      /// `true` to scroll vertically, `false` horizontally, `nil` when the content fits.
      var hitchAxis: Bool? {
        let inset = adjustedContentInset
        if contentSize.height > bounds.height - inset.top - inset.bottom + 10 { return true }
        if contentSize.width > bounds.width - inset.left - inset.right + 10 { return false }
        return nil
      }

      /// At least half of it shows: inside the window and inside the scroll views it sits in.
      var hitchIsOnScreen: Bool {
        guard let window else { return false }
        var visible = hitchFrame.intersection(window.bounds)
        var view = superview
        while let current = view {
          if current is UIScrollView { visible = visible.intersection(current.convert(current.bounds, to: nil)) }
          view = current.superview
        }
        return visible.width * visible.height >= bounds.width * bounds.height / 2
      }

      /// Scrolls the scroll views it sits in so its top (or left) edge shows 20pt in.
      func hitchReveal() {
        var view = superview
        while let current = view {
          if let outer = current as? UIScrollView, let vertical = outer.hitchAxis {
            let rect = convert(bounds, to: outer)
            let inset = outer.adjustedContentInset
            let limits = outer.hitchLimits(vertical: vertical)
            let target = vertical ? rect.minY - inset.top - 20 : rect.minX - inset.left - 20
            outer.setHitchOffset(min(max(target, limits.lower), limits.upper), vertical: vertical)
          }
          view = current.superview
        }
      }

      func hitchLimits(vertical: Bool) -> (lower: CGFloat, upper: CGFloat) {
        let inset = adjustedContentInset
        if vertical {
          return (-inset.top, max(-inset.top, contentSize.height + inset.bottom - bounds.height))
        }
        return (-inset.left, max(-inset.left, contentSize.width + inset.right - bounds.width))
      }

      func hitchEndsAtUpper(vertical: Bool) -> Bool { true }

      func hitchOffset(vertical: Bool) -> CGFloat { vertical ? contentOffset.y : contentOffset.x }

      func setHitchOffset(_ value: CGFloat, vertical: Bool) {
        contentOffset = vertical ? CGPoint(x: contentOffset.x, y: value) : CGPoint(x: value, y: contentOffset.y)
      }

      /// No scroll-wheel events on iOS: the test sets the offset.
      func hitchScroll(by delta: CGFloat, vertical: Bool) -> Bool { false }
    }

  #elseif os(macOS)
    typealias HitchWindow = NSWindow
    typealias HitchScrollView = NSScrollView

    enum HitchPlatform {
      static var device: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [UInt8](repeating: 0, count: max(size, 1))
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(decoding: model.prefix { $0 != 0 }, as: UTF8.self)
      }

      /// The catalog window: the key one, else the largest visible one with content.
      static func window() -> NSWindow? {
        if let key = NSApp.keyWindow, key.contentView != nil, !(key is NSPanel) { return key }
        return NSApp.windows.filter { $0.isVisible && $0.contentView != nil && !($0 is NSPanel) }
          .max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
      }

      static func bounds(_ window: NSWindow) -> CGRect { window.contentView?.bounds ?? .zero }

      static func maximumFramesPerSecond(_ window: NSWindow) -> Int {
        (window.screen ?? NSScreen.main)?.maximumFramesPerSecond ?? 60
      }

      static func displayLink(_ window: NSWindow, target: Any, selector: Selector) -> CADisplayLink {
        (window.contentView ?? NSView()).displayLink(target: target, selector: selector)
      }

      /// macOS throttles the display link of a window that doesn't show.
      static func visibilityWarning(_ window: NSWindow) -> String? {
        window.occlusionState.contains(.visible)
          ? nil : "the window is not visible (occluded); the display link may be throttled"
      }

      static func scrollViews(in window: NSWindow) -> [NSScrollView] {
        var found: [NSScrollView] = []
        func collect(_ view: NSView) {
          if let scroll = view as? NSScrollView { found.append(scroll) }
          view.subviews.forEach(collect)
        }
        if let content = window.contentView { collect(content) }
        return found
      }

      static func finish() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSApp.terminate(nil) }
      }
    }

    extension NSScrollView {
      var hitchIsShown: Bool {
        window != nil && !isHiddenOrHasHiddenAncestor && alphaValue > 0.01 && bounds.width >= 40
          && bounds.height >= 40 && documentView != nil
      }

      /// Its frame in the window, from the top left.
      var hitchFrame: CGRect {
        let frame = convert(bounds, to: nil)
        let height = window?.contentView?.bounds.height ?? frame.maxY
        return CGRect(x: frame.minX, y: height - frame.maxY, width: frame.width, height: frame.height)
      }

      var hitchContentSize: CGSize { documentView?.frame.size ?? .zero }

      var hitchDepth: Int {
        var depth = 0
        var view = superview
        while let current = view {
          if current is NSScrollView { depth += 1 }
          view = current.superview
        }
        return depth
      }

      var hitchAxis: Bool? {
        let clip = contentView.bounds.size
        let inset = contentView.contentInsets
        let content = hitchContentSize
        if content.height > clip.height - inset.top - inset.bottom + 10 { return true }
        if content.width > clip.width - inset.left - inset.right + 10 { return false }
        return nil
      }

      var hitchIsOnScreen: Bool {
        guard let content = window?.contentView else { return false }
        var visible = convert(bounds, to: nil).intersection(content.convert(content.bounds, to: nil))
        var view = superview
        while let current = view {
          if let outer = current as? NSScrollView {
            visible = visible.intersection(outer.convert(outer.bounds, to: nil))
          }
          view = current.superview
        }
        return visible.width * visible.height >= bounds.width * bounds.height / 2
      }

      /// Scrolls the scroll views it sits in so its top (or left) edge shows 20pt in.
      func hitchReveal() {
        var view = superview
        while let current = view {
          if let outer = current as? NSScrollView, let document = outer.documentView, let vertical = outer.hitchAxis {
            let rect = convert(bounds, to: document)
            let inset = outer.contentView.contentInsets
            let limits = outer.hitchLimits(vertical: vertical)
            let target =
              !vertical
              ? rect.minX - inset.left - 20
              : document.isFlipped
                ? rect.minY - inset.top - 20 : rect.maxY + 20 + inset.top - outer.contentView.bounds.height
            outer.setHitchOffset(min(max(target, limits.lower), limits.upper), vertical: vertical)
          }
          view = current.superview
        }
      }

      func hitchLimits(vertical: Bool) -> (lower: CGFloat, upper: CGFloat) {
        let clip = contentView.bounds.size
        let inset = contentView.contentInsets
        let content = hitchContentSize
        if vertical {
          let (before, after) = documentView?.isFlipped ?? true ? (inset.top, inset.bottom) : (inset.bottom, inset.top)
          return (-before, max(-before, content.height + after - clip.height))
        }
        return (-inset.left, max(-inset.left, content.width + inset.right - clip.width))
      }

      /// A flipped document ends (scrolled down) at the largest origin, an unflipped one at the smallest.
      func hitchEndsAtUpper(vertical: Bool) -> Bool { !vertical || (documentView?.isFlipped ?? true) }

      func hitchOffset(vertical: Bool) -> CGFloat {
        vertical ? contentView.bounds.origin.y : contentView.bounds.origin.x
      }

      func setHitchOffset(_ value: CGFloat, vertical: Bool) {
        var origin = contentView.bounds.origin
        if vertical { origin.y = value } else { origin.x = value }
        contentView.scroll(to: origin)
        reflectScrolledClipView(contentView)
      }

      /// Scrolls by `delta` points with a pixel scroll-wheel event, as a trackpad does, through the scroll view's own
      /// handling (and SwiftUI's). Whole pixels: the rest carries to the next step.
      func hitchScroll(by delta: CGFloat, vertical: Bool) -> Bool {
        let total = delta + HitchWheel.remainder
        let pixels = total.rounded(.towardZero)
        HitchWheel.remainder = total - pixels
        guard pixels != 0 else { return true }
        let amount = Int32(-pixels)
        guard
          let cgEvent = CGEvent(
            scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: vertical ? amount : 0,
            wheel2: vertical ? 0 : amount, wheel3: 0),
          let event = NSEvent(cgEvent: cgEvent)
        else { return false }
        scrollWheel(with: event)
        return true
      }
    }

    @MainActor enum HitchWheel {
      static var remainder: CGFloat = 0
    }
  #endif
#else
  extension View {
    func hitchTest(_ model: CatalogModel) -> some View { self }
  }
#endif
