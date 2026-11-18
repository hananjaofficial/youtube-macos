// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "YouTube",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "YouTube",
            path: "Sources"
        )
    ],
    swiftLanguageVersions: [.v5]
)
