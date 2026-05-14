// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "touchbar-temp",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "touchbar-temp",
            path: "Sources/touchbar-temp"
        )
    ]
)
