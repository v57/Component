import SwiftUI

// MARK: - Pages full screen

extension View {
  /// Shows `pages` one at a time over the whole window on black while `isPresented` is true, starting at `selection`
  /// (and keeping it as the user moves): a photo or a scanned page looked at alone. Pinch, double-tap or double-click
  /// zooms, a drag pans the zoomed page, ‹ › and the ← → keys (or a swipe at full size) move between pages, and
  /// Close, Escape or a swipe down closes it. A tap hides the bars. On iPhone the status bar hides while it shows.
  ///
  /// ```swift
  /// KitPageViewer(imageData: page.data, aspectRatio: page.ratio)
  ///   .onTapGesture { showsFullScreen = true }
  ///   .kitFullScreenPages(isPresented: $showsFullScreen, pages: pages, selection: $page)
  /// ```
  public func kitFullScreenPages(
    isPresented: Binding<Bool>, pages: [KitPage], selection: Binding<String?>
  ) -> some View {
    modifier(KitFullScreenPagesPresenter(isPresented: isPresented, pages: pages, selection: selection))
  }
}

private struct KitFullScreenPagesPresenter: ViewModifier {
  @Binding var isPresented: Bool
  var pages: [KitPage]
  @Binding var selection: String?
  @Environment(\.kitOverlayHost) private var host

  func body(content: Content) -> some View {
    #if os(iOS)
      if host == nil {
        // Outside `componentKit()`: the system's cover.
        content.fullScreenCover(isPresented: $isPresented) {
          let binding = $isPresented
          KitFullScreenPages(pages: pages, selection: $selection)
            .environment(\.kitDismiss, KitDismissAction { binding.wrappedValue = false })
            .presentationBackground(.black)
        }
      } else {
        overlay(content)
      }
    #else
      overlay(content)
    #endif
  }

  private func overlay(_ content: Content) -> some View {
    let pages = pages
    let selection = $selection
    return content.modifier(
      KitOverlayPresenter(
        isPresented: $isPresented, style: .cover, onDismiss: nil,
        content: { KitFullScreenPages(pages: pages, selection: selection) }))
  }
}

/// The pages full screen (`kitFullScreenPages`): the shown page alone on black, a bar on top (Close, its label, "2 of
/// 5") and ‹ › at the bottom. Only the shown page is built; moving to another starts it at full size.
struct KitFullScreenPages: View {
  var pages: [KitPage]
  @Binding var selection: String?
  @Environment(\.kitDismiss) private var dismiss
  @Environment(\.kitIdiom) private var idiom
  @State private var showsBars = true

  private var index: Int { pages.firstIndex { $0.id == selection } ?? 0 }

  var body: some View {
    let index = index
    ZStack {
      Color.black.ignoresSafeArea()
      if pages.indices.contains(index) {
        KitZoomablePage(page: pages[index]) {
          withAnimation(.kitFast) { showsBars.toggle() }
        } step: { step in
          move(step)
        } close: {
          dismiss()
        }
        .id(pages[index].id)
        .ignoresSafeArea()
      }
    }
    .overlay(alignment: .top) {
      topBar(index: index)
        .background(alignment: .top) { scrim(.top) }
        .bars(showsBars)
    }
    .overlay(alignment: .bottom) {
      pager(index: index)
        .background(alignment: .bottom) { scrim(.bottom) }
        .bars(showsBars && pages.count > 1)
    }
    .environment(\.colorScheme, .dark)
    #if os(iOS)
      .statusBarHidden(true)
      .persistentSystemOverlays(.hidden)
    #endif
  }

  private func topBar(index: Int) -> some View {
    HStack(spacing: 12) {
      Button("Close", systemImage: "xmark") { dismiss() }
        .buttonStyle(.kitRound)
        .keyboardShortcut(.cancelAction)
      if pages.indices.contains(index) {
        VStack(alignment: .leading, spacing: 1) {
          if !pages[index].label.isEmpty {
            Text(verbatim: pages[index].label).kitFont(.headline).lineLimit(1)
          }
          if pages.count > 1 {
            Text("\(index + 1) of \(pages.count)").kitFont(.caption).monospacedDigit()
          }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.6), radius: 3)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 16)
    .frame(maxWidth: .infinity)
    // On the Mac under the window's buttons, which stay over the page.
    .padding(.top, idiom == .phone ? 8 : idiom == .mac ? 40 : 12)
  }

  /// A shade behind a bar, so its label and buttons read over a light page (as Player's timeline over the video).
  private func scrim(_ edge: VerticalEdge) -> some View {
    LinearGradient(
      colors: [.black.opacity(0.5), .black.opacity(0)], startPoint: edge == .top ? .top : .bottom,
      endPoint: edge == .top ? .bottom : .top
    )
    .frame(height: 112)
    .ignoresSafeArea(edges: edge == .top ? .top : .bottom)
    .allowsHitTesting(false)
  }

  private func pager(index: Int) -> some View {
    HStack(spacing: 24) {
      Button("Previous Page", systemImage: "chevron.left") { move(-1) }
        .buttonStyle(.kitRound)
        .keyboardShortcut(.leftArrow, modifiers: [])
        .disabled(index == 0)
      Button("Next Page", systemImage: "chevron.right") { move(1) }
        .buttonStyle(.kitRound)
        .keyboardShortcut(.rightArrow, modifiers: [])
        .disabled(index >= pages.count - 1)
    }
    .controlSize(.large)
    .padding(.bottom, idiom == .phone ? 8 : 16)
    .frame(maxWidth: .infinity)
  }

