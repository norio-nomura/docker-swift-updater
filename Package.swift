// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "docker-swift-updater",
    dependencies: [
        .package(url: "https://github.com/norio-nomura/SwiftBacktrace", .branch("master"))
    ],
    targets: [
        .target(name: "docker-swift-updater",
            dependencies: ["SwiftBacktrace"]),
    ]
)
