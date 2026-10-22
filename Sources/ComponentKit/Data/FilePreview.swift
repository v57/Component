import SwiftUI

#if canImport(PDFKit) && (os(iOS) || os(macOS))
  import PDFKit
#endif

/// A file's contents shown in place from bytes the app already has (read from an encrypted folder's sealed chunks,
/// so nothing plain is written): pictures, PDFs, text and code; anything else shows its kind's glyph and size.
///
/// ```swift
/// KitFilePreview(name: entry.name, data: try folder.read(entry.path))
/// ```
public struct KitFilePreview: View {
  var name: String
  var data: Data
  @Environment(\.kitIdiom) private var idiom

  public init(name: String, data: Data) {
    self.name = name
    self.data = data
  }

  /// How a file of this name is shown.
  enum Form: Equatable {
    case image, pdf, text, none
  }

  nonisolated static func form(of name: String) -> Form {
    let ext = name.split(separator: ".").last.map { $0.lowercased() } ?? ""
    if ext == "pdf" { return .pdf }
    switch KitFileCell.Kind.of(name) {
    case .image: return ext == "svg" || ext == "psd" ? .none : .image
    case .text: return ext == "fig" ? .none : .text
    default: return .none
    }
  }

  public var body: some View {
    let shape = RoundedRectangle(cornerRadius: KitMetrics.radiusCard, style: .continuous)
    Group {
      switch Self.form(of: name) {
      case .image:
        if let image = Image(data: data) {
          image.resizable().scaledToFit().clipShape(shape)
        } else {
          unavailable
        }
      case .pdf:
        #if canImport(PDFKit) && (os(iOS) || os(macOS))
          PDFPreview(data: data).clipShape(shape)
        #else
          unavailable
        #endif
      case .text:
        ScrollView {
          Text(String(decoding: data.prefix(512 * 1024), as: UTF8.self))
            .font(.system(size: idiom.size(12, touch: 13), design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
        .kitSurface(.card)
      case .none:
        unavailable
      }
    }
    .accessibilityLabel("Preview of \(name)")
  }

  private var unavailable: some View {
    VStack(spacing: 10) {
      Tile(systemImage: KitFileCell.Kind.of(name).systemImage, hue: .gray, size: 56)
      Text(name).kitFont(.headline)
      Text(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file) + " · no preview")
        .kitFont(.caption)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

#if canImport(PDFKit) && os(iOS)
  private struct PDFPreview: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
      let view = PDFView()
      view.autoScales = true
      view.document = PDFDocument(data: data)
      return view
    }

    func updateUIView(_ view: PDFView, context: Context) {}
  }
#elseif canImport(PDFKit) && os(macOS)
  private struct PDFPreview: NSViewRepresentable {
    let data: Data

    func makeNSView(context: Context) -> PDFView {
      let view = PDFView()
      view.autoScales = true
      view.document = PDFDocument(data: data)
      return view
    }

    func updateNSView(_ view: PDFView, context: Context) {}
  }
#endif