  private func move(_ step: Int) {
    let next = index + step
    guard pages.indices.contains(next) else { return }
    selection = pages[next].id
  }
}

extension View {
  /// The full-screen bars: faded out while hidden, their buttons' keys still working.
  fileprivate func bars(_ isShown: Bool) -> some View {
    opacity(isShown ? 1 : 0)
      .allowsHitTesting(isShown)
      .accessibilityHidden(!isShown)
      .animation(.kitFast, value: isShown)
  }
}

/// One page fitted to the screen: pinch or double-tap to zoom (to the point tapped), drag to pan while zoomed; at
/// full size a sideways swipe steps pages and a swipe down closes.
private struct KitZoomablePage: View {
  let page: KitPage
  var tap: () -> Void
  var step: (Int) -> Void
  var close: () -> Void
  @State private var scale: CGFloat = 1
  @GestureState private var pinch: CGFloat = 1
  @State private var offset: CGSize = .zero
  @GestureState private var drag: CGSize = .zero

  static let maxScale: CGFloat = 6
  static let doubleTapScale: CGFloat = 2.5

  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      let fitted = Self.fit(page.aspectRatio, in: size)
      let shown = min(Self.maxScale, max(1, scale * pinch))
      let moved = scale > 1 || pinch > 1
        ? Self.clamp(CGSize(width: offset.width + drag.width, height: offset.height + drag.height), fitted: fitted, scale: shown, in: size)
        // At full size the page follows a swipe a little, then springs back.
        : CGSize(width: drag.width * 0.5, height: max(0, drag.height) * 0.5)
      Group {
        if page.imageData == nil {
          // A page not scanned yet: the blank sheet.
          KitPagePreview(data: nil, aspectRatio: page.aspectRatio)
        } else {
          KitImageData(data: page.imageData, maxPixelSize: 4096) { Color.clear }
        }
      }
      .aspectRatio(page.aspectRatio, contentMode: .fit)
      .frame(width: fitted.width, height: fitted.height)
      .scaleEffect(shown)
      .offset(moved)
      .frame(width: size.width, height: size.height)
      .contentShape(Rectangle())
      #if !os(tvOS)
        .onTapGesture(count: 2, coordinateSpace: .local) { location in zoom(at: location, fitted: fitted, in: size) }
        .onTapGesture { tap() }
        .gesture(
          MagnifyGesture()
            .updating($pinch) { value, state, _ in state = value.magnification }
            .onEnded { value in
              withAnimation(.kitFast) {
                scale = min(Self.maxScale, max(1, scale * value.magnification))
                offset = scale > 1 ? Self.clamp(offset, fitted: fitted, scale: scale, in: size) : .zero
              }
            }
            .simultaneously(
              with: DragGesture(minimumDistance: 8)
                .updating($drag) { value, state, _ in state = value.translation }
                .onEnded { value in ended(value, fitted: fitted, in: size) })
        )
      #endif
      .animation(.kitFast, value: drag == .zero)
      .accessibilityElement()
      .accessibilityLabel(page.label.isEmpty ? Text("Page") : Text(verbatim: page.label))
      .accessibilityAddTraits(.isImage)
      .accessibilityAction(named: Text(scale > 1 ? "Fit" : "Zoom")) {
        withAnimation(.kitFast) {
          scale = scale > 1 ? 1 : Self.doubleTapScale
          offset = .zero
        }
      }
    }
  }

  #if !os(tvOS)
  private func ended(_ value: DragGesture.Value, fitted: CGSize, in size: CGSize) {
    let moved = value.translation
    if scale > 1 {
      let flung = CGSize(
        width: offset.width + moved.width + (value.predictedEndTranslation.width - moved.width) * 0.3,
        height: offset.height + moved.height + (value.predictedEndTranslation.height - moved.height) * 0.3)
      withAnimation(.kitFast) { offset = Self.clamp(flung, fitted: fitted, scale: scale, in: size) }
    } else if abs(moved.width) > 60, abs(moved.width) > abs(moved.height) {
      step(moved.width < 0 ? 1 : -1)
    } else if moved.height > 100, moved.height > abs(moved.width) {
      close()
    }
  }
  #endif

  /// A double tap zooms in with the point tapped staying under the finger, or back to full size.
  private func zoom(at location: CGPoint, fitted: CGSize, in size: CGSize) {
    withAnimation(.kitFast) {
      if scale > 1 {
        scale = 1
        offset = .zero
      } else {
        scale = Self.doubleTapScale
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let toward = CGSize(width: (center.x - location.x) * (scale - 1), height: (center.y - location.y) * (scale - 1))
        offset = Self.clamp(toward, fitted: fitted, scale: scale, in: size)
      }
    }
  }

  /// The page's size fitted inside `size`.
  static func fit(_ aspectRatio: CGFloat, in size: CGSize) -> CGSize {
    guard size.width > 0, size.height > 0, aspectRatio > 0 else { return .zero }
    return size.width / size.height > aspectRatio
      ? CGSize(width: size.height * aspectRatio, height: size.height)
      : CGSize(width: size.width, height: size.width / aspectRatio)
  }

  /// An offset that keeps the zoomed page over the screen: no black past its edges where it is larger than the
  /// screen, centred where it is smaller.
  static func clamp(_ offset: CGSize, fitted: CGSize, scale: CGFloat, in size: CGSize) -> CGSize {
    let reachX = max(0, (fitted.width * scale - size.width) / 2)
    let reachY = max(0, (fitted.height * scale - size.height) / 2)
    return CGSize(width: min(reachX, max(-reachX, offset.width)), height: min(reachY, max(-reachY, offset.height)))
  }
}
