// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "xclean",
    products: [
        .library(
            name: "XCleanCore",
            targets: ["XCleanCore"]
        ),
        .executable(
            name: "xclean",
            targets: ["xclean"]
        ),
    ],
    targets: [
        .target(
            name: "XCleanCore"
        ),
        .executableTarget(
            name: "xclean",
            dependencies: ["XCleanCore"]
        ),
        .testTarget(
            name: "XCleanCoreTests",
            dependencies: ["XCleanCore"]
        ),
    ]
)
