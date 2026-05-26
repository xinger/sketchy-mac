// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SketchyMac",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(name: "SketchyCore", targets: ["SketchyCore"]),
        .executable(name: "SketchyMac", targets: ["SketchyMac"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.2")
    ],
    targets: [
        .target(name: "SketchyCore"),
        .executableTarget(
            name: "SketchyMac",
            dependencies: [
                "SketchyCore",
                .product(name: "Sparkle", package: "Sparkle")
            ]
        ),
        .testTarget(name: "SketchyCoreTests", dependencies: ["SketchyCore"])
    ]
)
