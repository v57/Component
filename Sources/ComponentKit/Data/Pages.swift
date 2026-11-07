import SwiftUI

// MARK: - A page as paper

/// A scanned or imported page drawn as paper: its picture on a sheet with a hairline and a small shadow, light in both
/// appearances (it's content, not chrome) and dimmed a little in dark. More than one page shows the next sheets
/// behind the first. Without a picture it is a blank sheet with a few grey lines.
///
/// ```swift
/// KitPagePreview(data: document.thumbnail, aspectRatio: 0.707, pages: 3).frame(height: 96)
/// KitPagePreview(data: nil, aspectRatio: 1.586)   // an ID card not scanned yet
/// ```
public struct KitPagePreview: View {
  var data: Data?
  var aspectRatio: CGFloat
  var pages: Int
  var maxPixelSize: Int
  @Environment(\.colorScheme) private var scheme

  /// - Parameters:
  ///   - aspectRatio: width over height (A4 0.707, an ID card 1.586, a passport's data page 1.42).
  ///   - pages: 2 or more draws the stacked sheets.
  public init(data: Data?, aspectRatio: CGFloat = 0.707, pages: Int = 1, maxPixelSize: Int = 480) {
    self.data = data
    self.aspectRatio = aspectRatio
    self.pages = pages
    self.maxPixelSize = maxPixelSize
  }

  public var body: some View {
    sheet
      .aspectRatio(aspectRatio, contentMode: .fit)
      .background(alignment: .topLeading) {
        if pages > 1 {
          GeometryReader { proxy in
            let step = max(2, min(proxy.size.width, proxy.size.height) * 0.035)
            ZStack(alignment: .topLeading) {
              if pages > 2 { behind(.paperBehindFar).offset(x: step * 2, y: step * 2) }
              behind(.paperBehind).offset(x: step, y: step)
            }
          }
        }
      }
      .padding(.trailing, pages > 1 ? 6 : 0)
      .padding(.bottom, pages > 1 ? 6 : 0)
      .accessibilityLabel(pages > 1 ? Text("\(pages) pages") : Text("Page"))
  }

  private var sheet: some View {
    ZStack {
      Rectangle().fill(KitColor.paper)
      if let data {
        KitImageData(data: data, maxPixelSize: maxPixelSize) { Self.blankLines }.scaledToFill()
      } else {
        Self.blankLines
      }
    }
    .clipped()
    .brightness(scheme == .dark ? -0.1 : 0)
    .overlay(Rectangle().strokeBorder(KitColor.paperEdge, lineWidth: 0.5))
    .shadow(color: .black.opacity(scheme == .dark ? 0.5 : 0.14), radius: 1.5, y: 1)
  }

  private func behind(_ color: KitColor) -> some View {
    Rectangle()
      .fill(color)
      .overlay(Rectangle().strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5))
  }

  /// A blank page's few lines of text.
  static var blankLines: some View {
    GeometryReader { proxy in
      let width = proxy.size.width, height = proxy.size.height
      let line = max(1, height * 0.018)
      VStack(alignment: .leading, spacing: height * 0.045) {
        Capsule().frame(width: width * 0.42, height: line * 1.6)
        ForEach(0..<6, id: \.self) { index in
          Capsule().frame(width: width * [0.78, 0.7, 0.74, 0.5, 0.76, 0.62][index], height: line)
        }
      }
      .foregroundStyle(KitColor.paperLines)
      .padding(.top, height * 0.1)
      .padding(.leading, width * 0.1)
    }
  }
}

// MARK: - A document as a card

/// A document in a grid: its first page on a well, a badge in the corner ("74 days"), then its title and a line
/// under it. Selected, the well takes the accent's tint and a 2pt ring. A tap selects; pass `open` for the double
/// click (Mac) that opens it.
///
/// ```swift
/// KitDocumentCard("Passport", imageData: doc.thumbnail, aspectRatio: 1.42, isSelected: selected == doc.id,
///                 badge: "74 days", badgeHue: .orange) {
///   Avatar(name: "Aiko", size: 14); Text("Aiko · until 2032")
/// } action: { selected = doc.id }
/// ```
public struct KitDocumentCard<Detail: View>: View {
  var title: String
  var imageData: Data?
  var aspectRatio: CGFloat
  var pages: Int
  var isSelected: Bool
  var badge: String?
  var badgeHue: Hue
  var detail: Detail
  var action: @MainActor () -> Void
  var open: (@MainActor () -> Void)?
  @Environment(\.kitIdiom) private var idiom

