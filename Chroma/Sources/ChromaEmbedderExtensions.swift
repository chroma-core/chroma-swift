// Copyright 2025 Chroma
// Licensed under the Apache License, Version 2.0
// Convenience extensions for integrating ChromaEmbedder with Chroma database operations

import Foundation

/// Convenience extensions for ChromaEmbedder to work seamlessly with Chroma database operations
extension ChromaEmbedder {
    
    /// Add documents to a Chroma collection with automatic text embedding
    /// - Parameters:
    ///   - collectionName: Name of the collection to add documents to
    ///   - ids: Unique identifiers for each document
    ///   - texts: Array of text documents to embed and add
    /// - Returns: Number of documents added
    /// - Throws: ChromaEmbedderError or Chroma database errors
    public func addDocuments(
        to collectionName: String,
        ids: [String],
        texts: [String]
    ) async throws -> UInt32 {
        guard ids.count == texts.count else {
            throw ChromaEmbedderError.embeddingFailed(texts,
                NSError(domain: "ChromaEmbedder", code: 1,
                       userInfo: [NSLocalizedDescriptionKey: "Number of IDs must match number of texts"]))
        }
        
        // Generate embeddings for all texts
        let embeddings = try await self.embed(texts: texts)
        
        // Add documents to Chroma collection
        return try Chroma.addDocuments(
            collectionName: collectionName,
            ids: ids,
            embeddings: embeddings,
            documents: texts
        )

    }
    
    /// Query a Chroma collection using text queries with automatic embedding
    /// - Parameters:
    ///   - collectionName: Name of the collection to query
    ///   - queryTexts: Array of text queries to embed and search for
    ///   - nResults: Maximum number of results to return per query
    ///   - whereFilter: Optional filter condition
    ///   - ids: Optional list of IDs to restrict search to
    ///   - include: Optional list of fields to include in results
    /// - Returns: Query results from Chroma
    /// - Throws: ChromaEmbedderError or Chroma database errors
    public func queryCollection(
        _ collectionName: String,
        queryTexts: [String],
        nResults: UInt32 = 10,
        whereFilter: String? = nil,
        ids: [String]? = nil,
        include: [String]? = nil
    ) async throws -> QueryResult {
        // Generate embeddings for query texts
        let queryEmbeddings = try await self.embed(texts: queryTexts)
        
        // Query Chroma collection
        return try Chroma.queryCollection(
            collectionName: collectionName,
            queryEmbeddings: queryEmbeddings,
            nResults: nResults,
            whereFilter: whereFilter,
            ids: ids,
            include: include
        )
    }
    
    /// Query a Chroma collection using a single text query
    /// - Parameters:
    ///   - collectionName: Name of the collection to query
    ///   - queryText: Text query to embed and search for
    ///   - nResults: Maximum number of results to return
    ///   - whereFilter: Optional filter condition
    ///   - ids: Optional list of IDs to restrict search to
    ///   - include: Optional list of fields to include in results
    /// - Returns: Query results from Chroma
    /// - Throws: ChromaEmbedderError or Chroma database errors
    public func queryCollection(
        _ collectionName: String,
        queryText: String,
        nResults: UInt32 = 10,
        whereFilter: String? = nil,
        ids: [String]? = nil,
        include: [String]? = nil
    ) async throws -> QueryResult {
        return try await queryCollection(
            collectionName,
            queryTexts: [queryText],
            nResults: nResults,
            whereFilter: whereFilter,
            ids: ids,
            include: include
        )
    }
}

/// Convenience methods for creating and managing collections with embedding models
public extension ChromaEmbedder {
    
    /// Create a collection using the Chroma API
    /// - Parameters:
    ///   - name: Name of the collection
    /// - Returns: Collection ID as String
    /// - Throws: Chroma database errors
    /// - Note: This is a convenience wrapper around Chroma.createCollection
    func createCollection(name: String) throws -> String {
        return try Chroma.createCollection(name: name)
    }
    
    /// Get information about the embedding model
    /// - Returns: Dictionary containing model information
    var modelInfo: [String: Any] {
        return [
            "model_id": model.rawValue,
            "model_name": model.displayName,
            "embedding_dimensions": embeddingDimensions,
            "embedder_type": "MLXEmbedders",
            "is_loaded": isInitialized
        ]
    }
}
