// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ShortcutBarCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ShortcutBarCore", targets: ["ShortcutBarCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.17.0"),
    ],
    targets: [
        .target(
            name: "ShortcutBarCore",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            path: "Sources/ShortcutBarCore"
        ),
        .testTarget(
            name: "ShortcutBarCoreTests",
            dependencies: ["ShortcutBarCore"],
            path: "Tests/ShortcutBarCoreTests",
            resources: [
                .copy("Fixtures")
            ]
        ),
    ]
)
