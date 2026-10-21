// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EatBetterCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "EatBetterCore", targets: ["EatBetterCore"])
    ],
    targets: [
        .target(
            name: "EatBetterCore",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "EatBetterCoreTests",
            dependencies: ["EatBetterCore"]
        )
    ]
)