  public init(
    _ title: String, imageData: Data?, aspectRatio: CGFloat = 0.707, pages: Int = 1, isSelected: Bool = false,
    badge: String? = nil, badgeHue: Hue = .orange, @ViewBuilder detail: () -> Detail,
    action: @escaping @MainActor () -> Void, open: (@MainActor () -> Void)? = nil
  ) {
    self.title = title
    self.imageData = imageData
    self.aspectRatio = aspectRatio
    self.pages = pages
    self.isSelected = isSelected
    self.badge = badge
    self.badgeHue = badgeHue
    self.detail = detail()
    self.action = action
    self.open = open
  }

  public var body: some View {
    let wellHeight = idiom.size(112, touch: 124)
    VStack(alignment: .leading, spacing: 0) {
      ZStack(alignment: .topTrailing) {
        RoundedRectangle(cornerRadius: 9 * KitMetrics.radius / 8, style: .continuous)
          .fill(isSelected ? AnyShapeStyle(Hue.accent.soft(0.12)) : AnyShapeStyle(.kitFillSoft))
          .overlay {
            RoundedRectangle(cornerRadius: 9 * KitMetrics.radius / 8, style: .continuous)
              .strokeBorder(isSelected ? AnyShapeStyle(.kitAccent) : AnyShapeStyle(.kitSeparator),
                            lineWidth: isSelected ? 2 : 0.5)
          }
        KitPagePreview(data: imageData, aspectRatio: aspectRatio, pages: pages)
          .padding(.vertical, aspectRatio > 1 ? wellHeight * 0.18 : 12)
          .padding(.horizontal, 16)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        if let badge {
          Chip(badge, hue: badgeHue)
            .controlSize(.small)
            .background(Capsule().fill(.kitRaised))
            .padding(6)
        }
      }
      .frame(height: wellHeight)
      VStack(alignment: .leading, spacing: 1) {
        Text(title).kitFont(.headline).fontWeight(.regular).lineLimit(1)
        HStack(spacing: 5) { detail }
          .kitFont(.caption)
          .lineLimit(1)
      }
      .padding(.horizontal, 4)
      .padding(.top, 7)
      .padding(.bottom, 2)
    }
    .padding(6)
    .contentShape(RoundedRectangle(cornerRadius: KitMetrics.radiusCard, style: .continuous))
    .kitHoverEffect(in: .rect(cornerRadius: KitMetrics.radiusCard))
    .onTapGesture(count: 2) { (open ?? action)() }
    .simultaneousGesture(TapGesture().onEnded { action() })
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    .accessibilityAction { action() }
  }
}

extension KitDocumentCard where Detail == Text {
  /// A card with a plain line under the title ("Aiko · until 2032").
  public init(
    _ title: String, subtitle: String, imageData: Data?, aspectRatio: CGFloat = 0.707, pages: Int = 1,
    isSelected: Bool = false, badge: String? = nil, badgeHue: Hue = .orange, action: @escaping @MainActor () -> Void,
    open: (@MainActor () -> Void)? = nil
  ) {
    self.init(
      title, imageData: imageData, aspectRatio: aspectRatio, pages: pages, isSelected: isSelected, badge: badge,
      badgeHue: badgeHue, detail: { Text(subtitle) }, action: action, open: open)
  }
}

/// Document cards in columns as wide as the space allows (at least `minimumWidth` each).
///
/// ```swift
/// KitDocumentGrid { ForEach(documents) { doc in KitDocumentCard(…) } }
/// ```
public struct KitDocumentGrid<Content: View>: View {
  var minimumWidth: CGFloat
  var content: Content
  @Environment(\.kitIdiom) private var idiom

  public init(minimumWidth: CGFloat = 150, @ViewBuilder content: () -> Content) {
    self.minimumWidth = minimumWidth
    self.content = content()
  }

  public var body: some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: idiom.size(minimumWidth, touch: minimumWidth - 10)), spacing: 4, alignment: .top)],
      alignment: .leading, spacing: 4
    ) { content }
  }
}

// MARK: - A document's pages

/// One page in a `KitPageStrip`.
public struct KitPage: Identifiable, Hashable, Sendable {
  public var id: String
  /// "Data page", "Cover", "Page 2".
  public var label: String
  public var imageData: Data?
  public var aspectRatio: CGFloat

