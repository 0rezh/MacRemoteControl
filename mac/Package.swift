// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacRemote",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/swhitty/FlyingFox.git", from: "0.27.1"),
    ],
    targets: [
        .executableTarget(
            name: "MacRemote",
            dependencies: [.product(name: "FlyingFox", package: "FlyingFox")],
            path: "Sources/MacRemote",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
