import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS) || os(visionOS)
import UIKit
#endif

/// What a `KitLineEditor` says under one of its lines: an error (red), a warning (orange), a note.
public struct KitLineIssue: Hashable, Sendable {
  public var message: String
  public var hue: Hue

  public init(_ message: String, hue: Hue = .red) {
    self.message = message
    self.hue = hue
  }
}

/// Editable monospaced text with line numbers in a gutter and a message right under any line that has one: filter
/// rules, a hosts list, a config where each line stands on its own. The line is tinted in the issue's hue with a
/// glyph at its end, and the lines below move down to make room, so a mistake sits where it was typed, not in a
/// separate list. It grows with its text (put it in a scroll view for long files); editing is the system's text
/// view (selection across lines, undo, paste), with smart quotes, dashes and corrections off.
///
/// `issues` are keyed by line number, from 1. Where there's no system text view (Apple TV, other platforms) it is a
/// plain text editor with the issues listed under it.
///
/// ```swift
/// KitLineEditor(text: $rules, issues: [4: KitLineIssue("Safari can't run :has-text")], placeholder: "||ads.example.com^")
/// ```
public struct KitLineEditor: View {
  @Binding var text: String
  var issues: [Int: KitLineIssue]
  var placeholder: KitString?
  var font: KitFont
  @Environment(\.self) private var environment
  @Environment(\.kitIdiom) private var idiom
  /// iPhone and iPad: the height the text view last measured (SwiftUI doesn't ask a UIKit view again as it grows).
  @State private var height: CGFloat?

  /// An editor whose placeholder is a key (a literal), looked up in the app's strings; the issues' messages are shown
  /// as they are.
  public init(
    text: Binding<String>, issues: [Int: KitLineIssue] = [:], placeholder: LocalizedStringKey? = nil,
    font: KitFont = .code
  ) {
    self.init(text: text, issues: issues, placeholder: KitString(placeholder), font: font)
  }

  /// The same with a placeholder shown as it is.
  @_disfavoredOverload
  public init(
    text: Binding<String>, issues: [Int: KitLineIssue] = [:], placeholder: String? = nil, font: KitFont = .code
  ) {
    self.init(text: text, issues: issues, placeholder: KitString(verbatim: placeholder), font: font)
  }

  init(text: Binding<String>, issues: [Int: KitLineIssue], placeholder: KitString?, font: KitFont) {
    self._text = text
    self.issues = issues
    self.placeholder = placeholder
    self.font = font
  }

  public var body: some View {
    let shape = RoundedRectangle(cornerRadius: KitMetrics.radiusCard, style: .continuous)
    editor
      .frame(maxWidth: .infinity, alignment: .topLeading)
      .background { SurfaceShape(surface: .field, cornerRadius: KitMetrics.radiusCard) }
      .clipShape(shape)
  }

  @ViewBuilder
  private var editor: some View {
    #if os(macOS)
    LineTextView(text: $text, style: style)
    #elseif os(iOS) || os(visionOS)
    LineTextView(text: $text, style: style, height: $height)
      .frame(height: height)
    #else
    VStack(alignment: .leading, spacing: 4) {
      #if !os(tvOS)
      TextEditor(text: $text).kitFont(font).frame(minHeight: 80)
      #else
      KitCodeBlock(source: .text(text), font: font, placeholder: placeholder)
      #endif
      ForEach(issues.keys.sorted(), id: \.self) { line in
        if let issue = issues[line] {
          Text("Line \(line): \(issue.message)").foregroundStyle(issue.hue.text).kitFont(.caption)
        }
      }
    }
    .padding(10)
    #endif
  }

  #if os(macOS) || os(iOS) || os(visionOS)
  private var style: LineStyle {
    let size = font.pointSize(scale: 1, idiom: idiom)
    return LineStyle(
      issues: issues.mapValues {
        LineStyle.Issue(
          message: $0.message, text: PlatformColor($0.hue.text.resolve(in: environment)),
          tint: PlatformColor($0.hue.soft(0.09).resolve(in: environment)))
      },
      placeholder: placeholder?.string,
      font: .monospacedSystemFont(ofSize: size, weight: .regular),
      numberFont: .monospacedDigitSystemFont(ofSize: size - 1, weight: .regular),
      messageFont: .systemFont(ofSize: KitFont.caption.pointSize(scale: 1, idiom: idiom)),
      lineHeight: (size * 1.6).rounded(),
      label: PlatformColor(KitColor.label.resolve(in: environment)),
      tertiary: PlatformColor(KitColor.tertiary.resolve(in: environment)),
      inset: idiom.size(8, touch: 10))
  }
  #endif
}