  public init(id: String, label: String, imageData: Data?, aspectRatio: CGFloat = 0.707) {
    self.id = id
    self.label = label
    self.imageData = imageData
    self.aspectRatio = aspectRatio
  }
}

/// A document's pages in a row: the current one ringed in the accent with its label in the label colour, then Add
/// Page (a dashed sheet) when `add` is given.
///
/// ```swift
/// KitPageStrip(pages: pages, selection: $page) { scanning = true }
/// ```
public struct KitPageStrip: View {
  var pages: [KitPage]
  @Binding var selection: String?
  var height: CGFloat
  var add: (@MainActor () -> Void)?

  public init(
    pages: [KitPage], selection: Binding<String?>, height: CGFloat = 68, add: (@MainActor () -> Void)? = nil
  ) {
    self.pages = pages
    _selection = selection
    self.height = height
    self.add = add
  }

  public var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(alignment: .bottom, spacing: 12) {
        ForEach(pages) { page in
          let isOn = page.id == selection
          Button {
            selection = page.id
          } label: {
            VStack(spacing: 6) {
              KitPagePreview(data: page.imageData, aspectRatio: page.aspectRatio, maxPixelSize: 240)
                .frame(height: height)
                .overlay {
                  if isOn {
                    Rectangle().strokeBorder(.kitAccent, lineWidth: 2).padding(-2)
                  }
                }
              Text(page.label.isEmpty ? " " : page.label)
                .kitFont(.caption)
                .fontWeight(isOn ? .medium : .regular)
                .foregroundStyle(isOn ? AnyShapeStyle(.kitLabel) : AnyShapeStyle(.kitSecondary))
                .lineLimit(1)
            }
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(isOn ? .isSelected : [])
        }
        if let add {
          Button(action: add) {
            VStack(spacing: 6) {
              RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(.kitBorder, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .frame(width: height * 0.7, height: height)
                .overlay { Image(systemName: "plus").foregroundStyle(.kitSecondary) }
              Text("Add Page").kitFont(.caption)
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
      }
      .padding(4)
    }
  }
}

// MARK: - A page large

/// A part of a page marked in the viewer: a field that was read ("Machine-readable zone · check digits match") or
/// what a search found. `rect` is in the page's units, 0...1 from the top left.
public struct KitPageHighlight: Identifiable, Hashable, Sendable {
  public var id: String
  public var rect: CGRect
  /// Shown above the box in the hue; nil for a box alone.
  public var label: String?
  public var systemImage: String?
  public var hue: Hue

  public init(id: String = UUID().uuidString, rect: CGRect, label: String? = nil, systemImage: String? = nil, hue: Hue = .accent) {
    self.id = id
    self.rect = rect
    self.label = label
    self.systemImage = systemImage
    self.hue = hue
  }
}

/// A page large on a well, fitted (or `zoom` times that, scrolling), with its highlights, boxes over hidden parts,
/// a watermark across it, and a bar along the top for the viewer's buttons (Fit, Select Text, rotate, crop).
///
/// ```swift
/// KitPageViewer(imageData: page.data, aspectRatio: 1.42, highlights: [mrz]) {
///   Button("Fit", systemImage: "plus.magnifyingglass") { zoom = 1 }.buttonStyle(.kit)
///   Spacer()
///   Button("Select Text", systemImage: "text.viewfinder") { … }.buttonStyle(.kit)
/// }
/// ```
public struct KitPageViewer<Bar: View>: View {
  var imageData: Data?
  var aspectRatio: CGFloat
  var zoom: CGFloat
  var rotation: Int
  var highlights: [KitPageHighlight]
  var hidden: [CGRect]
  var watermark: String?
  var bar: Bar
  @Environment(\.kitIdiom) private var idiom

  /// - Parameters:
  ///   - rotation: quarter turns clockwise.
  ///   - hidden: parts drawn as black boxes, as a shared copy will show them.
  public init(
    imageData: Data?, aspectRatio: CGFloat = 0.707, zoom: CGFloat = 1, rotation: Int = 0,
    highlights: [KitPageHighlight] = [], hidden: [CGRect] = [], watermark: String? = nil,
    @ViewBuilder bar: () -> Bar
  ) {
    self.imageData = imageData
    self.aspectRatio = aspectRatio
    self.zoom = zoom
    self.rotation = rotation
    self.highlights = highlights
    self.hidden = hidden
    self.watermark = watermark
    self.bar = bar()
  }

  public var body: some View {
    GeometryReader { proxy in
      let turned = rotation % 2 != 0
      let shown = turned ? 1 / aspectRatio : aspectRatio
      let room = CGSize(width: max(1, proxy.size.width - 80), height: max(1, proxy.size.height - 100))
      let fitted = room.width / room.height > shown
        ? CGSize(width: room.height * shown, height: room.height) : CGSize(width: room.width, height: room.width / shown)
      let size = CGSize(width: fitted.width * zoom, height: fitted.height * zoom)
      let page = turned ? CGSize(width: size.height, height: size.width) : size
      ScrollView([.horizontal, .vertical], showsIndicators: zoom > 1) {
        KitMarkedPage(
          imageData: imageData, aspectRatio: aspectRatio, highlights: highlights, hidden: hidden, watermark: watermark
        )
        .frame(width: page.width, height: page.height)
        .rotationEffect(.degrees(Double(rotation % 4) * 90))
        .frame(width: size.width, height: size.height)
        .padding(.horizontal, 40)
        .padding(.top, 56)
        .padding(.bottom, 44)
        .frame(minWidth: proxy.size.width, minHeight: proxy.size.height)
      }
      .scrollDisabled(zoom <= 1)
    }
    .background(.kitFillSoft)
    .overlay(alignment: .top) {
      HStack(spacing: 8) { bar }.padding(12)
    }
    .clipShape(RoundedRectangle(cornerRadius: KitMetrics.radiusXL, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: KitMetrics.radiusXL, style: .continuous).strokeBorder(.kitSeparator, lineWidth: 0.5)
    }
  }
}

extension KitPageViewer where Bar == EmptyView {
  public init(
    imageData: Data?, aspectRatio: CGFloat = 0.707, zoom: CGFloat = 1, rotation: Int = 0,
    highlights: [KitPageHighlight] = [], hidden: [CGRect] = [], watermark: String? = nil
  ) {
    self.init(
      imageData: imageData, aspectRatio: aspectRatio, zoom: zoom, rotation: rotation, highlights: highlights,
      hidden: hidden, watermark: watermark) { EmptyView() }
  }
}

/// A page with its marks at whatever size it's given: the viewer's page, and the preview of a shared copy.
///
/// ```swift
/// KitMarkedPage(imageData: data, aspectRatio: 0.707, hidden: [number], watermark: "Copy for Acme · 7 Nov 2026")
///   .frame(width: 240)
/// ```
public struct KitMarkedPage: View {
  var imageData: Data?
  var aspectRatio: CGFloat
  var highlights: [KitPageHighlight]
  var hidden: [CGRect]
  var watermark: String?

  public init(
    imageData: Data?, aspectRatio: CGFloat = 0.707, highlights: [KitPageHighlight] = [], hidden: [CGRect] = [],
    watermark: String? = nil
  ) {
    self.imageData = imageData
    self.aspectRatio = aspectRatio
    self.highlights = highlights
    self.hidden = hidden
    self.watermark = watermark
  }

  public var body: some View {
    KitPagePreview(data: imageData, aspectRatio: aspectRatio, maxPixelSize: 2400)
      .overlay {
        GeometryReader { proxy in
          let size = proxy.size
          ZStack(alignment: .topLeading) {
            if let watermark { KitWatermark(watermark).clipped() }
            ForEach(Array(hidden.enumerated()), id: \.offset) { _, rect in
              RoundedRectangle(cornerRadius: size.width * 0.006)
                .fill(KitColor.redaction)
                .frame(width: rect.width * size.width, height: rect.height * size.height)
                .offset(x: rect.minX * size.width, y: rect.minY * size.height)
            }
            ForEach(highlights) { mark in
              RoundedRectangle(cornerRadius: 3)
                .fill(mark.hue.soft(0.2))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(mark.hue.fill.opacity(0.7), lineWidth: 1.5))
                .frame(width: mark.rect.width * size.width, height: mark.rect.height * size.height)
                .offset(x: mark.rect.minX * size.width, y: mark.rect.minY * size.height)
              if let label = mark.label {
                HStack(spacing: 4) {
                  if let systemImage = mark.systemImage { Image(systemName: systemImage) }
                  Text(label)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .frame(height: 20)
                .background(Capsule().fill(mark.hue.fill))
                .fixedSize()
                .offset(x: mark.rect.minX * size.width, y: mark.rect.minY * size.height - 26)
              }
            }
          }
          .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
      }
  }
}

/// What a shared copy is for, in rows across the page at an angle, see-through red: drawn over a copy's preview
/// (the exported PDF gets the same rows burned into its pictures).
///
/// ```swift
/// page.overlay { KitWatermark("Copy for Acme Lettings only · 7 Nov 2026") }
/// ```
public struct KitWatermark: View {
  var text: String

  public init(_ text: String) { self.text = text }

  public var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      let fontSize = max(7, min(size.width, size.height) / 24)
      let reach = hypot(size.width, size.height)
      VStack(spacing: fontSize * 3.5) {
        ForEach(0..<max(1, Int(reach / (fontSize * 4.5)) + 1), id: \.self) { row in
          Text(String(repeating: "   \(text)   ", count: 6))
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(KitColor.watermark)
            .lineLimit(1)
            .fixedSize()
            .offset(x: row % 2 == 0 ? 0 : fontSize * 6)
        }
      }
      .frame(width: reach * 1.4, height: reach * 1.4)
      .rotationEffect(.degrees(-30))
      .position(x: size.width / 2, y: size.height / 2)
    }
    .allowsHitTesting(false)
    .accessibilityLabel(text)
  }
}

// MARK: - Cropping

/// A page's four corners on a photo, in the photo's units (0...1 from the top left), in the order top left, top
/// right, bottom right, bottom left.
public struct KitPageCorners: Hashable, Sendable {
  public var points: [CGPoint]

  public init(_ points: [CGPoint]) {
    precondition(points.count == 4, "a page has four corners")
    self.points = points
  }

  /// The whole photo.
  public static let full = KitPageCorners([.init(x: 0, y: 0), .init(x: 1, y: 0), .init(x: 1, y: 1), .init(x: 0, y: 1)])
}

/// The edges found on a photo with a handle on each corner to correct them: outside the page dimmed, the edges in
/// the accent. Drag a handle to move its corner.
///
/// ```swift
/// KitPageCrop(imageData: photo, aspectRatio: 4.0 / 3.0, corners: $corners)
/// ```
public struct KitPageCrop: View {
  var imageData: Data?
  var aspectRatio: CGFloat
  @Binding var corners: KitPageCorners
  @Environment(\.kitIdiom) private var idiom

  public init(imageData: Data?, aspectRatio: CGFloat, corners: Binding<KitPageCorners>) {
    self.imageData = imageData
    self.aspectRatio = aspectRatio
    _corners = corners
  }

  public var body: some View {
    KitImageData(data: imageData, maxPixelSize: 2000)
      .aspectRatio(aspectRatio, contentMode: .fit)
      .overlay {
        GeometryReader { proxy in
          let size = proxy.size
          let points = corners.points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
          ZStack(alignment: .topLeading) {
            Path { path in
              path.addRect(CGRect(origin: .zero, size: size))
              path.addLines(points)
              path.closeSubpath()
            }
            .fill(Color.black.opacity(0.32), style: FillStyle(eoFill: true))
            Path { path in
              path.addLines(points)
              path.closeSubpath()
            }
            .stroke(.kitAccent, lineWidth: 1.5)
            ForEach(0..<4, id: \.self) { index in
              let handle = idiom.size(12, touch: 22)
              Circle()
                .fill(.white)
                .overlay(Circle().strokeBorder(.kitAccent, lineWidth: 2))
                .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
                .frame(width: handle, height: handle)
                .frame(width: handle + 20, height: handle + 20)
                .contentShape(Rectangle())
                .position(points[index])
                #if !os(tvOS)
                .gesture(
                  DragGesture(coordinateSpace: .named("crop"))
                    .onChanged { value in
                      corners.points[index] = CGPoint(
                        x: min(1, max(0, value.location.x / size.width)),
                        y: min(1, max(0, value.location.y / size.height)))
                    }
                )
                #endif
                .accessibilityLabel(
                  [Text("Top left corner"), Text("Top right corner"), Text("Bottom right corner"),
                   Text("Bottom left corner")][index])
            }
          }
          .coordinateSpace(name: "crop")
        }
      }
  }
}
