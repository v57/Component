import SwiftUI

/// A search inside content: the forms' filled field. It starts with its scope as a small raised pop-up (or the
/// magnifier when there is none) and ends with the search's live icon: the work indicator while it searches, a green
/// check when it's done, red (and a red ring) when nothing matched. The match count sits before the icon; a clear
/// button shows while there is text and no search runs. Esc clears the text.
///
/// ```swift
/// KitSearchField(text: $query, prompt: "Search orders", scope: $column, status: search.status, count: "4 rows")
/// KitSearchField(text: $filter, prompt: "Filter branches")
/// ```
public struct KitSearchField<Scope: KitOption>: View {
  @Binding var text: String
  var prompt: String
  var scope: Binding<Scope>?
  var scopes: [Scope]
  var status: WorkStatus
  var count: String?
  @FocusState private var isFocused: Bool
  @Environment(\.kitIdiom) private var idiom

  /// A search with a scope pop-up over `scopes`.
  public init(
    text: Binding<String>, prompt: String = "Search", scope: Binding<Scope>, scopes: [Scope],
    status: WorkStatus = .idle, count: String? = nil
  ) {
    _text = text
    self.prompt = prompt
    self.scope = scope
    self.scopes = scopes
    self.status = status
    self.count = count
  }

  public var body: some View {
    let metrics = CtlSearchMetrics(idiom)
    let failed = if case .failed = status { true } else { false }
    let shape = RoundedRectangle(cornerRadius: metrics.radius, style: .continuous)
    HStack(spacing: metrics.spacing) {
      if let scope {
        CtlScopeMenu(selection: scope, scopes: scopes, metrics: metrics)
      } else {
        Image(systemName: "magnifyingglass")
          .imageScale(.small)
          .foregroundStyle(.kitSecondary)
          .accessibilityHidden(true)
      }
      TextField(prompt, text: $text, prompt: Text(prompt).foregroundStyle(.kitSecondary))
        .textFieldStyle(.plain)
        .kitFont(.body)
        .foregroundStyle(.kitLabel)
        .focused($isFocused)
        .onKeyPress(.escape) {
          guard !text.isEmpty else { return .ignored }
          text = ""
          return .handled
        }
      if let label = count ?? (failed ? "None" : nil) {
        Text(label)
          .foregroundStyle(failed ? AnyShapeStyle(Hue.red.text) : AnyShapeStyle(.kitSecondary))
          .kitFont(.caption)
          .fontWeight(failed ? .medium : .regular)
          .monospacedDigit()
          .lineLimit(1)
          .fixedSize()
          .contentTransition(.numericText())
      }
      if status == .idle && !text.isEmpty {
        Button {
          text = ""
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: metrics.clear * 0.5, weight: .bold))
            .foregroundStyle(KitColor.window)
            .frame(width: metrics.clear, height: metrics.clear)
            .background(Circle().fill(.kitTertiary))
        }
        .buttonStyle(CtlPressStyle())
        .accessibilityLabel("Clear")
        .transition(.opacity)
      }
      if status != .idle {
        LiveIcon(systemImage: "magnifyingglass", status: status, size: metrics.icon)
          .transition(.opacity.combined(with: .scale(scale: 0.8)))
      }
    }
    .padding(
      EdgeInsets(
        top: 0,
        leading: scope == nil ? metrics.leading : (metrics.height - metrics.scope) / 2,
        bottom: 0,
        trailing: status != .idle ? (metrics.height - metrics.icon) / 2 : metrics.trailing))
    .frame(height: metrics.height)
    .background {
      shape.fill(isFocused ? AnyShapeStyle(KitColor.control) : AnyShapeStyle(.kitField))
    }
    .ctlFieldRing(isFocused || failed, hue: failed ? .red : .accent, cornerRadius: metrics.radius)
    .contentShape(shape)
    .onTapGesture { isFocused = true }
    .animation(.kitFast, value: isFocused)
    .animation(.kit, value: status)
    .animation(.kitFast, value: text.isEmpty)
    .accessibilityElement(children: .contain)
  }
}

