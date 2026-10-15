import SwiftUI

/// One tab of a `KitTabStrip`: its id, title, an optional SF Symbol in a hue, and whether it has unsaved edits.
///
/// ```swift
/// KitTab(id: file.id, title: "TripStore.swift", systemImage: "swift", hue: .orange, isEdited: true)
/// ```
public struct KitTab<ID: Hashable>: Identifiable {
  public var id: ID
  public var title: String
  public var systemImage: String?
  /// The icon's hue; `nil` draws it in the tab's text colour.
  public var hue: Hue?
  /// Unsaved edits: a dot where the close button sits (the close button shows on hover).
  public var isEdited: Bool

  public init(id: ID, title: String, systemImage: String? = nil, hue: Hue? = nil, isEdited: Bool = false) {
    self.id = id
    self.title = title
    self.systemImage = systemImage
    self.hue = hue
    self.isEdited = isEdited
  }
}

/// The kit's tab strip (editor tabs, query tabs): tabs on the panel colour, the selected one a raised card that
/// glides to the new pick, a close button on the selected and the hovered tab, a dot on an edited one, and an
/// optional + at the end. It scrolls sideways when the tabs don't fit.
/// Keyboard: Tab focuses a tab (a solid ring), ← → move, Space selects. VoiceOver: each tab is a selectable button
/// with a Close action.
///
/// ```swift
/// KitTabStrip(tabs: documents.map { KitTab(id: $0.id, title: $0.name, isEdited: $0.isDirty) },
///             selection: $current, onClose: { close($0) }, onAdd: { newQuery() })
/// ```
public struct KitTabStrip<ID: Hashable>: View {
  var tabs: [KitTab<ID>]
  @Binding var selection: ID?
  var onClose: ((ID) -> Void)?
  var onAdd: (() -> Void)?
  @Environment(\.kitIdiom) private var idiom
  @FocusState private var focus: ID?
  @Namespace private var namespace

  public init(
    tabs: [KitTab<ID>], selection: Binding<ID?>, onClose: ((ID) -> Void)? = nil, onAdd: (() -> Void)? = nil
  ) {
    self.tabs = tabs
    _selection = selection
    self.onClose = onClose
    self.onAdd = onAdd
  }

  /// A tab strip that always has a selected tab.
  public init(
    tabs: [KitTab<ID>], selection: Binding<ID>, onClose: ((ID) -> Void)? = nil, onAdd: (() -> Void)? = nil
  ) {
    self.init(
      tabs: tabs,
      selection: Binding<ID?>(get: { selection.wrappedValue }, set: { if let id = $0 { selection.wrappedValue = id } }),
      onClose: onClose, onAdd: onAdd)
  }

  public var body: some View {
    ViewThatFits(in: .horizontal) {
      row
      ScrollView(.horizontal, showsIndicators: false) { row }
    }
    .frame(height: idiom.isTouch ? 48 : 40)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.kitPanel)
    .overlay(alignment: .bottom) { Rectangle().fill(.kitSeparator).frame(height: 1) }
    .focusEffectDisabled()
    .onKeyPress(.leftArrow) { moveFocus(-1) }
    .onKeyPress(.rightArrow) { moveFocus(1) }
    .animation(.kit, value: selection)
  }

  private var row: some View {
    HStack(spacing: idiom.isTouch ? 6 : 4) {
      ForEach(tabs) { tab in
        CtlTabView(
          tab: tab, isSelected: tab.id == selection, isFocused: focus == tab.id, namespace: namespace,
          select: { withKitAnimation { selection = tab.id } },
          close: onClose.map { onClose in { onClose(tab.id) } }
        )
        .focused($focus, equals: tab.id)
      }
      if let onAdd {
        Button("New Tab", systemImage: "plus", action: onAdd)
          .labelStyle(.iconOnly)
          .buttonStyle(.kitIcon)
          .help("New Tab")
      }
    }
    .padding(.horizontal, idiom.isTouch ? 10 : 8)
    .fixedSize(horizontal: true, vertical: false)
    .frame(maxHeight: .infinity)
  }

  private func moveFocus(_ direction: Int) -> KeyPress.Result {
    guard let current = focus, let index = tabs.firstIndex(where: { $0.id == current }),
      let next = CtlSegmentNavigation.next(from: index, by: direction, enabled: tabs.map { _ in true })
    else { return .ignored }
    focus = tabs[next].id
    return .handled
  }
}

