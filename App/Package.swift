// swift-tools-version: 6.2

import PackageDescription

/// This repository's ComponentKit, the package at "..": SwiftPM names a path dependency after its folder, which is
/// Component in the main checkout and the worktree's own name in a worktree.
let kits = String(Context.packageDirectory.split(whereSeparator: { $0 == "/" || $0 == "\\" }).dropLast().last ?? "Component")

// The catalog app, all of it but the bundle: Component.xcodeproj (at the repository's root) builds
// Sources/Component/ComponentMain.swift into Component.app and links ComponentApp; on Linux and Windows the Component
// target below does.
let package = Package(
  name: "ComponentApp", platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v18), .visionOS(.v2)],
  products: [.library(name: "ComponentApp", targets: ["ComponentApp"])],
  dependencies: [.package(path: "..")],
  targets: [
    .target(
      name: "ComponentApp", dependencies: [.product(name: "ComponentKit", package: kits)],
      swiftSettings: [
        .enableUpcomingFeature("ApproachableConcurrency"), .defaultIsolation(MainActor.self),
        .enableUpcomingFeature("MemberImportVisibility"),
      ])
  ])

#if os(Windows) || os(Linux)
// Off Apple platforms SwiftUI is v57/SwiftUI: GitHub's main branch, or the checkout next to this repository with
// `V57_LOCAL=1`. Only here: on Apple platforms v57/SwiftUI (with its swift-syntax) stays out of the package graph
// Xcode resolves.
package.dependencies.append(
  Context.environment["V57_LOCAL"] == nil
    ? .package(url: "https://github.com/v57/SwiftUI.git", branch: "main") : .package(path: "../../SwiftUI"))
for target in package.targets where target.name == "ComponentApp" {
  target.dependencies.append(.product(name: "SwiftUI", package: "SwiftUI"))
}
// The entry point, Sources/Component/ComponentMain.swift, which the Xcode project builds on Apple platforms.
let entryDependencies: [Target.Dependency] = ["ComponentApp", .product(name: "SwiftUI", package: "SwiftUI")]
let entrySettings: [SwiftSetting] = [
  .enableUpcomingFeature("ApproachableConcurrency"), .defaultIsolation(MainActor.self),
  .enableUpcomingFeature("MemberImportVisibility"),
]
#if os(Windows)
// On Windows the catalog is a DLL the SwiftUI WinUI host loads (SwiftUI's Windows/scripts/build-app.ps1 -PackagePath
// <this package> -Product ComponentWinUI).
package.targets.append(.target(name: "Component", dependencies: entryDependencies, swiftSettings: entrySettings))
package.products.append(.library(name: "ComponentWinUI", type: .dynamic, targets: ["Component"]))
#elseif os(Linux)
// On Linux the catalog is an executable on SwiftUI's GTK backend (in App/: V57_LOCAL=1 swift build --product
// Component; SwiftUI's Linux/scripts/build-app stages it with a .desktop file).
package.targets.append(
  .executableTarget(name: "Component", dependencies: entryDependencies, swiftSettings: entrySettings))
package.products.append(.executable(name: "Component", targets: ["Component"]))
#endif
#endif
