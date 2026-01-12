// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BioMotionPro",
    platforms: [
        .macOS(.v14)  // macOS Sonoma for ContentUnavailableView
    ],
    products: [
        .executable(name: "BioMotionPro", targets: ["BioMotionPro"])
    ],
    targets: [
        .executableTarget(
            name: "BioMotionPro",
            path: "Sources",
            resources: [
                .copy("../Resources/Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "BioMotionProTests",
            dependencies: ["BioMotionPro"],
            path: "Tests"
        )
    ]
)