#if os(macOS) || os(iOS) || os(visionOS)
#if os(macOS)
typealias PlatformColor = NSColor
typealias PlatformFont = NSFont
private typealias PlatformImage = NSImage
#else
typealias PlatformColor = UIColor
typealias PlatformFont = UIFont
private typealias PlatformImage = UIImage
#endif

/// Everything the text view draws with, resolved from the kit's tokens.
struct LineStyle {
  struct Issue {
    var message: String
    var text: PlatformColor
    var tint: PlatformColor
  }

  var issues: [Int: Issue]
  var placeholder: String?
  var font: PlatformFont
  var numberFont: PlatformFont
  var messageFont: PlatformFont
  var lineHeight: CGFloat
  var label: PlatformColor
  var tertiary: PlatformColor
  /// Top and bottom padding inside the well.
  var inset: CGFloat

  /// Room for the numbers, which fits three digits.
  var gutter: CGFloat { ("000" as NSString).size(withAttributes: [.font: numberFont]).width + 16 }
  /// Room at a line's end for the issue's glyph.
  var glyphWidth: CGFloat { 22 }

  /// The paragraph style of line `number`: indented past the gutter; with an issue, room at its end for the glyph
  /// and under it for the message.
  func paragraph(_ number: Int, width: CGFloat) -> NSParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.minimumLineHeight = lineHeight
    style.maximumLineHeight = lineHeight
    style.firstLineHeadIndent = gutter
    style.headIndent = gutter
    if let issue = issues[number] {
      style.tailIndent = -glyphWidth
      style.paragraphSpacing = messageHeight(issue.message, width: width) + 6
    } else {
      style.tailIndent = -10
    }
    return style
  }

  var messageAttributes: [NSAttributedString.Key: Any] { [.font: messageFont] }

  func messageHeight(_ message: String, width: CGFloat) -> CGFloat {
    let bounds = (message as NSString).boundingRect(
      with: CGSize(width: max(width - gutter - 10, 40), height: CGFloat.greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: messageAttributes, context: nil)
    return ceil(bounds.height)
  }
}

/// The lines of a text: each one's range, without its newline (the last may be empty).
private func lineRanges(_ string: NSString) -> [NSRange] {
  var ranges: [NSRange] = []
  var start = 0
  while true {
    let rest = NSRange(location: start, length: string.length - start)
    let newline = string.range(of: "\n", options: .literal, range: rest)
    if newline.location == NSNotFound {
      ranges.append(rest)
      return ranges
    }
    ranges.append(NSRange(location: start, length: newline.location - start))
    start = newline.location + 1
  }
}

/// TextKit drawing shared by both platforms' text views: the paragraph styles that make room, then the numbers,
/// tints, glyphs and messages in that room.
@MainActor struct LineDecorator {
  var style: LineStyle

  /// Applies each line's paragraph style for a container `width` wide.
  func restyle(_ storage: NSTextStorage, width: CGFloat) {
    let string = storage.string as NSString
    storage.beginEditing()
    storage.addAttributes([.font: style.font, .foregroundColor: style.label], range: NSRange(location: 0, length: string.length))
    for (index, range) in lineRanges(string).enumerated() {
      // The paragraph's newline carries its style too.
      let length = min(range.length + 1, string.length - range.location)
      guard length > 0 else { continue }
      storage.addAttribute(
        .paragraphStyle, value: style.paragraph(index + 1, width: width),
        range: NSRange(location: range.location, length: length))
    }
    storage.endEditing()
  }

  var typingAttributes: [NSAttributedString.Key: Any] {
    [.font: style.font, .foregroundColor: style.label, .paragraphStyle: style.paragraph(0, width: 0)]
  }

