// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "chroma-swift",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ChromaSwift",
            targets: ["Chroma"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/ml-explore/mlx-swift-lm",
            from: "2.30.3"
        )
    ],
    targets: [
        .target(
            name: "Chroma",
            dependencies: [
                "chroma_swiftFFI",
                .product(name: "MLXEmbedders", package: "mlx-swift-lm")
            ],
            path: "Chroma/Sources",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ],
            linkerSettings: [
                .linkedFramework("SystemConfiguration")
            ]
        ),
        .binaryTarget(
            name: "chroma_swiftFFI",
            url: "https://github.com/chroma-core/chroma-swift/releases/download/1.0.1/chroma_swift_framework.xcframework.zip",
            checksum: "d438e2d46544947c59261fda17b2640c9b452e3afbdcdd3d1b2c28bee82c3d51"
        )
    ]
)
