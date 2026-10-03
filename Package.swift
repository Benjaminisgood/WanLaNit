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
            // The course JSON lives at the repo root so the Xcode app target
            // can copy the same files. SwiftPM only generates Bundle.module
            // and copies resources that sit inside the target path.
            path: ".",
            exclude: [
                "App",
                "Tests",
                "scripts",
                ".github",
                "README.md",
                "project.yml",
                "CREDITS.md"
            ],
            sources: ["Sources/ThaiLearnCore"],
            resources: [
                .copy("Content")
            ]
        ),
        .testTarget(
            name: "ThaiLearnCoreTests",
            dependencies: ["ThaiLearnCore"],
            path: "Tests/ThaiLearnCoreTests"
        )
    ]
)