  /// The top and bottom of each line's first and last fragments, in the container's coordinates.
  private func frames(_ layout: NSLayoutManager, _ string: NSString) -> [(first: CGRect, last: CGRect)] {
    lineRanges(string).map { range in
      if range.location >= string.length, string.length == 0 || string.character(at: string.length - 1) == 10 {
        // The empty line after a final newline (or an empty text): the extra fragment.
        var rect = layout.extraLineFragmentRect
        if rect.height == 0 { rect = CGRect(x: 0, y: 0, width: 0, height: style.lineHeight) }
        return (rect, rect)
      }
      let first = layout.glyphIndexForCharacter(at: range.location)
      let last = layout.glyphIndexForCharacter(at: max(range.location, NSMaxRange(range) - 1))
      return (
        layout.lineFragmentRect(forGlyphAt: first, effectiveRange: nil),
        layout.lineFragmentUsedRect(forGlyphAt: last, effectiveRange: nil)
      )
    }
  }

  /// The height the text takes, with its messages, for a container `width` wide.
  func height(_ layout: NSLayoutManager, _ container: NSTextContainer, _ string: NSString, width: CGFloat) -> CGFloat {
    layout.ensureLayout(for: container)
    var bottom = layout.usedRect(for: container).maxY
    for (index, frame) in frames(layout, string).enumerated() {
      bottom = max(bottom, frame.last.maxY)
      if let issue = style.issues[index + 1] {
        bottom = max(bottom, frame.last.maxY + style.messageHeight(issue.message, width: width) + 6)
      }
    }
    return ceil(max(bottom, style.lineHeight)) + style.inset * 2
  }

  /// Draws under the text: tints, numbers, glyphs, messages and the placeholder. `origin` is the container's.
  func draw(_ layout: NSLayoutManager, _ string: NSString, origin: CGPoint, width: CGFloat) {
    let frames = frames(layout, string)
    let right = NSMutableParagraphStyle()
    right.alignment = .right
    for (index, frame) in frames.enumerated() {
      let number = index + 1
      let issue = style.issues[number]
      let top = frame.first.minY + origin.y
      if let issue {
        let height = frame.last.maxY + style.messageHeight(issue.message, width: width) + 6 - frame.first.minY
        issue.tint.setFill()
        fill(CGRect(x: 0, y: top, width: width + origin.x * 2, height: height))
      }
      // The number on the line's first fragment, on the text's baseline.
      let numberRect = CGRect(x: origin.x, y: top, width: style.gutter - 8, height: style.lineHeight)
      let numberAttributes: [NSAttributedString.Key: Any] = [
        .font: style.numberFont, .foregroundColor: issue?.text ?? style.tertiary, .paragraphStyle: right,
      ]
      let numberSize = ("\(number)" as NSString).size(withAttributes: numberAttributes)
      ("\(number)" as NSString).draw(
        in: numberRect.offsetBy(dx: 0, dy: (style.lineHeight - numberSize.height) / 2), withAttributes: numberAttributes)
      guard let issue else { continue }
      if let glyph = warningGlyph(issue.text) {
        let size = CGSize(width: 12, height: 12)
        glyph.draw(
          in: CGRect(
            x: origin.x + width - style.glyphWidth + 4, y: top + (style.lineHeight - size.height) / 2,
            width: size.width, height: size.height))
      }
      let message = NSAttributedString(
        string: issue.message, attributes: style.messageAttributes.merging([.foregroundColor: issue.text]) { $1 })
      message.draw(
        with: CGRect(
          x: origin.x + style.gutter, y: frame.last.maxY + origin.y + 1, width: max(width - style.gutter - 10, 40),
          height: CGFloat.greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
    }
    if string.length == 0, let placeholder = style.placeholder {
      let attributes: [NSAttributedString.Key: Any] = [.font: style.font, .foregroundColor: style.tertiary]
      let size = (placeholder as NSString).size(withAttributes: attributes)
      (placeholder as NSString).draw(
        at: CGPoint(x: origin.x + style.gutter, y: origin.y + (style.lineHeight - size.height) / 2),
        withAttributes: attributes)
    }
  }

  private func fill(_ rect: CGRect) {
    #if os(macOS)
    rect.fill()
    #else
    UIRectFillUsingBlendMode(rect, .normal)
    #endif
  }

  private func warningGlyph(_ color: PlatformColor) -> PlatformImage? {
    #if os(macOS)
    let configuration = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
      .applying(.init(hierarchicalColor: color))
    return NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)?
      .withSymbolConfiguration(configuration)
    #else
    return UIImage(systemName: "exclamationmark.triangle.fill")?.withTintColor(color, renderingMode: .alwaysOriginal)
    #endif
  }
}

#if os(macOS)
/// The Mac's editor: an NSTextView that grows with its text and draws the decorations under it.
private final class DecoratedTextView: NSTextView {
  var decorator = LineDecorator(style: LineStyle(
    issues: [:], font: .systemFont(ofSize: 12), numberFont: .systemFont(ofSize: 11), messageFont: .systemFont(ofSize: 11),
    lineHeight: 20, label: .labelColor, tertiary: .tertiaryLabelColor, inset: 8))

