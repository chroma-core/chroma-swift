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
            url: "https://github.com/chroma-core/chroma-swift/releases/download/1.0.0/chroma_swift_framework.xcframework.zip",
            checksum: "234c8fa3aa14d5d7677a7549cba0ad1dd7a8e3a4bced6738f5c9c69074317aec"
        )
    ]
)