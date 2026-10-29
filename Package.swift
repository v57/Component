// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "Component", platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v18), .visionOS(.v2)],
  products: [.library(name: "ComponentKit", targets: ["ComponentKit"])],
  targets: [
    .target(
      name: "ComponentKit",
      // Release builds leave out Swift 6's dynamic actor-isolation checks: a runtime call (swift_task_isCurrentExecutor)
      // at the start of each MainActor closure handed to SwiftUI, about 1,000 of them, 7% of the kit's code. Debug
      // keeps them, so a closure that runs off the main thread still traps there.
      swiftSettings: [.unsafeFlags(["-Xfrontend", "-disable-dynamic-actor-isolation"], .when(configuration: .release))]),
    .testTarget(name: "ComponentKitTests", dependencies: ["ComponentKit"]),
  ])

#if os(Windows) || os(Linux)
// Off Apple platforms SwiftUI is v57/SwiftUI: GitHub's main branch, or the checkout next to this one with
// `V57_LOCAL=1`. The catalog app is its own package in App/.
let swiftUI: Package.Dependency = Context.environment["V57_LOCAL"] == nil
  ? .package(url: "https://github.com/v57/SwiftUI.git", branch: "main") : .package(path: "../SwiftUI")
package.dependencies.append(swiftUI)
for target in package.targets where target.name == "ComponentKit" {
  target.dependencies.append(.product(name: "SwiftUI", package: "SwiftUI"))
}
#endif