/// A tab: the selected one is the raised card, a hovered one takes the hover fill; the close button (or the edited
/// dot) sits in an 18pt slot at the end that is always there, so tabs never change width on hover.
struct CtlTabView<ID: Hashable>: View {
  let tab: KitTab<ID>
  let isSelected: Bool
  let isFocused: Bool
  let namespace: Namespace.ID
  let select: () -> Void
  let close: (() -> Void)?
  @Environment(\.kitIdiom) private var idiom
  @State private var isHovered = false

  var body: some View {
    let radius: CGFloat = idiom.isTouch ? 10 : 8
    HStack(spacing: 6) {
      Button(action: select) {
        HStack(spacing: 6) {
          if let systemImage = tab.systemImage {
            Image(systemName: systemImage)
              .imageScale(.small)
              .foregroundStyle(tab.hue.map { AnyShapeStyle($0.fill) } ?? AnyShapeStyle(.foreground))
          }
          CtlStableWeightText(tab.title, bold: isSelected)
            .truncationMode(.tail)
        }
        .frame(maxHeight: .infinity)
      }
      .buttonStyle(CtlPressStyle())
      .accessibilityAddTraits(isSelected ? .isSelected : [])
      .accessibilityAction(named: "Close") { close?() }
      if close != nil || tab.isEdited {
        trailing
      }
    }
    .kitFont(.callout)
    .fontWeight(.regular)
    .lineLimit(1)
    .foregroundStyle(isSelected || isHovered ? .kitLabel : .kitSecondary)
    .padding(.leading, idiom.isTouch ? 12 : 10)
    .padding(.trailing, close != nil || tab.isEdited ? (idiom.isTouch ? 6 : 5) : (idiom.isTouch ? 12 : 10))
    .frame(maxWidth: idiom.isTouch ? 240 : 200)
    .frame(height: idiom.isTouch ? 36 : 28)
    .background {
      if isSelected {
        CtlRaisedCard(cornerRadius: radius).matchedGeometryEffect(id: "tab", in: namespace)
      } else if isHovered {
        RoundedRectangle(cornerRadius: radius, style: .continuous).fill(.kitHover)
      }
    }
    .ctlStandaloneRing(isFocused, cornerRadius: radius)
    .contentShape(Rectangle())
    .onHover { isHovered = $0 }
    .animation(.kitFast, value: isHovered)
  }

  @ViewBuilder
  private var trailing: some View {
    let size: CGFloat = idiom.isTouch ? 24 : 18
    ZStack {
      if let close, isSelected || isHovered || !tab.isEdited {
        CtlTabCloseButton(title: tab.title, size: size, action: close)
          .opacity(isSelected || isHovered ? 1 : 0)
          .accessibilityHidden(!(isSelected || isHovered))
      } else if tab.isEdited {
        Circle().fill(.kitSecondary).frame(width: 7, height: 7)
          .accessibilityLabel("Edited")
      }
    }
    .frame(width: size, height: size)
  }
}

struct CtlTabCloseButton: View {
  let title: String
  let size: CGFloat
  let action: () -> Void
  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      Image(systemName: "xmark")
        .font(.system(size: size * 0.5, weight: .semibold))
        .frame(width: size, height: size)
        .background {
          RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(isHovered ? AnyShapeStyle(.kitFill) : AnyShapeStyle(.clear))
        }
    }
    .buttonStyle(CtlPressStyle())
    .onHover { isHovered = $0 }
    .accessibilityLabel("Close \(title)")
    .help("Close")
  }
}

// MARK: - Path bar

/// One crumb of a `KitPathBar`: a title, an optional SF Symbol in a hue, and what clicking it does.
///
/// ```swift
/// KitPathItem("Sources", systemImage: "folder", hue: .blue) { reveal(sources) }
/// ```
public struct KitPathItem {
  public var title: String
  public var systemImage: String?
  public var hue: Hue?
  public var action: (() -> Void)?

