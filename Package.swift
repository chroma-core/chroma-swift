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
            url: "https://github.com/andrewgleave/chroma-swift/releases/download/1.0.2/chroma_swift_framework.xcframework.zip",
            checksum: "938c3d396feddb9c985ca796a99b8c5612048939780d8cae648cacd74e874147"
        )
    ]
)
