// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ChapterlyCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ChapterlyCore", targets: ["ChapterlyCore"])
    ],
    targets: [
        .target(
            name: "ChapterlyCore",
            resources: [.process("Assets")]
        ),
        .testTarget(
            name: "ChapterlyCoreTests",
            dependencies: ["ChapterlyCore"],
            resources: [.process("Fixtures")]
        )
    ]
)
