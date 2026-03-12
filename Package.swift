// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "pastep",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(name: "pastepCore", path: "Sources/pastepCore"),
        .executableTarget(name: "pastep", dependencies: ["pastepCore"], path: "Sources/pastep"),
        .testTarget(
            name: "pastepTests",
            dependencies: ["pastepCore"],
            path: "Tests/pastepTests"
        )
    ]
)
