#!/bin/bash

# Simple wrapper script to update Chroma package dependencies
# Usage: ./scripts/update_deps.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔄 Updating Chroma package dependencies..."
echo "🔄 This will rename chroma_swift.swift to ChromaSwift.swift if needed"
echo "📁 Working directory: $PROJECT_ROOT"

cd "$PROJECT_ROOT/Chroma"

# Run the Swift dependency update script
swift "$SCRIPT_DIR/update_dependencies.swift"

echo ""
echo "🚀 To test the updated package, run:"
echo "   cd Chroma && swift package resolve"
echo "   cd Chroma && swift build"
