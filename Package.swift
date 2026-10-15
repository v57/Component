// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "Component", platforms: [.macOS(.v14), .iOS(.v17)],
  products: [.library(name: "ComponentKit", targets: ["ComponentKit"])],
  targets: [
    .target(name: "ComponentKit"),
    .testTarget(name: "ComponentKitTests", dependencies: ["ComponentKit"]),
  ])
