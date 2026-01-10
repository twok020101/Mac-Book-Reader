// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BookReaderFeature",
    platforms: [.macOS(.v14)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "BookReaderFeature",
            targets: ["BookReaderFeature"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/witekbobrowski/EPUBKit.git", from: "0.2.2"),
        .package(url: "https://github.com/google/generative-ai-swift", from: "0.4.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "BookReaderFeature",
            dependencies: [
                "EPUBKit",
                .product(name: "GoogleGenerativeAI", package: "generative-ai-swift")
            ]
        ),
        .testTarget(
            name: "BookReaderFeatureTests",
            dependencies: [
                "BookReaderFeature"
            ]
        ),
    ]
)