  override var isFlipped: Bool { true }

  override func drawBackground(in rect: NSRect) {
    guard let layoutManager else { return }
    decorator.draw(layoutManager, string as NSString, origin: textContainerOrigin, width: textContainer?.size.width ?? bounds.width)
  }

  override func setFrameSize(_ newSize: NSSize) {
    let widthChanged = newSize.width != frame.width
    super.setFrameSize(newSize)
    if widthChanged, let textStorage { decorator.restyle(textStorage, width: newSize.width) }
  }
}

private struct LineTextView: NSViewRepresentable {
  @Binding var text: String
  var style: LineStyle

  func makeNSView(context: Context) -> DecoratedTextView {
    let view = DecoratedTextView()
    view.delegate = context.coordinator
    view.drawsBackground = false
    view.isRichText = false
    view.allowsUndo = true
    view.isAutomaticQuoteSubstitutionEnabled = false
    view.isAutomaticDashSubstitutionEnabled = false
    view.isAutomaticTextReplacementEnabled = false
    view.isAutomaticSpellingCorrectionEnabled = false
    view.isContinuousSpellCheckingEnabled = false
    view.isGrammarCheckingEnabled = false
    view.isVerticallyResizable = false
    view.isHorizontallyResizable = false
    view.textContainer?.lineFragmentPadding = 0
    view.textContainer?.widthTracksTextView = true
    view.textContainer?.containerSize = NSSize(width: 320, height: CGFloat.greatestFiniteMagnitude)
    view.textContainerInset = NSSize(width: 0, height: style.inset)
    view.string = text
    apply(style, to: view)
    return view
  }

  func updateNSView(_ view: DecoratedTextView, context: Context) {
    context.coordinator.parent = self
    if view.string != text {
      let selection = view.selectedRanges
      view.string = text
      view.selectedRanges = selection.compactMap {
        let range = $0.rangeValue
        return range.location <= (text as NSString).length ? $0 : nil
      }
    }
    view.textContainerInset = NSSize(width: 0, height: style.inset)
    apply(style, to: view)
  }

  private func apply(_ style: LineStyle, to view: DecoratedTextView) {
    view.decorator = LineDecorator(style: style)
    view.typingAttributes = view.decorator.typingAttributes
    view.insertionPointColor = style.label
    if let storage = view.textStorage { view.decorator.restyle(storage, width: view.frame.width) }
    view.needsDisplay = true
  }

  func sizeThatFits(_ proposal: ProposedViewSize, nsView view: DecoratedTextView, context: Context) -> CGSize? {
    guard let layout = view.layoutManager, let container = view.textContainer, let storage = view.textStorage else {
      return nil
    }
    let width = proposal.width ?? 320
    if container.size.width != width {
      container.size = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
      view.decorator.restyle(storage, width: width)
    }
    return CGSize(width: width, height: view.decorator.height(layout, container, view.string as NSString, width: width))
  }

  func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

  final class Coordinator: NSObject, NSTextViewDelegate {
    var parent: LineTextView

    init(parent: LineTextView) { self.parent = parent }

