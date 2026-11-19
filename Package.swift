// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "hanstePlayer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "hanstePlayer",
            path: "Sources"
        )
    ],
    swiftLanguageVersions: [.v5]
)
