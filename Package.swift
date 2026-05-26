// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Sketchy",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(name: "SketchyCore", targets: ["SketchyCore"]),
        .executable(name: "Sketchy", targets: ["Sketchy"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.2")
    ],
    targets: [
        .target(name: "SketchyCore"),
        .executableTarget(
            name: "Sketchy",
            dependencies: [
                "SketchyCore",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            exclude: ["Resources"]
        ),
        .testTarget(name: "SketchyCoreTests", dependencies: ["SketchyCore"])
    ]
)
