// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MonoriCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MonoriCore", targets: ["MonoriCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", .upToNextMajor(from: "0.9.19"))
    ],
    targets: [
        .target(
            name: "MonoriCore",
            dependencies: [.product(name: "ZIPFoundation", package: "ZIPFoundation")],
            resources: [.process("Assets")]
        ),
        .testTarget(
            name: "MonoriCoreTests",
            dependencies: ["MonoriCore"],
            resources: [.process("Fixtures")]
        )
    ]
)
