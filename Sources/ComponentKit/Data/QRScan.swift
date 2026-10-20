import SwiftUI

#if canImport(AVFoundation) && !os(watchOS)
  @preconcurrency import AVFoundation
#endif
#if canImport(CoreImage)
  import CoreImage
#endif
#if canImport(ScreenCaptureKit) && os(macOS)
  import ScreenCaptureKit
#endif

// MARK: - Reading codes

/// QR codes read from pictures and the screen, without the platform's frameworks: an invite someone shows, a
/// recovery kit, the setup code a website shows for a one-time code.
///
/// ```swift
/// let links = KitQRReader.codes(inImageData: data)
/// let onScreen = try await KitQRReader.codesOnScreen()   // the Mac: what the displays show now
/// ```
public enum KitQRReader {
  /// The texts of the QR codes in a picture (PNG, JPEG, HEIC…), in no particular order; empty when there are none
  /// or the platform can't read pictures.
  public static func codes(inImageData data: Data) -> [String] {
    #if canImport(CoreImage)
      guard let image = CIImage(data: data) else { return [] }
      return codes(in: image)
    #else
      return []
    #endif
  }

  /// Whether this platform can look for codes on the screen (the Mac).
  public static var canScanScreen: Bool {
    #if canImport(ScreenCaptureKit) && os(macOS)
      true
    #else
      false
    #endif
  }

  /// The texts of the QR codes on every display right now. The first time, the system asks the person to allow
  /// screen recording; until they do it throws. Call it only when they ask ("Scan Screen").
  public static func codesOnScreen() async throws -> [String] {
    #if canImport(ScreenCaptureKit) && os(macOS)
      let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
      var found: [String] = []
      for display in content.displays {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = display.width * 2
        configuration.height = display.height * 2
        configuration.showsCursor = false
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        found += codes(in: CIImage(cgImage: image))
      }
      return Array(NSOrderedSet(array: found)) as? [String] ?? found
    #else
      return []
    #endif
  }

  #if canImport(CoreImage)
    static func codes(in image: CIImage) -> [String] {
      let detector = CIDetector(
        ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
      return (detector?.features(in: image) ?? []).compactMap { ($0 as? CIQRCodeFeature)?.messageString }
    }
  #endif
}

// MARK: - Camera

/// A camera view that reads QR codes: the picture fills the view in a rounded frame with a scanning corner mark,
/// and `onScan` gets each new code's text (once per code). The first time, the system asks the person to allow the
/// camera (the app declares why: `NSCameraUsageDescription`, and on the Mac the hardened runtime's camera
/// entitlement). Where there's no camera or it isn't allowed, the view says so.
///
/// ```swift
/// KitQRScanner { text in if let invite = VaultInvite(url: text) { accept(invite) } }
///   .frame(height: 280)
/// ```
public struct KitQRScanner: View {
  var onScan: (String) -> Void
  @State private var model = ScannerModel()

  public init(onScan: @escaping (String) -> Void) {
    self.onScan = onScan
  }

