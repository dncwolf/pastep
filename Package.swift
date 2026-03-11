// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "pastep",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "pastep",
            path: "Sources/pastep"
        )
    ]
)
