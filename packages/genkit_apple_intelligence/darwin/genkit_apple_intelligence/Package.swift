// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "genkit_apple_intelligence",
  platforms: [
    // The app's own deployment targets. Foundation Models needs iOS / macOS
    // 26, so every use of it is behind #available, and the framework ends up
    // weak-linked: the app still launches on older systems.
    .iOS("17.0"),
    .macOS("12.0"),
  ],
  products: [
    .library(name: "genkit-apple-intelligence", targets: ["genkit_apple_intelligence"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework")
  ],
  targets: [
    .target(
      name: "genkit_apple_intelligence",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework")
      ]
    )
  ]
)
