// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CmdEx",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: "CmdExCore"),
    ],
    targets: [
        .executableTarget(
            name: "CmdEx",
            dependencies: [
                .product(name: "CmdExCore", package: "CmdExCore"),
            ],
            path: "CmdEx",
            exclude: ["Info.plist", "CmdEx.entitlements"]
        ),
    ]
)
