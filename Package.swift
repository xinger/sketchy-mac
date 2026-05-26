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
    targets: [
        .target(name: "SketchyCore"),
        .executableTarget(name: "SketchyMac", dependencies: ["SketchyCore"]),
        .testTarget(name: "SketchyCoreTests", dependencies: ["SketchyCore"])
    ]
)
