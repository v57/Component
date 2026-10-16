import SwiftUI

/// Header sizes: a section's 24pt tile, the toolbar's or inspector's 28pt tile, a sheet's 30pt one.
public enum RichHeaderSize: Hashable, Sendable {
  case section, title, sheet

  func tile(_ idiom: KitIdiom) -> CGFloat {
    switch self {
    case .section: idiom == .phone ? 32 : idiom == .pad ? 30 : 24
    case .title: 28
    case .sheet: 30
    }
  }
}
/// The kit's header for anything that groups: an icon tile (a live icon when work runs), the name, one line of
/// meta (counts, status, progress) and trailing actions. Sidebar sections, list groups, inspector sections, the
/// toolbar's title and sheets all use it.
///
/// ```swift
/// RichHeader("Repositories", meta: "5 repositories · 2 with changes", systemImage: "folder", hue: .blue) {
///   Button("Add", systemImage: "plus") { … }
/// }
/// ```
public struct RichHeader<Icon: View, Meta: View, Accessory: View>: View {
  var title: Text
  var size: Size
  @ViewBuilder var icon: Icon
  @ViewBuilder var meta: Meta
  @ViewBuilder var accessory: Accessory
  var titleAccessory: AnyView?
  @Environment(\.kitIdiom) private var idiom

  public typealias Size = RichHeaderSize

  public init(
    _ title: Text, size: Size = .section, @ViewBuilder icon: () -> Icon, @ViewBuilder meta: () -> Meta,
    @ViewBuilder accessory: () -> Accessory
  ) {
    self.title = title
    self.size = size
    self.icon = icon()
    self.meta = meta()
    self.accessory = accessory()
  }

  public var body: some View {
    HStack(spacing: size == .section ? 8 : 10) {
      icon
      VStack(alignment: .leading, spacing: 1) {
        HStack(spacing: 6) {
          title
            .kitFont(size == .sheet ? .title3 : .headline)
            .lineLimit(1)
          if let titleAccessory {
            titleAccessory
              .kitFont(.caption)
              .fixedSize()
          }
        }
        meta
          .kitFont(.caption)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      accessory
        .buttonStyle(.kitIcon)
    }
    .padding(.leading, size == .section ? 6 : 0)
    .padding(.trailing, size == .section ? 2 : 0)
    .padding(.vertical, size == .section ? 4 : 0)
    .frame(minHeight: size == .section ? (idiom.isTouch ? 48 : 40) : nil)
  }
}

extension RichHeader {
  /// Sets a small view right after the title: a chip ("Production", "Read only"), a dot, a lock.
  ///
  /// ```swift
  /// RichHeader("Shop", meta: "PostgreSQL 16", systemImage: "cylinder").titleAccessory { Chip.production }
  /// ```
  public func titleAccessory<V: View>(@ViewBuilder _ content: () -> V) -> Self {
    var header = self
    header.titleAccessory = AnyView(content())
    return header
  }
}

extension RichHeader where Icon == SizedLiveIcon {
  /// A header with an SF Symbol tile that carries `status`.
  public init(
    _ title: some StringProtocol, size: Size = .section, systemImage: String, hue: Hue = .accent,
    status: WorkStatus = .idle, @ViewBuilder meta: () -> Meta, @ViewBuilder accessory: () -> Accessory
  ) {
    self.init(
      Text(title), size: size, icon: { SizedLiveIcon(systemImage: systemImage, hue: hue, status: status, size: size) },
      meta: meta, accessory: accessory)
  }
}

extension RichHeader where Icon == SizedLiveIcon, Meta == MetaLine {
  /// A header whose meta is a line of parts joined with " · ": `meta: ["5 repositories", "2 with changes"]`.
  public init(
    _ title: some StringProtocol, meta: [String] = [], size: Size = .section, systemImage: String,
    hue: Hue = .accent, status: WorkStatus = .idle, @ViewBuilder accessory: () -> Accessory
  ) {
    self.init(title, size: size, systemImage: systemImage, hue: hue, status: status, meta: { MetaLine(meta) }, accessory: accessory)
  }

  /// A header with a one-part meta line.
  public init(
    _ title: some StringProtocol, meta: String, size: Size = .section, systemImage: String, hue: Hue = .accent,
    status: WorkStatus = .idle, @ViewBuilder accessory: () -> Accessory
  ) {
    self.init(title, meta: [meta], size: size, systemImage: systemImage, hue: hue, status: status, accessory: accessory)
  }
}

extension RichHeader where Icon == SizedLiveIcon, Meta == MetaLine, Accessory == EmptyView {
  public init(
    _ title: some StringProtocol, meta: [String] = [], size: Size = .section, systemImage: String,
    hue: Hue = .accent, status: WorkStatus = .idle
  ) {
    self.init(title, meta: meta, size: size, systemImage: systemImage, hue: hue, status: status) { EmptyView() }
  }

  public init(
    _ title: some StringProtocol, meta: String, size: Size = .section, systemImage: String, hue: Hue = .accent,
    status: WorkStatus = .idle
  ) {
    self.init(title, meta: [meta], size: size, systemImage: systemImage, hue: hue, status: status) { EmptyView() }
  }
}

/// A meta line: parts joined with a quiet " · ".
public struct MetaLine: View {
  var parts: [String]

  public init(_ parts: [String]) { self.parts = parts.filter { !$0.isEmpty } }
  public init(_ parts: String...) { self.init(parts) }

  public var body: some View {
    parts.enumerated().reduce(Text("")) { text, item in
      item.offset == 0 ? text + Text(item.element) : text + Text("  ·  ").foregroundStyle(.kitTertiary) + Text(item.element)
    }
  }
}

/// A header's live icon, sized for the idiom it's drawn in.
public struct SizedLiveIcon: View {
  var systemImage: String
  var hue: Hue
  var status: WorkStatus
  var size: RichHeaderSize
  var glyph: AnyView? = nil
  @Environment(\.kitIdiom) private var idiom

  /// A live icon around any glyph (a drawn `BranchGlyph`, an image), sized for the idiom.
  ///
  /// ```swift
  /// RichHeader(Text("Branches"), icon: { SizedLiveIcon(hue: .orange) { BranchGlyph() } }, meta: { … }, accessory: {})
  /// ```
  public init<Glyph: View>(
    hue: Hue = .accent, status: WorkStatus = .idle, size: RichHeaderSize = .section, @ViewBuilder glyph: () -> Glyph
  ) {
    self.systemImage = ""
    self.hue = hue
    self.status = status
    self.size = size
    self.glyph = AnyView(glyph())
  }

  init(systemImage: String, hue: Hue, status: WorkStatus, size: RichHeaderSize) {
    self.systemImage = systemImage
    self.hue = hue
    self.status = status
    self.size = size
  }

  public var body: some View {
    if let glyph {
      LiveIcon(hue: hue, status: status, size: size.tile(idiom)) { glyph }
    } else {
      LiveIcon(systemImage: systemImage, hue: hue, status: status, size: size.tile(idiom))
    }
  }
}
