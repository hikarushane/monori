// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MonoriCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MonoriCore", targets: ["MonoriCore"])
    ],
    targets: [
        .target(
            name: "MonoriCore",
            resources: [.process("Assets")]
        ),
        .testTarget(
            name: "MonoriCoreTests",
            dependencies: ["MonoriCore"],
            resources: [.process("Fixtures")]
        )
    ]
)