  public init(_ title: String, systemImage: String? = nil, hue: Hue? = nil, action: (() -> Void)? = nil) {
    self.title = title
    self.systemImage = systemImage
    self.hue = hue
    self.action = action
  }
}

/// A path bar (breadcrumbs): crumbs separated by small chevrons; the current (last) crumb is the label in semibold,
/// the others are quiet and take the field fill on hover. The last crumb keeps its width when space runs out.
///
/// ```swift
/// KitPathBar(["v57", "Git", "Shared", "Components.swift"])
/// KitPathBar(components: [
///   KitPathItem("Sources", systemImage: "folder", hue: .blue) { open(sources) },
///   KitPathItem("TripStore", systemImage: "swift", hue: .orange),
/// ])
/// ```
public struct KitPathBar: View {
  var components: [KitPathItem]
  @Environment(\.kitIdiom) private var idiom

  public init(components: [KitPathItem]) {
    self.components = components
  }

  /// A path bar of plain titles.
  public init(_ titles: [String]) {
    self.init(components: titles.map { KitPathItem($0) })
  }

  public var body: some View {
    HStack(spacing: 1) {
      ForEach(components.indices, id: \.self) { index in
        let isLast = index == components.count - 1
        CtlCrumb(item: components[index], isCurrent: isLast)
          .layoutPriority(isLast ? 1 : 0)
        if !isLast {
          Image(systemName: "chevron.right")
            .font(.system(size: idiom.isTouch ? 10 : 8, weight: .semibold))
            .foregroundStyle(.kitTertiary)
            .frame(width: idiom.isTouch ? 12 : 10)
            .accessibilityHidden(true)
        }
      }
    }
    .kitFont(.callout)
    .fontWeight(.regular)
    .lineLimit(1)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Path")
  }
}

struct CtlCrumb: View {
  let item: KitPathItem
  let isCurrent: Bool
  @Environment(\.kitIdiom) private var idiom
  @FocusState private var isFocused: Bool
  @State private var isHovered = false

  var body: some View {
    let radius: CGFloat = idiom.isTouch ? 9 : 7
    Button {
      item.action?()
    } label: {
      HStack(spacing: 4) {
        if let systemImage = item.systemImage {
          Image(systemName: systemImage)
            .imageScale(.small)
            .foregroundStyle(item.hue.map { AnyShapeStyle($0.fill) } ?? AnyShapeStyle(.foreground))
        }
        Text(item.title)
          .fontWeight(isCurrent ? .semibold : .regular)
          .truncationMode(.middle)
      }
      .foregroundStyle(isCurrent || isHovered ? .kitLabel : .kitSecondary)
      .padding(.horizontal, idiom.isTouch ? 8 : 6)
      .frame(height: idiom.isTouch ? 32 : 24)
      .background {
        if isHovered && !isCurrent && item.action != nil {
          RoundedRectangle(cornerRadius: radius, style: .continuous).fill(.kitField)
        }
      }
    }
    .buttonStyle(CtlPressStyle())
    .disabled(item.action == nil && !isCurrent)
    .focused($isFocused)
    .ctlStandaloneRing(isFocused, cornerRadius: radius)
    .onHover { isHovered = $0 }
    .animation(.kitFast, value: isHovered)
    .accessibilityAddTraits(isCurrent ? .isSelected : [])
  }
}

#Preview("Tabs and path bar") {
  @Previewable @State var tab = 1
  VStack(spacing: 0) {
    KitTabStrip(
      tabs: [
        KitTab(id: 1, title: "TripStore", systemImage: "swift", hue: .orange),
        KitTab(id: 2, title: "Trip", systemImage: "swift", hue: .orange),
        KitTab(id: 3, title: "Package", systemImage: "doc", hue: .orange, isEdited: true),
      ], selection: $tab, onClose: { _ in }, onAdd: {})
    KitPathBar(components: [
      KitPathItem("Atlas", systemImage: "folder", hue: .red) {},
      KitPathItem("Sources", systemImage: "folder", hue: .blue) {},
      KitPathItem("TripStore", systemImage: "swift", hue: .orange),
    ])
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
  .frame(width: 480)
  .componentKit()
}