extension KitSearchField where Scope: CaseIterable {
  /// A search with a scope pop-up over every case of the scope's enum.
  public init(
    text: Binding<String>, prompt: String = "Search", scope: Binding<Scope>, status: WorkStatus = .idle,
    count: String? = nil
  ) {
    self.init(
      text: text, prompt: prompt, scope: scope, scopes: Array(Scope.allCases), status: status, count: count)
  }
}

extension KitSearchField where Scope == Never {
  /// A search without a scope: the magnifier leads.
  public init(text: Binding<String>, prompt: String = "Search", status: WorkStatus = .idle, count: String? = nil) {
    _text = text
    self.prompt = prompt
    self.scope = nil
    self.scopes = []
    self.status = status
    self.count = count
  }
}

/// `Never` stands in for the scope of a search that has none (`KitSearchField(text:prompt:)`).
extension Never: KitOption {
  public var title: String { switch self {} }
}

/// The scope at the start of a search: a raised pop-up that opens the kit's menu of scopes.
struct CtlScopeMenu<Scope: KitOption>: View {
  @Binding var selection: Scope
  let scopes: [Scope]
  let metrics: CtlSearchMetrics

  var body: some View {
      HStack(spacing: 4) {
        Text(selection.title)
          .kitFont(.callout)
          .fontWeight(.medium)
          .foregroundStyle(.kitLabel)
        Image(systemName: "chevron.down")
          .font(.system(size: metrics.scope * 0.36, weight: .semibold))
          .foregroundStyle(.kitSecondary)
      }
      .lineLimit(1)
      .padding(EdgeInsets(top: 0, leading: metrics.scope * 0.32, bottom: 0, trailing: metrics.scope * 0.27))
      .frame(height: metrics.scope)
      .background { CtlRaisedCard(cornerRadius: metrics.scope * 0.27) }
      .contentShape(Rectangle())
      .fixedSize()
      .kitMenu { KitMenuOptions(selection: $selection, options: scopes) }
      .accessibilityLabel("Scope")
    .accessibilityValue(selection.title)
  }
}

struct CtlSearchMetrics {
  var height: CGFloat
  var radius: CGFloat
  var spacing: CGFloat
  var leading: CGFloat
  var trailing: CGFloat
  var scope: CGFloat
  var icon: CGFloat
  var clear: CGFloat

  init(_ idiom: KitIdiom) {
    switch idiom {
    case .mac: (height, radius, spacing, leading, trailing, scope, icon, clear) = (30, 9, 6, 9, 7, 22, 18, 16)
    case .pad: (height, radius, spacing, leading, trailing, scope, icon, clear) = (36, 12, 8, 12, 8, 28, 22, 20)
    case .phone: (height, radius, spacing, leading, trailing, scope, icon, clear) = (44, 14, 8, 14, 10, 32, 26, 22)
    case .tv: (height, radius, spacing, leading, trailing, scope, icon, clear) = (60, 18, 12, 18, 14, 44, 36, 32)
    }
  }
}

// MARK: - Sidebar search

/// The sidebar's search: a square card button in the sidebar's bottom bar that opens into the full-width search line
/// (a card with the field and a close button) and closes back into the button. Put it first in the bar and hide the
/// bar's other items while `isSearching`, so the line takes the whole bar. Esc or the close button ends the search
/// and clears the text.
///
/// ```swift
/// HStack(spacing: KitMetrics.gutter) {
///   SidebarSearchButton(text: $filter, isSearching: $isSearching)
///   if !isSearching { Spacer(); actions }
/// }
/// ```
public struct SidebarSearchButton: View {
  @Binding var text: String
  @Binding var isSearching: Bool
  var prompt: String
  @Environment(\.kitIdiom) private var idiom
  @Namespace private var namespace
  @FocusState private var isFocused: Bool
  @FocusState private var buttonFocused: Bool
  @State private var isHovered = false

  public init(text: Binding<String>, isSearching: Binding<Bool>, prompt: String = "Search") {
    _text = text
    _isSearching = isSearching
    self.prompt = prompt
  }

