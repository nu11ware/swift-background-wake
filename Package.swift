// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "swift-background-wake",
  platforms: [
    .iOS(.v15),
    .macCatalyst(.v15),
    .macOS(.v12),
    .tvOS(.v15),
    .visionOS(.v1),
    .watchOS(.v9),
  ],
  products: [
    .library(name: "BackgroundWake", targets: ["BackgroundWake"])
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", from: "1.3.0")
  ],
  targets: [
    .target(name: "BackgroundWake"),
    .testTarget(
      name: "BackgroundWakeTests",
      dependencies: [
        "BackgroundWake",
        .target(name: "StandInBackgroundTasks", condition: .when(platforms: [.macOS])),
        .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
      ]
    ),
    .target(
      name: "StandInBackgroundTasks",
      path: "Tests/StandInBackgroundTasks"
    ),
  ],
  swiftLanguageModes: [.v6]
)
