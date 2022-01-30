// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ConfigurableObjectManager",
    platforms: [.macOS(.v10_15), .iOS(.v13), .watchOS(.v6), .tvOS(.v13)],
    products: [
        .library(
            name: "ConfigurableObjectManager",
            targets: ["ConfigurableObjectManager"]),
    ],
    targets: [
        .target(
            name: "ConfigurableObjectManager",
            dependencies: []),
        .testTarget(
            name: "ConfigurableObjectManagerTests",
            dependencies: ["ConfigurableObjectManager"]),
    ]
)
