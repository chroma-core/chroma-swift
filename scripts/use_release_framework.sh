#!/bin/bash
set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
TARGET_PKG="$ROOT/Package.swift"

# Intentionally no baked-in defaults; pass URL + checksum explicitly.
if [[ $# -lt 2 ]]; then
  echo "usage: $0 <framework-zip-url> <checksum>" >&2
  echo "tip: after you publish a new release, update this script with fresh defaults if you want them" >&2
  exit 1
fi

URL="$1"
CHECKSUM="$2"

cat > "$TARGET_PKG" <<EOF
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
            url: "$URL",
            checksum: "$CHECKSUM"
        )
    ]
)
EOF
echo "Package.swift restored to use the published XCFramework (url=$URL)."
