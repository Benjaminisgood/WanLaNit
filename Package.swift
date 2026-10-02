// swift-tools-version: 5.9
import PackageDescription

// 应用要求 macOS 14，写在 project.yml。这里不限制平台，Linux 上才能跑 swift test。

let package = Package(
    name: "ThaiLearn",
    defaultLocalization: "zh-Hans",
    products: [
        .library(name: "ThaiLearnCore", targets: ["ThaiLearnCore"])
    ],
    targets: [
        .target(
            name: "ThaiLearnCore",
            path: "Sources/ThaiLearnCore"
        ),
        .testTarget(
            name: "ThaiLearnCoreTests",
            dependencies: ["ThaiLearnCore"],
            path: "Tests/ThaiLearnCoreTests"
        )
    ]
)
