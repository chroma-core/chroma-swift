#!/bin/bash
set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
TARGET_PKG="$ROOT/Package.swift"
FRAMEWORK_DIR="$ROOT/../chroma/rust/swift_bindings/Chroma/chroma_swift_framework.xcframework"

if [[ ! -d "$FRAMEWORK_DIR" ]]; then
  echo "error: $FRAMEWORK_DIR not found. Run ./build_swift_package.sh first." >&2
  exit 1
fi

cat > "$TARGET_PKG" <<'EOF'
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
            path: "../chroma/rust/swift_bindings/Chroma/chroma_swift_framework.xcframework"
        )
    ]
)
EOF
echo "Package.swift now points to the locally built XCFramework."