  public var body: some View {
    let shape = RoundedRectangle(cornerRadius: KitMetrics.radiusCard, style: .continuous)
    ZStack {
      shape.fill(KitColor.qrInk)
      #if canImport(AVFoundation) && (os(iOS) || os(macOS))
        if model.state == .running {
          CameraPreview(session: model.session).clipShape(shape)
          ScanCorners().stroke(KitColor.qrPlate.opacity(0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .padding(28)
        }
      #endif
      if let message = model.state.message {
        VStack(spacing: 8) {
          Image(systemName: "camera").font(.system(size: 22))
          Text(message).kitFont(.callout).multilineTextAlignment(.center)
        }
        .foregroundStyle(KitColor.qrPlate.opacity(0.85))
        .padding(20)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("QR code scanner")
    .onAppear {
      model.onScan = { text in onScan(text) }
      model.start()
    }
    .onDisappear { model.stop() }
  }
}

/// The scanner's corner marks.
private struct ScanCorners: Shape {
  func path(in rect: CGRect) -> Path {
    let side = min(rect.width, rect.height)
    let box = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
    let arm = side * 0.14
    var path = Path()
    for (corner, dx, dy) in [
      (CGPoint(x: box.minX, y: box.minY), 1.0, 1.0), (CGPoint(x: box.maxX, y: box.minY), -1.0, 1.0),
      (CGPoint(x: box.minX, y: box.maxY), 1.0, -1.0), (CGPoint(x: box.maxX, y: box.maxY), -1.0, -1.0),
    ] {
      path.move(to: CGPoint(x: corner.x, y: corner.y + dy * arm))
      path.addLine(to: corner)
      path.addLine(to: CGPoint(x: corner.x + dx * arm, y: corner.y))
    }
    return path
  }
}

/// The capture session and what it found, off the main thread for the frames.
@MainActor
@Observable
final class ScannerModel {
  enum State: Equatable {
    case starting, running, denied, unavailable

    var message: String? {
      switch self {
      case .starting: nil
      case .running: nil
      case .denied: "Allow the camera in Settings to scan a code."
      case .unavailable: "No camera here. Paste the link instead."
      }
    }
  }

  var state = State.starting
  @ObservationIgnored var onScan: ((String) -> Void)?
  @ObservationIgnored private var seen: Set<String> = []

  #if canImport(AVFoundation) && (os(iOS) || os(macOS))
    @ObservationIgnored let session = AVCaptureSession()
    @ObservationIgnored private var reader: FrameReader?

    func start() {
      switch AVCaptureDevice.authorizationStatus(for: .video) {
      case .authorized: configure()
      case .notDetermined:
        Task {
          let granted = await AVCaptureDevice.requestAccess(for: .video)
          if granted { configure() } else { state = .denied }
        }
      default: state = .denied
      }
    }

    private func configure() {
      guard let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device),
        session.canAddInput(input)
      else {
        state = .unavailable
        return
      }
      session.beginConfiguration()
      session.addInput(input)
      let output = AVCaptureVideoDataOutput()
      let reader = FrameReader { [weak self] text in
        Task { @MainActor in self?.found(text) }
      }
      output.setSampleBufferDelegate(reader, queue: DispatchQueue(label: "dev.v57.kit.qr-scanner"))
      if session.canAddOutput(output) { session.addOutput(output) }
      session.commitConfiguration()
      self.reader = reader
      state = .running
      let session = session
      DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    func stop() {
      let session = session
      DispatchQueue.global(qos: .userInitiated).async { session.stopRunning() }
    }
  #else
    func start() { state = .unavailable }
    func stop() {}
  #endif

  private func found(_ text: String) {
    guard !seen.contains(text) else { return }
    seen.insert(text)
    onScan?(text)
  }
}

#if canImport(AVFoundation) && (os(iOS) || os(macOS))
  /// Reads QR codes from camera frames, a few a second.
  private final class FrameReader: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let found: @Sendable (String) -> Void
    private var lastRead = Date.distantPast
    private let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyLow])

    init(found: @escaping @Sendable (String) -> Void) {
      self.found = found
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
      guard Date().timeIntervalSince(lastRead) > 0.25, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
      lastRead = Date()
      for feature in detector?.features(in: CIImage(cvPixelBuffer: buffer)) ?? [] {
        if let text = (feature as? CIQRCodeFeature)?.messageString { found(text) }
      }
    }
  }

  #if os(iOS)
    private struct CameraPreview: UIViewRepresentable {
      let session: AVCaptureSession

      func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
      }

      func updateUIView(_ view: PreviewView, context: Context) {}

      final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
      }
    }
  #else
    private struct CameraPreview: NSViewRepresentable {
      let session: AVCaptureSession

      func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer = layer
        view.wantsLayer = true
        return view
      }

      func updateNSView(_ view: NSView, context: Context) {}
    }
  #endif
#endif
