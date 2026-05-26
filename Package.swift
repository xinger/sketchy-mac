// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SketchyMac",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(name: "SketchyCore", targets: ["SketchyCore"])
    ],
    targets: [
        .target(name: "SketchyCore"),
        .testTarget(name: "SketchyCoreTests", dependencies: ["SketchyCore"])
    ]
)