    func textDidChange(_ notification: Notification) {
      guard let view = notification.object as? DecoratedTextView else { return }
      parent.text = view.string
      if let storage = view.textStorage { view.decorator.restyle(storage, width: view.frame.width) }
      view.invalidateIntrinsicContentSize()
      view.needsDisplay = true
    }
  }
}
#else
/// iPhone and iPad: a UITextView that grows with its text and draws the decorations under it.
private final class DecoratedTextView: UITextView {
  var decorator = LineDecorator(style: LineStyle(
    issues: [:], font: .systemFont(ofSize: 12), numberFont: .systemFont(ofSize: 11), messageFont: .systemFont(ofSize: 11),
    lineHeight: 20, label: .label, tertiary: .tertiaryLabel, inset: 10))

  override func draw(_ rect: CGRect) {
    unboundContainer()
    decorator.draw(
      layoutManager, text as NSString, origin: CGPoint(x: textContainerInset.left, y: textContainerInset.top),
      width: textContainer.size.width)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    unboundContainer()
    if textContainer.size.width != lastWidth {
      lastWidth = textContainer.size.width
      decorator.restyle(textStorage, width: lastWidth)
      setNeedsDisplay()
      measure()
    }
  }

  /// UITextView sizes its container to its own bounds, so a line past the current height (the one just typed) is never
  /// laid out: the container stays as tall as the text needs, and the view grows to it.
  private func unboundContainer() {
    if textContainer.size.height < .greatestFiniteMagnitude / 2 {
      textContainer.size = CGSize(width: textContainer.size.width, height: .greatestFiniteMagnitude)
    }
  }

  /// Reports the height the text and its messages take at the current width.
  func measure() {
    unboundContainer()
    let width = textContainer.size.width
    guard width > 0 else { return }
    onHeight?(decorator.height(layoutManager, textContainer, text as NSString, width: width))
  }

  var onHeight: ((CGFloat) -> Void)?
  private var lastWidth: CGFloat = 0
}

private struct LineTextView: UIViewRepresentable {
  @Binding var text: String
  var style: LineStyle
  @Binding var height: CGFloat?

  func makeUIView(context: Context) -> DecoratedTextView {
    // TextKit 1, for the layout manager the decorations are measured with.
    let view = DecoratedTextView(usingTextLayoutManager: false)
    view.delegate = context.coordinator
    view.backgroundColor = .clear
    view.isScrollEnabled = false
    view.autocorrectionType = .no
    view.autocapitalizationType = .none
    view.smartQuotesType = .no
    view.smartDashesType = .no
    view.smartInsertDeleteType = .no
    view.spellCheckingType = .no
    view.textContainer.lineFragmentPadding = 0
    view.contentMode = .redraw
    view.text = text
    apply(style, to: view)
    return view
  }

  func updateUIView(_ view: DecoratedTextView, context: Context) {
    context.coordinator.parent = self
    let height = $height
    view.onHeight = { measured in
      guard abs((height.wrappedValue ?? 0) - measured) > 0.5 else { return }
      DispatchQueue.main.async { height.wrappedValue = measured }
    }
    if view.text != text {
      view.text = text
    }
    apply(style, to: view)
    view.measure()
  }

  private func apply(_ style: LineStyle, to view: DecoratedTextView) {
    view.decorator = LineDecorator(style: style)
    view.textContainerInset = UIEdgeInsets(top: style.inset, left: 0, bottom: style.inset, right: 0)
    view.typingAttributes = view.decorator.typingAttributes
    view.tintColor = nil
    view.decorator.restyle(view.textStorage, width: view.textContainer.size.width)
    view.setNeedsDisplay()
  }

  func sizeThatFits(_ proposal: ProposedViewSize, uiView view: DecoratedTextView, context: Context) -> CGSize? {
    let width = proposal.width ?? 320
    if view.textContainer.size.width != width {
      view.textContainer.size = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
      view.decorator.restyle(view.textStorage, width: width)
    }
    return CGSize(
      width: width,
      height: view.decorator.height(view.layoutManager, view.textContainer, view.text as NSString, width: width))
  }

  func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

  final class Coordinator: NSObject, UITextViewDelegate {
    var parent: LineTextView

    init(parent: LineTextView) { self.parent = parent }

    func textViewDidChange(_ view: UITextView) {
      parent.text = view.text
      guard let view = view as? DecoratedTextView else { return }
      view.decorator.restyle(view.textStorage, width: view.textContainer.size.width)
      view.setNeedsDisplay()
      view.measure()
    }
  }
}
#endif
#endif
