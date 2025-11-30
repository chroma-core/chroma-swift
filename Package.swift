// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "chroma-swift",
    platforms: [
        .iOS(.v16),
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
            url: "https://github.com/ml-explore/mlx-swift-examples",
            exact: "2.25.6"
        )
    ],
    targets: [
        .target(
            name: "Chroma",
            dependencies: [
                "chroma_swiftFFI",
                .product(name: "MLXEmbedders", package: "mlx-swift-examples")
            ],
            path: "Chroma/Sources",
            linkerSettings: [
                .linkedFramework("SystemConfiguration")
            ]
        ),
        .binaryTarget(
            name: "chroma_swiftFFI",
            url: "https://github.com/chroma-core/chroma-swift/releases/download/untagged-9bb63757553b689712e7/chroma_swift_framework.xcframework.zip",
            checksum: "d438e2d46544947c59261fda17b2640c9b452e3afbdcdd3d1b2c28bee82c3d51"
        )
    ]
)
