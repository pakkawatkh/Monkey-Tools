// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "monkey-tools",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "monkey-tools",
            targets: ["MonkeyTools"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MonkeyTools",
            dependencies: [],
            path: "Sources/MonkeyTools"
        ),
        .testTarget(
            name: "MonkeyToolsTests",
            dependencies: ["MonkeyTools"],
            path: "Tests/MonkeyToolsTests"
        )
    ]
)
