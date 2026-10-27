// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "Component", platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v18), .visionOS(.v2)],
  products: [.library(name: "ComponentKit", targets: ["ComponentKit"])],
  targets: [
    .target(name: "ComponentKit"),
    .testTarget(name: "ComponentKitTests", dependencies: ["ComponentKit"]),
  ])

#if os(Windows) || os(Linux)
// Off Apple platforms SwiftUI is v57/SwiftUI: GitHub's main branch, or the checkout next to this one with
// `V57_LOCAL=1`. On Windows the catalog is also a DLL the SwiftUI WinUI host loads
// (SwiftUI's Windows/scripts/build-app.ps1 -PackagePath <this package> -Product ComponentWinUI).
let swiftUI: Package.Dependency = Context.environment["V57_LOCAL"] == nil
  ? .package(url: "https://github.com/v57/SwiftUI.git", branch: "main") : .package(path: "../SwiftUI")
package.dependencies.append(swiftUI)
for target in package.targets where target.name == "ComponentKit" {
  target.dependencies.append(.product(name: "SwiftUI", package: "SwiftUI"))
}
#if os(Windows)
package.targets.append(
  .target(
    name: "ComponentCatalog", dependencies: ["ComponentKit", .product(name: "SwiftUI", package: "SwiftUI")],
    path: "Component",
    swiftSettings: [
      .enableUpcomingFeature("ApproachableConcurrency"), .defaultIsolation(MainActor.self),
      .enableUpcomingFeature("MemberImportVisibility"),
    ]))
package.products.append(.library(name: "ComponentWinUI", type: .dynamic, targets: ["ComponentCatalog"]))
#elseif os(Linux)
// On Linux the catalog is an executable on SwiftUI's GTK backend (SwiftUI's Linux/scripts/build-app stages it with a
// .desktop file).
package.targets.append(
  .executableTarget(
    name: "ComponentCatalog", dependencies: ["ComponentKit", .product(name: "SwiftUI", package: "SwiftUI")],
    path: "Component",
    swiftSettings: [
      .enableUpcomingFeature("ApproachableConcurrency"), .defaultIsolation(MainActor.self),
      .enableUpcomingFeature("MemberImportVisibility"),
    ]))
package.products.append(.executable(name: "Component", targets: ["ComponentCatalog"]))
#endif
#endif
