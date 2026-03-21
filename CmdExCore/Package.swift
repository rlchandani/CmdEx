// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CmdExCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "CmdExCore", targets: ["CmdExCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.17.0"),
    ],
    targets: [
        .target(
            name: "CmdExCore",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            path: "Sources/CmdExCore"
        ),
        .testTarget(
            name: "CmdExCoreTests",
            dependencies: ["CmdExCore"],
            path: "Tests/CmdExCoreTests",
            resources: [
                .copy("Fixtures")
            ]
        ),
    ]
)
