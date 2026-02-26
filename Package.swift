// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WallSpan",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "WallSpan",
            path: "Sources"
        )
    ]
)
