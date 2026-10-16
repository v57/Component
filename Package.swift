// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "Component", platforms: [.macOS(.v14), .iOS(.v17)],
  products: [.library(name: "ComponentKit", targets: ["ComponentKit"])],
  targets: [
    // Release builds optimize for size (9% less code): the kit is SwiftUI view code, where -Osize costs no speed you'd
    // notice, and Xcode builds a package's targets at -O whatever the app sets. SwiftPM refuses unsafe flags in a
    // dependency pinned to a version (a branch or a local path is fine): drop this before the apps pin releases.
    .target(name: "ComponentKit", swiftSettings: [.unsafeFlags(["-Osize"], .when(configuration: .release))]),
    .testTarget(name: "ComponentKitTests", dependencies: ["ComponentKit"]),
  ])
