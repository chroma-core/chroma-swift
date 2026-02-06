#!/usr/bin/swift

import Foundation

// MARK: - Configuration

struct DependencyConfig {
    let name: String
    let url: String
    let version: String?
    let branch: String?
    let products: [String]
    
    init(name: String, url: String, version: String? = nil, branch: String? = nil, products: [String] = []) {
        self.name = name
        self.url = url
        self.version = version
        self.branch = branch
        self.products = products
    }
}

struct PackageConfig {
    let name: String
    let platforms: [String: String]
    let dependencies: [DependencyConfig]
    let targetDependencies: [String]
}

// MARK: - Package Configuration

let packageConfig = PackageConfig(
    name: "Chroma",
    platforms: [
        "macOS": ".v14",
        "iOS": ".v17"
    ],
    dependencies: [
        DependencyConfig(
            name: "mlx-swift-lm",
            url: "https://github.com/ml-explore/mlx-swift-lm",
            branch: "main",
            products: ["MLXEmbedders"]
        )
    ],
    targetDependencies: [
        "chroma_swift_framework",
        ".product(name: \"MLXEmbedders\", package: \"mlx-swift-lm\")"
    ]
)

// MARK: - Package.swift Generator

// List of source files to include in the package
let sourceFiles = ["ChromaSwift.swift", "ChromaEmbedder.swift", "ChromaEmbedderExtensions.swift"]

func generatePackageSwift(config: PackageConfig) -> String {
    var content = """
    // swift-tools-version: 6.2
    import PackageDescription

    let package = Package(
        name: "\(config.name)",
        platforms: [
    """
    
    // Add platforms
    for (platform, version) in config.platforms {
        content += "\n        .\(platform)(\(version)),"
    }
    content = String(content.dropLast()) // Remove trailing comma
    
    content += """
    
        ],
        products: [
            .library(name: "\(config.name)", targets: ["\(config.name)"])
        ],
    """
    
    // Add dependencies if any
    if !config.dependencies.isEmpty {
        content += "    dependencies: [\n"
        for dep in config.dependencies {
            if let version = dep.version {
                content += "        .package(url: \"\(dep.url)\", from: \"\(version)\"),\n"
            } else if let branch = dep.branch {
                content += "        .package(url: \"\(dep.url)\", branch: \"\(branch)\"),\n"
            } else {
                content += "        .package(url: \"\(dep.url)\"),\n"
            }
        }
        content += "    ],\n"
    }
    
    content += """
        targets: [
            .target(
                name: "\(config.name)",
                dependencies: [
    """
    
    // Add target dependencies
    for dep in config.targetDependencies {
        if dep.hasPrefix(".product") {
            content += "                \(dep),\n"
        } else {
            content += "                \"\(dep)\",\n"
        }
    }
    
    content += """
                ],
                path: "Sources",
                linkerSettings: [.linkedFramework("SystemConfiguration")]
            ),
            .binaryTarget(
                name: "chroma_swift_framework",
                path: "chroma_swift_framework.xcframework"
            )
        ]
    )
    """
    
    return content
}

// MARK: - File Operations

func writePackageSwift(to path: String, content: String) {
    do {
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        print("✅ Successfully updated Package.swift")
    } catch {
        print("❌ Error writing Package.swift: \(error)")
        exit(1)
    }
}

func getCurrentDirectory() -> String {
    return FileManager.default.currentDirectoryPath
}

// MARK: - Main Execution

func main() {
    print("🔄 Updating Chroma package dependencies...")
    
    let currentDir = getCurrentDirectory()
    let packagePath = "\(currentDir)/Package.swift"
    
    // Check if Package.swift exists
    guard FileManager.default.fileExists(atPath: packagePath) else {
        print("❌ Package.swift not found at \(packagePath)")
        exit(1)
    }
    
    // Generate new Package.swift content
    let newContent = generatePackageSwift(config: packageConfig)
    
    // Write the updated Package.swift
    writePackageSwift(to: packagePath, content: newContent)
    
    // Rename the chroma_swift.swift file to ChromaSwift.swift if it exists
    let oldFilePath = "\(currentDir)/Sources/chroma_swift.swift"
    let newFilePath = "\(currentDir)/Sources/ChromaSwift.swift"
    
    if FileManager.default.fileExists(atPath: oldFilePath) {
        do {
            try FileManager.default.moveItem(atPath: oldFilePath, toPath: newFilePath)
            print("✅ Successfully renamed chroma_swift.swift to ChromaSwift.swift")
        } catch {
            print("⚠️ Could not rename chroma_swift.swift: \(error)")
        }
    }
    
    print("📦 Package.swift has been updated with the following dependencies:")
    for dep in packageConfig.dependencies {
        print("  - \(dep.name): \(dep.url)")
        if !dep.products.isEmpty {
            print("    Products: \(dep.products.joined(separator: ", "))")
        }
    }
    
    print("\n🏁 Update complete!")
}

// Run the script
main()