  public var body: some View {
    let size: CGFloat = idiom.size(32, touch: 40)
    Group {
      if isSearching {
        HStack(spacing: 8) {
          Image(systemName: "magnifyingglass")
            .foregroundStyle(.kitSecondary)
            .matchedGeometryEffect(id: "glass", in: namespace)
            .accessibilityHidden(true)
          TextField(prompt, text: $text, prompt: Text(prompt).foregroundStyle(.kitSecondary))
            .textFieldStyle(.plain)
            .kitFont(.body)
            .focused($isFocused)
            .onKeyPress(.escape) {
              close()
              return .handled
            }
          CtlSearchCloseButton(size: idiom.size(22, touch: 28), action: close)
        }
        .padding(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 6))
        .frame(maxWidth: .infinity)
        .frame(height: size)
        .background {
          SurfaceShape(surface: .card, cornerRadius: KitMetrics.radiusCard)
            .matchedGeometryEffect(id: "card", in: namespace)
        }
        .ctlFieldRing(isFocused, cornerRadius: KitMetrics.radiusCard)
        .onAppear { isFocused = true }
      } else {
        Button {
          withKitAnimation { isSearching = true }
        } label: {
          Image(systemName: "magnifyingglass")
            .foregroundStyle(isHovered ? .kitLabel : .kitSecondary)
            .matchedGeometryEffect(id: "glass", in: namespace)
            .frame(width: size, height: size)
            .background {
              SurfaceShape(surface: .card, cornerRadius: KitMetrics.radiusCard)
                .matchedGeometryEffect(id: "card", in: namespace)
            }
        }
        .buttonStyle(CtlPressStyle())
        .focused($buttonFocused)
        .focusEffectDisabled()
        .ctlStandaloneRing(buttonFocused, cornerRadius: KitMetrics.radiusCard)
        .kitHover { isHovered = $0 }
        .accessibilityLabel(prompt)
        .help(prompt)
      }
    }
    .kitFont(.body)
  }

  /// Focus leaves the field first, then it closes: a field that went away while focused dropped focus on its own, and
  /// on iPhone the keyboard then went down out of step with the bar.
  private func close() {
    isFocused = false
    withKitAnimation {
      text = ""
      isSearching = false
    }
  }
}

struct CtlSearchCloseButton: View {
  let size: CGFloat
  let action: () -> Void
  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      Image(systemName: "xmark")
        .font(.system(size: size * 0.5, weight: .semibold))
        .foregroundStyle(isHovered ? .kitLabel : .kitSecondary)
        .frame(width: size, height: size)
        .background {
          RoundedRectangle(cornerRadius: 8, style: .continuous).fill(isHovered ? AnyShapeStyle(.kitFill) : AnyShapeStyle(.clear))
        }
    }
    .buttonStyle(CtlPressStyle())
    .kitHover { isHovered = $0 }
    .accessibilityLabel("Close Search")
  }
}

private enum PreviewScope: String, KitOption, CaseIterable {
  case anyColumn = "Any column", inFile = "In File", inProject = "In Project"
  var title: String { rawValue }
}

#Preview("Search") {
  @Previewable @State var query = "Lisbon"
  @Previewable @State var empty = ""
  @Previewable @State var scope = PreviewScope.anyColumn
  @Previewable @State var searching = true
  VStack(alignment: .leading, spacing: 12) {
    KitSearchField(text: $empty, prompt: "Search orders", scope: $scope)
    KitSearchField(text: $empty, prompt: "Filter branches")
    KitSearchField(text: $query, scope: $scope, status: .done, count: "4 rows")
    KitSearchField(text: $query, scope: $scope, status: .working, count: "13 in 3 files")
    KitSearchField(text: $query, scope: $scope, status: .failed)
    HStack(spacing: KitMetrics.gutter) {
      SidebarSearchButton(text: $empty, isSearching: $searching)
      if !searching { Spacer() }
    }
  }
  .padding(20)
  .frame(width: 320)
  .componentKit()
}
