// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "monkey-copy",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "monkey-copy",
            targets: ["MonkeyCopy"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MonkeyCopy",
            dependencies: [],
            path: "Sources/MonkeyCopy"
        ),
        .testTarget(
            name: "MonkeyCopyTests",
            dependencies: ["MonkeyCopy"],
            path: "Tests/MonkeyCopyTests"
        )
    ]
)
