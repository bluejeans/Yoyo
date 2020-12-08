// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "Yoyo",
    platforms: [
        .macOS(.v10_10), .iOS(.v10), .watchOS(.v3), .tvOS(.v10)
    ],
    products: [
        .library(name: "Yoyo", targets: ["Yoyo"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Yoyo",
            dependencies: []),
        .testTarget(
            name: "YoyoTests",
            dependencies: ["Yoyo"])
    ]
)
