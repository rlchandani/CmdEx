// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ShortcutBar",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: "ShortcutBarCore"),
    ],
    targets: [
        .executableTarget(
            name: "ShortcutBar",
            dependencies: [
                .product(name: "ShortcutBarCore", package: "ShortcutBarCore"),
            ],
            path: "ShortcutBar",
            exclude: ["Info.plist", "ShortcutBar.entitlements"]
        ),
    ]
)
