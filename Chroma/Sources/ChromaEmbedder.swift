// Copyright 2025 Chroma
// Licensed under the Apache License, Version 2.0
// Integration with MLXEmbedders for text embedding generation

import Foundation
import MLX
import MLXEmbedders
import Hub

/// ChromaEmbedder provides a simplified interface for generating text embeddings
/// compatible with Chroma vector database operations.
public class ChromaEmbedder {
    
    /// Available embedding models from MLXEmbedders
    public enum EmbeddingModel: String, CaseIterable {
        case bgeMicro = "TaylorAI/bge-micro-v2"
        case gteTiny = "TaylorAI/gte-tiny"
        case miniLML6 = "sentence-transformers/all-MiniLM-L6-v2"
        case miniLML12 = "sentence-transformers/all-MiniLM-L12-v2"
        case bgeSmall = "BAAI/bge-small-en-v1.5"
        case bgeBase = "BAAI/bge-base-en-v1.5"
        case bgeLarge = "BAAI/bge-large-en-v1.5"
        case mixedbreadLarge = "mixedbread-ai/mxbai-embed-large-v1"
        
        /// Display name for the model
        public var displayName: String {
            switch self {
            case .bgeMicro: return "BGE Micro v2"
            case .gteTiny: return "GTE Tiny"
            case .miniLML6: return "MiniLM L6 v2"
            case .miniLML12: return "MiniLM L12 v2"
            case .bgeSmall: return "BGE Small EN v1.5"
            case .bgeBase: return "BGE Base EN v1.5"
            case .bgeLarge: return "BGE Large EN v1.5"
            case .mixedbreadLarge: return "Mixedbread Large v1"
            }
        }
        
        /// Embedding dimensions for each model
        public var embeddingDimensions: Int {
            switch self {
            case .bgeMicro: return 384
            case .gteTiny: return 384
            case .miniLML6: return 384
            case .miniLML12: return 384
            case .bgeSmall: return 384
            case .bgeBase: return 768
            case .bgeLarge: return 1024
            case .mixedbreadLarge: return 1024
            }
        }
        
        /// Convert to MLXEmbedders ModelConfiguration
        internal var modelConfiguration: ModelConfiguration {
            switch self {
            case .bgeMicro: return .bge_micro
            case .gteTiny: return .gte_tiny
            case .miniLML6: return .minilm_l6
            case .miniLML12: return .minilm_l12
            case .bgeSmall: return .bge_small
            case .bgeBase: return .bge_base
            case .bgeLarge: return .bge_large
            case .mixedbreadLarge: return .mixedbread_large
            }
        }
    }
    
    public let model: EmbeddingModel
    public let embeddingDimensions: Int
    
    // ModelContainer actor manages the model loading and inference
    private var modelContainer: ModelContainer?
    internal var isInitialized = false
    private let hubApi = HubApi()

    /// Initialize ChromaEmbedder with a specific model
    /// - Parameter model: The embedding model to use
    public init(model: EmbeddingModel = .miniLML6) {
        self.model = model
        self.embeddingDimensions = model.embeddingDimensions
    }
    
    /// Load the embedding model (call this before generating embeddings)
    /// - Throws: ChromaEmbedderError if model loading fails
    public func loadModel() async throws {
        do {
            // Use MLXEmbedders.loadModelContainer like in the working example
            modelContainer = try await MLXEmbedders.loadModelContainer(
                hub: hubApi,
                configuration: model.modelConfiguration
            )
            isInitialized = true
        } catch {
            throw ChromaEmbedderError.modelLoadingFailed(model.displayName, error)
        }
    }
    
    /// Generate embeddings for a single text
    /// - Parameter text: The text to embed
    /// - Returns: Embedding as an array of floats compatible with Chroma
    /// - Throws: ChromaEmbedderError if embedding generation fails
    public func embed(text: String) async throws -> [Float] {
        guard isInitialized, let container = modelContainer else {
            throw ChromaEmbedderError.modelNotLoaded
        }

        return await encodeText(text, container: container)
    }

    /// Generate embeddings for multiple texts using batched inference
    /// - Parameter texts: Array of texts to embed
    /// - Returns: 2D array of embeddings compatible with Chroma addDocuments/queryCollection
    /// - Throws: ChromaEmbedderError if embedding generation fails
    public func embed(texts: [String]) async throws -> [[Float]] {
        guard isInitialized, let container = modelContainer else {
            throw ChromaEmbedderError.modelNotLoaded
        }

        guard !texts.isEmpty else {
            return []
        }

        var allEmbeddings: [[Float]] = []

        let batchSize = 32
        for chunk in texts.chunked(into: batchSize) {
            let batchEmbeddings = await encodeBatch(chunk, container: container)
            allEmbeddings.append(contentsOf: batchEmbeddings)
        }

        return allEmbeddings
    }

    // Encode a single text using MLXEmbedders
    private func encodeText(_ text: String, container: ModelContainer) async -> [Float] {
        return await container.perform { model, tokenizer, pooling in
            let tokens = tokenizer.encode(text: text)
            let input = MLXArray(tokens).expandedDimensions(axis: 0)
            let tokenTypes = MLXArray.zeros(like: input)
            let output = pooling(
                model(input, positionIds: nil, tokenTypeIds: tokenTypes, attentionMask: nil),
                normalize: true
            )
            eval(output)
            return output.asArray(Float.self)
        }
    }

    // Encode a batch of texts with padding and attention masking
    private func encodeBatch(_ texts: [String], container: ModelContainer) async -> [[Float]] {
        return await container.perform { model, tokenizer, pooling in
            let tokensList = texts.map { tokenizer.encode(text: $0) }
            let maxLen = tokensList.map(\.count).max() ?? 0

            var padded = [[Int]]()
            var mask = [[Float]]()
            for tokens in tokensList {
                let paddingCount = maxLen - tokens.count
                let padToken = tokenizer.eosTokenId ?? 0
                padded.append(tokens + Array(repeating: padToken, count: paddingCount))
                mask.append(
                    Array(repeating: Float(1.0), count: tokens.count) +
                    Array(repeating: Float(0.0), count: paddingCount)
                )
            }

            let input = MLXArray(padded.flatMap { $0 }).reshaped(texts.count, maxLen)
            let attentionMask = MLXArray(mask.flatMap { $0 }).reshaped(texts.count, maxLen)

            let tokenTypes = MLXArray.zeros(like: input)
            let modelOutput = model(input, positionIds: nil, tokenTypeIds: tokenTypes, attentionMask: attentionMask)
            let pooled = pooling(modelOutput, mask: attentionMask, normalize: true)
            eval(pooled)

            // Extract individual embeddings from the batch
            var embeddings = [[Float]]()
            for i in 0..<texts.count {
                embeddings.append(pooled[i].asArray(Float.self))
            }
            return embeddings
        }
    }
}

/// Errors that can occur during embedding operations
public enum ChromaEmbedderError: Error, LocalizedError {
    case modelNotLoaded
    case modelLoadingFailed(String, Error)
    case embeddingFailed([String], Error)
    
    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Embedding model not loaded. Call loadModel() first."
        case .modelLoadingFailed(let modelName, let error):
            return "Failed to load embedding model '\(modelName)': \(error.localizedDescription)"
        case .embeddingFailed(let texts, let error):
            return "Failed to generate embeddings for \(texts.count) text(s): \(error.localizedDescription)"
        }
    }
}

// MARK: - Array Extension for Chunking

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
