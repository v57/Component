import SwiftUI

#if os(macOS)
  import AppKit
#endif

extension EnvironmentValues {
  /// The app's accent: the only colour an app picks. Set it once with `.componentKit(accent:)`.
  @Entry public var kitAccent: Color = Color(.sRGB, red: 0, green: 0.478, blue: 1)
  /// Whether the window is the key window. An inactive window shows gray selections and doesn't animate.
  @Entry public var kitWindowIsActive: Bool = true
  /// The idiom the kit lays out for: rows and controls grow on iPad and iPhone.
  @Entry public var kitIdiom: KitIdiom = .current
  /// Draws the kit as under Increase Contrast whatever the system's setting (previews, the catalog). The system's
  /// own setting still applies when this is off.
  ///
  /// ```swift
  /// Preview().environment(\.kitIncreaseContrast, true)
  /// ```
  @Entry public var kitIncreaseContrast: Bool = false

  /// Whether the kit draws its Increase Contrast values: the system's setting, or `kitIncreaseContrast`.
  var kitMoreContrast: Bool { kitIncreaseContrast || colorSchemeContrast == .increased }
}

/// Where the kit is laid out: the Mac's dense metrics, or touch sizes.
public enum KitIdiom: Hashable, Sendable {
  case mac, pad, phone

  public static var current: KitIdiom {
    #if os(macOS)
      .mac
    #else
      .pad
    #endif
  }

  /// Touch targets: 44pt rows on iPad and iPhone instead of the Mac's 32.
  public var isTouch: Bool { self != .mac }
}

extension View {
  /// Puts a view tree on the kit: the app's accent, the kit's type and ground, and the window rules every app
  /// follows: an inactive window goes still (no animation) and Reduce Motion keeps fades and drops movement.
  /// Put it once on each scene's root view.
  ///
  /// ```swift
  /// WindowGroup { ContentView().componentKit(accent: .orange) }
  /// ```
  public func componentKit(accent: Color? = nil) -> some View {
    modifier(ComponentKitRoot(accent: accent))
  }
}

extension View {
  /// The window's appearance: `.light`, `.dark`, or `nil` to follow the system's. Use it in place of
  /// `preferredColorScheme` for an app's appearance setting: on the Mac, going back to `nil` from a fixed scheme left
  /// the window in that scheme until something else redrew it, so the kit follows the system's appearance itself.
  ///
  /// ```swift
  /// ContentView().kitColorScheme(settings.appearance.colorScheme)
  /// ```
  public func kitColorScheme(_ scheme: ColorScheme?) -> some View {
    modifier(ContColorScheme(scheme: scheme))
  }
}

private struct ContColorScheme: ViewModifier {
  var scheme: ColorScheme?
  #if os(macOS)
    @State private var system = ContColorScheme.systemScheme(NSApp.effectiveAppearance)
  #endif

  func body(content: Content) -> some View {
    #if os(macOS)
      // The app's appearance follows the system's (the scheme is set on the window, not the app).
      content
        .preferredColorScheme(scheme ?? system)
        .onReceive(NSApp.publisher(for: \.effectiveAppearance)) { system = Self.systemScheme($0) }
    #else
      content.preferredColorScheme(scheme)
    #endif
  }

  #if os(macOS)
    static func systemScheme(_ appearance: NSAppearance) -> ColorScheme {
      appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
    }
  #endif
}

struct ComponentKitRoot: ViewModifier {
  var accent: Color?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  #if os(macOS)
    @Environment(\.controlActiveState) private var activeState
    private var isActive: Bool { activeState != .inactive }
  #else
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isActive: Bool { scenePhase != .background }
  #endif

  func body(content: Content) -> some View {
    content
      .environment(\.kitWindowIsActive, isActive)
      .environment(\.kitIdiom, idiom)
      .modifier(OptionalAccent(accent: accent))
      .font(KitFont.body.font)
      .tracking(KitFont.body.tracking)
      .foregroundStyle(.kitLabel)
      .transaction { transaction in
        // A window that isn't focused doesn't animate at all; Reduce Motion keeps a short crossfade.
        if !isActive {
          transaction.disablesAnimations = true
          transaction.animation = nil
        } else if reduceMotion, transaction.animation != nil {
          transaction.animation = .easeInOut(duration: 0.15)
        }
      }
  }

  private var idiom: KitIdiom {
    #if os(macOS)
      .mac
    #else
      sizeClass == .compact ? .phone : .pad
    #endif
  }
}

private struct OptionalAccent: ViewModifier {
  var accent: Color?

  func body(content: Content) -> some View {
    if let accent {
      content.environment(\.kitAccent, accent).tint(accent)
    } else {
      content
    }
  }
}
