// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "pastep",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        // Foundation だけに依存するロジック層（履歴・監視・ペースト手順・メニュー内容）
        .target(name: "pastepCore", path: "Sources/pastepCore"),
        // AppKit / Carbon / CoreGraphics への薄いアダプタ
        .target(name: "pastepMac", dependencies: ["pastepCore"], path: "Sources/pastepMac"),
        .executableTarget(name: "pastep", dependencies: ["pastepCore", "pastepMac"], path: "Sources/pastep"),
        .testTarget(
            name: "pastepTests",
            dependencies: ["pastepCore", "pastepMac"],
            path: "Tests/pastepTests"
        )
    ]
)
