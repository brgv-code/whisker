// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Whisker",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "WhiskerCore"),
        .executableTarget(name: "Whisker", dependencies: ["WhiskerCore"]),
        .testTarget(name: "WhiskerCoreTests", dependencies: ["WhiskerCore"]),
    ]
)
