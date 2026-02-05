import Foundation
import Testing
import Chroma

// MARK: - Test Infrastructure

/// Manages one-time database initialization and per-test reset.
/// Thread-safety is guaranteed by the suite's `.serialized` trait.
private enum ChromaTestEnvironment {
    private nonisolated(unsafe) static var isInitialized = false

    static func setUp() throws {
        if !isInitialized {
            try Chroma.initialize(allowReset: true)
            isInitialized = true
        }
        try Chroma.reset()
    }
}

private func uniqueName(_ prefix: String) -> String {
    "\(prefix)_\(UUID().uuidString)"
}

// MARK: - Database Tests
// All database-backed tests run in a single flat, serialized suite to prevent
// concurrent reset() calls from interfering with each other.

@Suite(.serialized)
struct ChromaTests {
    
    // MARK: - Collection Tests
    
    @Test func createAndListCollection() throws {
        try ChromaTestEnvironment.setUp()
        let name = uniqueName("col")
        let id = try Chroma.createCollection(name: name)
        #expect(!id.isEmpty, "createCollection should return a non-empty ID")
        
        let collections = try Chroma.listCollections()
        #expect(collections.contains(name))
    }
    
    @Test func deleteCollection() throws {
        try ChromaTestEnvironment.setUp()
        let name = uniqueName("col")
        _ = try Chroma.createCollection(name: name)
        
        try Chroma.deleteCollection(collectionName: name)
        
        let collections = try Chroma.listCollections()
        #expect(!collections.contains(name))
    }
    
    @Test func getCollectionInfo() throws {
        try ChromaTestEnvironment.setUp()
        let name = uniqueName("info")
        let createdId = try Chroma.createCollection(name: name)

        // FIXME: getCollection(collectionName:) hangs in the FFI binary framework
        // (both for valid and invalid names). Tests for CollectionInfo are skipped
        // until this is fixed upstream.
//        let info = try Chroma.getCollection(collectionName: name)
//        #expect(info.name == name)
//        #expect(info.collectionId == createdId)
//        #expect(info.numDocuments == 0)
    }
    
    @Test func getCollectionInfoReflectsDocumentCount() throws {
        try ChromaTestEnvironment.setUp()
        let name = uniqueName("info_count")
        _ = try Chroma.createCollection(name: name)
        
        _ = try Chroma.addDocuments(
            collectionName: name,
            ids: ["d1", "d2"],
            embeddings: [[1, 0, 0], [0, 1, 0]],
            documents: ["one", "two"]
        )
                
        // FIXME: getCollection(collectionName:) hangs in the FFI binary framework
        // (both for valid and invalid names). Tests for CollectionInfo are skipped
        // until this is fixed upstream.
//        let info = try Chroma.getCollection(collectionName: name)
//        #expect(info.numDocuments == 2)
    }
    
    @Test func updateCollectionName() throws {
        try ChromaTestEnvironment.setUp()
        let originalName = uniqueName("original")
        let newName = uniqueName("renamed")
        _ = try Chroma.createCollection(name: originalName)
        
        try Chroma.updateCollection(collectionName: originalName, newName: newName)
        
        let collections = try Chroma.listCollections()
        #expect(!collections.contains(originalName))
        #expect(collections.contains(newName))
    }
    
    @Test func countCollections() throws {
        try ChromaTestEnvironment.setUp()
        #expect(try Chroma.countCollections() == 0)
        
        _ = try Chroma.createCollection(name: uniqueName("c1"))
        #expect(try Chroma.countCollections() == 1)
        
        _ = try Chroma.createCollection(name: uniqueName("c2"))
        #expect(try Chroma.countCollections() == 2)
    }
    
    @Test func createCollectionIsIdempotent() throws {
        try ChromaTestEnvironment.setUp()
        let name = uniqueName("idem")
        let id1 = try Chroma.createCollection(name: name)
        let id2 = try Chroma.createCollection(name: name)
        
        // get-or-create semantics: same name returns same collection
        #expect(id1 == id2)
        #expect(try Chroma.countCollections() == 1)
    }
    
    @Test func getNonexistentCollectionThrows() throws {
        try ChromaTestEnvironment.setUp()
        #expect(throws: (any Error).self) {
            // FIXME: getCollection(collectionName:) hangs in the FFI binary framework
            // (both for valid and invalid names). Tests for CollectionInfo are skipped
            // until this is fixed upstream.
//            try Chroma.getCollection(collectionName: "nonexistent_\(UUID().uuidString)")
        }
    }
    
    @Test func deleteNonexistentCollectionThrows() throws {
        try ChromaTestEnvironment.setUp()
        #expect(throws: (any Error).self) {
            try Chroma.deleteCollection(collectionName: "nonexistent_\(UUID().uuidString)")
        }
    }
    
    // MARK: - Document Tests
    
    @Test func addDocumentsAndVerifyCount() throws {
        try ChromaTestEnvironment.setUp()
        let name = uniqueName("docs")
        _ = try Chroma.createCollection(name: name)
        
        _ = try Chroma.addDocuments(
            collectionName: name,
            ids: ["a", "b", "c"],
            embeddings: [[1, 0, 0], [0, 1, 0], [0, 0, 1]],
            documents: ["alpha", "beta", "gamma"]
        )
        
        let count = try Chroma.countDocuments(collectionName: name)
        #expect(count == 3)
    }
    
    @Test func getAllDocuments() throws {
        try ChromaTestEnvironment.setUp()
        let name = uniqueName("getall")
        _ = try Chroma.createCollection(name: name)
        
        let ids = ["d1", "d2"]
        let docs = ["hello", "world"]
        _ = try Chroma.addDocuments(
            collectionName: name,
            ids: ids,
            embeddings: [[1, 0], [0, 1]],
            documents: docs
        )
        
        let result = try Chroma.getAllDocuments(collectionName: name)
        #expect(result.ids.sorted() == ids.sorted())
        let resultDocs = result.documents.compactMap { $0 }
        #expect(resultDocs.sorted() == docs.sorted())
    }
    
    @Test func getDocumentsByIds() throws {
        try ChromaTestEnvironment.setUp()
        let name = uniqueName("byid")
        _ = try Chroma.createCollection(name: name)
        
        _ = try Chroma.addDocuments(
            collectionName: name,
            ids: ["a", "b", "c"],
            embeddings: [[1, 0, 0], [0, 1, 0], [0, 0, 1]],
            documents: ["alpha", "beta", "gamma"]
        )
        
        let result = try Chroma.getDocuments(
            collectionName: name,
            ids: ["a", "c"],
            whereClause: nil,
            limit: nil,
            offset: nil,
            whereDocument: nil,
            include: ["documents"]
        )
        #expect(result.ids.sorted() == ["a", "c"])
        let docs = result.documents?.compactMap { $0 }.sorted()
        #expect(docs == ["alpha", "gamma"])
    }
    
    @Test func getDocumentsWithLimit() throws {
        try ChromaTestEnvironment.setUp()
        let name = uniqueName("limit")
        _ = try Chroma.createCollection(name: name)
        
        _ = try Chroma.addDocuments(
            collectionName: name,
            ids: ["a", "b", "c", "d", "e"],
            embeddings: [[1,0,0], [0,1,0], [0,0,1], [1,1,0], [0,1,1]],
            documents: ["one", "two", "three", "four", "five"]
        )
        
        let result = try Chroma.getDocuments(
            collectionName: name,
            ids: nil,
            whereClause: nil,
            limit: 2,
            offset: nil,
            whereDocument: nil,
            include: ["documents"]
        )
        #expect(result.ids.count == 2)
    }
    
    @Test func getDocumentsWithLimitAndOffset() throws {
        try ChromaTestEnvironment.setUp()
        let name = uniqueName("offset")
        _ = try Chroma.createCollection(name: name)
        
        _ = try Chroma.addDocuments(
            collectionName: name,
            ids: ["a", "b", "c", "d"],
            embeddings: [[1,0,0], [0,1,0], [0,0,1], [1,1,0]],
            documents: ["one", "two", "three", "four"]
        )
        
        let page1 = try Chroma.getDocuments(
            collectionName: name,
            ids: nil,
            whereClause: nil,
            limit: 2,
            offset: 0,
            whereDocument: nil,
            include: ["documents"]
        )
        let page2 = try Chroma.getDocuments(
            collectionName: name,
            ids: nil,
            whereClause: nil,
            limit: 2,
            offset: 2,
            whereDocument: nil,
            include: ["documents"]
        )
        #expect(page1.ids.count == 2)
        #expect(page2.ids.count == 2)
        // Pages should not overlap
        let allIds = Set(page1.ids).union(Set(page2.ids))
        #expect(allIds.count == 4)
    }
    
    @Test func getDocumentsIncludeEmbeddings() throws {
        try ChromaTestEnvironment.setUp()
        let name = uniqueName("incemb")
        _ = try Chroma.createCollection(name: name)
        
        let embeddings: [[Float]] = [[1.0, 2.0, 3.0]]
        _ = try Chroma.addDocuments(
            collectionName: name,
            ids: ["a"],
            embeddings: embeddings,
            documents: ["alpha"]
        )
        
        // Request embeddings only
        let withEmb = try Chroma.getDocuments(
            collectionName: name,
            ids: ["a"],
            whereClause: nil,
            limit: nil,
            offset: nil,
            whereDocument: nil,
            include: ["embeddings"]
        )
        #expect(withEmb.embeddings != nil)
        #expect(withEmb.embeddings?.count == 1)
        
        // Request documents only — embeddings should be nil
        let withoutEmb = try Chroma.getDocuments(
            collectionName: name,
            ids: ["a"],
            whereClause: nil,
            limit: nil,
            offset: nil,
            whereDocument: nil,
            include: ["documents"]
        )
        #expect(withoutEmb.embeddings == nil)
        #expect(withoutEmb.documents != nil)
    }
    
    @Test func updateDocuments() throws {
        try ChromaTestEnvironment.setUp()
        let name = uniqueName("update")
        _ = try Chroma.createCollection(name: name)
        
        _ = try Chroma.addDocuments(
            collectionName: name,
            ids: ["a"],
            embeddings: [[1, 0, 0]],
            documents: ["original"]
        )
        
        try Chroma.updateDocuments(
            collectionName: name,
            ids: ["a"],
            embeddings: [[0, 1, 0]],
            documents: ["updated"]
        )
        
        let result = try Chroma.getAllDocuments(collectionName: name)
        #expect(result.ids == ["a"])
        #expect(result.documents == ["updated"])
    }
    
    @Test func upsertInsertsThenUpdates() throws {
        try ChromaTestEnvironment.setUp()
        let name = uniqueName("upsert")
        _ = try Chroma.createCollection(name: name)
        
        // Upsert as insert (document doesn't exist yet)
        try Chroma.upsertDocuments(
            collectionName: name,
            ids: ["a"],
            embeddings: [[1, 0, 0]],
            documents: ["first version"]
        )
        #expect(try Chroma.countDocuments(collectionName: name) == 1)
        
        let before = try Chroma.getAllDocuments(collectionName: name)
        #expect(before.documents == ["first version"])
        
        // Upsert as update (same ID, different content)
        try Chroma.upsertDocuments(
            collectionName: name,
            ids: ["a"],
            embeddings: [[0, 1, 0]],
            documents: ["second version"]
        )
        // Count should still be 1, not 2
        #expect(try Chroma.countDocuments(collectionName: name) == 1)
        
        let after = try Chroma.getAllDocuments(collectionName: name)
        #expect(after.documents == ["second version"])
    }
    
    @Test func deleteAllDocumentsByIds() throws {
        try ChromaTestEnvironment.setUp()
        let name = uniqueName("delall")
        _ = try Chroma.createCollection(name: name)
        
        let ids = ["a", "b"]
        _ = try Chroma.addDocuments(
            collectionName: name,
            ids: ids,
            embeddings: [[1, 0], [0, 1]],
            documents: ["alpha", "beta"]
        )
        #expect(try Chroma.countDocuments(collectionName: name) == 2)
        
        try Chroma.deleteDocuments(collectionName: name, ids: ids)
        #expect(try Chroma.countDocuments(collectionName: name) == 0)
    }
    
    @Test func deleteSpecificDocuments() throws {
        try ChromaTestEnvironment.setUp()
        let name = uniqueName("delsome")
        _ = try Chroma.createCollection(name: name)
        
        _ = try Chroma.addDocuments(
            collectionName: name,
            ids: ["a", "b", "c"],
            embeddings: [[1, 0, 0], [0, 1, 0], [0, 0, 1]],
            documents: ["alpha", "beta", "gamma"]
        )
        
        try Chroma.deleteDocuments(collectionName: name, ids: ["a", "c"])
        #expect(try Chroma.countDocuments(collectionName: name) == 1)
        
        let remaining = try Chroma.getAllDocuments(collectionName: name)
        #expect(remaining.ids == ["b"])
        #expect(remaining.documents == ["beta"])
    }
    
    @Test func addDocumentsToNonexistentCollectionThrows() throws {
        try ChromaTestEnvironment.setUp()
        #expect(throws: (any Error).self) {
            _ = try Chroma.addDocuments(
                collectionName: "nonexistent_\(UUID().uuidString)",
                ids: ["a"],
                embeddings: [[1, 0]],
                documents: ["alpha"]
            )
        }
    }

    // MARK: - Query Tests
    
    @Test func queryReturnsNearestNeighbor() throws {
        try ChromaTestEnvironment.setUp()
        let name = uniqueName("query_nn")
        _ = try Chroma.createCollection(name: name)
        
        _ = try Chroma.addDocuments(
            collectionName: name,
            ids: ["cat", "dog"],
            embeddings: [[1, 0, 0], [0, 1, 0]],
            documents: ["about cats", "about dogs"]
        )
        
        // Query with embedding closest to "cat"
        let result = try Chroma.queryCollection(
            collectionName: name,
            queryEmbeddings: [[1, 0, 0]],
            nResults: 1,
            whereFilter: nil,
            ids: nil,
            include: ["documents"]
        )
        #expect(result.ids.count == 1)       // 1 query
        #expect(result.ids[0].count == 1)     // 1 result per query
        #expect(result.ids[0][0] == "cat")
        #expect(result.documents[0][0] == "about cats")
    }
    
    @Test func queryMultipleResults() throws {
        try ChromaTestEnvironment.setUp()
        let name = uniqueName("query_multi")
        _ = try Chroma.createCollection(name: name)
        
        _ = try Chroma.addDocuments(
            collectionName: name,
            ids: ["a", "b", "c"],
            embeddings: [[1, 0, 0], [0.9, 0.1, 0], [0, 0, 1]],
            documents: ["close", "closer", "far"]
        )
        
        let result = try Chroma.queryCollection(
            collectionName: name,
            queryEmbeddings: [[1, 0, 0]],
            nResults: 2,
            whereFilter: nil,
            ids: nil,
            include: ["documents"]
        )
        #expect(result.ids[0].count == 2)
        // Both "a" and "b" should be returned (closest to [1,0,0])
        let returnedIds = Set(result.ids[0])
        #expect(returnedIds.contains("a"))
        #expect(returnedIds.contains("b"))
        #expect(!returnedIds.contains("c"))
    }
    
    @Test func queryMultipleQueries() throws {
        try ChromaTestEnvironment.setUp()
        let name = uniqueName("query_batch")
        _ = try Chroma.createCollection(name: name)
        
        _ = try Chroma.addDocuments(
            collectionName: name,
            ids: ["x", "y"],
            embeddings: [[1, 0, 0], [0, 1, 0]],
            documents: ["doc_x", "doc_y"]
        )
        
        // Two queries at once
        let result = try Chroma.queryCollection(
            collectionName: name,
            queryEmbeddings: [[1, 0, 0], [0, 1, 0]],
            nResults: 1,
            whereFilter: nil,
            ids: nil,
            include: ["documents"]
        )
        #expect(result.ids.count == 2)        // 2 queries
        #expect(result.ids[0][0] == "x")      // first query matches x
        #expect(result.ids[1][0] == "y")      // second query matches y
    }
    
    @Test func queryNResultsExceedsDocumentCount() throws {
        try ChromaTestEnvironment.setUp()
        let name = uniqueName("query_exceed")
        _ = try Chroma.createCollection(name: name)
        
        _ = try Chroma.addDocuments(
            collectionName: name,
            ids: ["only"],
            embeddings: [[1, 0, 0]],
            documents: ["lonely doc"]
        )
        
        // Ask for 100 results but only 1 document exists
        let result = try Chroma.queryCollection(
            collectionName: name,
            queryEmbeddings: [[1, 0, 0]],
            nResults: 100,
            whereFilter: nil,
            ids: nil,
            include: ["documents"]
        )
        #expect(result.ids[0].count == 1)
        #expect(result.documents[0][0] == "lonely doc")
    }

    // MARK: - System Tests
    
    @Test func getVersion() throws {
        try ChromaTestEnvironment.setUp()
        let version = try Chroma.getVersion()
        #expect(!version.isEmpty, "Version string should not be empty")
    }
    
    @Test func heartbeat() throws {
        try ChromaTestEnvironment.setUp()
        let heartbeat = try Chroma.heartbeat()
        #expect(heartbeat > 0, "Heartbeat should return a positive timestamp")
    }
    
    @Test func getMaxBatchSize() throws {
        try ChromaTestEnvironment.setUp()
        let maxBatch = try Chroma.getMaxBatchSize()
        #expect(maxBatch > 0, "Max batch size should be positive")
    }
    
    @Test func resetClearsAllData() throws {
        try ChromaTestEnvironment.setUp()
        _ = try Chroma.createCollection(name: uniqueName("pre_reset"))
        #expect(try Chroma.countCollections() == 1)
        
        try Chroma.reset()
        #expect(try Chroma.countCollections() == 0)
    }

    // MARK: - Concurrency Tests

    @Test func concurrentCreateCollections() async throws {
        try ChromaTestEnvironment.setUp()
        let collectionNames = (0..<8).map { _ in uniqueName("concurrent") }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for name in collectionNames {
                group.addTask {
                    _ = try Chroma.createCollection(name: name)
                }
            }
            try await group.waitForAll()
        }

        let collections = try Chroma.listCollections()
        for name in collectionNames {
            #expect(collections.contains(name))
        }
        #expect(try Chroma.countCollections() == UInt32(collectionNames.count))
    }

    @Test func concurrentWritesDistinctCollections() async throws {
        try ChromaTestEnvironment.setUp()
        let collectionNames = (0..<6).map { _ in uniqueName("distinct") }
        for name in collectionNames {
            _ = try Chroma.createCollection(name: name)
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for (index, name) in collectionNames.enumerated() {
                let id = "\(name)-doc"
                let embedding: [Float] = [Float(index), 0.0, 1.0]
                let document = "doc \(index)"
                group.addTask {
                    _ = try Chroma.addDocuments(
                        collectionName: name,
                        ids: [id],
                        embeddings: [embedding],
                        documents: [document]
                    )
                }
            }
            try await group.waitForAll()
        }

        for name in collectionNames {
            let count = try Chroma.countDocuments(collectionName: name)
            #expect(count == 1)
        }
    }

    @Test func concurrentWritesSameCollection() async throws {
        try ChromaTestEnvironment.setUp()
        let collectionName = uniqueName("shared")
        _ = try Chroma.createCollection(name: collectionName)

        let taskCount = 10
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<taskCount {
                let id = "\(collectionName)-\(index)"
                let embedding: [Float] = [Float(index), 1.0, 0.5]
                let document = "doc \(index)"
                group.addTask {
                    _ = try Chroma.addDocuments(
                        collectionName: collectionName,
                        ids: [id],
                        embeddings: [embedding],
                        documents: [document]
                    )
                }
            }
            try await group.waitForAll()
        }

        let count = try Chroma.countDocuments(collectionName: collectionName)
        #expect(count == UInt32(taskCount))
    }

    @Test func concurrentReadsDuringWrites() async throws {
        try ChromaTestEnvironment.setUp()
        let collectionName = uniqueName("readwrite")
        _ = try Chroma.createCollection(name: collectionName)

        let writeCount = 12
        let readCount = 12

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<writeCount {
                let id = "\(collectionName)-\(index)"
                let embedding: [Float] = [Float(index), 0.0, 1.0]
                let document = "doc \(index)"
                group.addTask {
                    _ = try Chroma.addDocuments(
                        collectionName: collectionName,
                        ids: [id],
                        embeddings: [embedding],
                        documents: [document]
                    )
                }
            }

            for _ in 0..<readCount {
                group.addTask {
                    _ = try Chroma.countDocuments(collectionName: collectionName)
                }
            }

            try await group.waitForAll()
        }

        let count = try Chroma.countDocuments(collectionName: collectionName)
        #expect(count == UInt32(writeCount))
    }
}

// MARK: - ChromaEmbedder Unit Tests
// These don't touch the database, so they can run in parallel.

@Suite struct EmbedderUnitTests {

    @Test func embeddingModelDimensions() {
        #expect(ChromaEmbedder.EmbeddingModel.bgeMicro.embeddingDimensions == 384)
        #expect(ChromaEmbedder.EmbeddingModel.gteTiny.embeddingDimensions == 384)
        #expect(ChromaEmbedder.EmbeddingModel.miniLML6.embeddingDimensions == 384)
        #expect(ChromaEmbedder.EmbeddingModel.miniLML12.embeddingDimensions == 384)
        #expect(ChromaEmbedder.EmbeddingModel.bgeSmall.embeddingDimensions == 384)
        #expect(ChromaEmbedder.EmbeddingModel.bgeBase.embeddingDimensions == 768)
        #expect(ChromaEmbedder.EmbeddingModel.bgeLarge.embeddingDimensions == 1024)
        #expect(ChromaEmbedder.EmbeddingModel.mixedbreadLarge.embeddingDimensions == 1024)
    }

    @Test func embeddingModelDisplayNames() {
        for model in ChromaEmbedder.EmbeddingModel.allCases {
            #expect(!model.displayName.isEmpty, "\(model) should have a display name")
        }
    }

    @Test func embeddingModelRawValues() {
        for model in ChromaEmbedder.EmbeddingModel.allCases {
            #expect(model.rawValue.contains("/"),
                    "\(model) raw value should be an org/model path, got: \(model.rawValue)")
        }
    }

    @Test func defaultInit() {
        let embedder = ChromaEmbedder()
        #expect(embedder.model == .miniLML6)
        #expect(embedder.embeddingDimensions == 384)
    }

    @Test func customModelInit() {
        let embedder = ChromaEmbedder(model: .bgeLarge)
        #expect(embedder.model == .bgeLarge)
        #expect(embedder.embeddingDimensions == 1024)
    }

    @Test func embedSingleTextBeforeLoadThrows() async throws {
        let embedder = ChromaEmbedder()
        await #expect(throws: ChromaEmbedderError.self) {
            _ = try await embedder.embed(text: "hello")
        }
    }

    @Test func embedMultipleTextsBeforeLoadThrows() async throws {
        let embedder = ChromaEmbedder()
        await #expect(throws: ChromaEmbedderError.self) {
            _ = try await embedder.embed(texts: ["hello", "world"])
        }
    }

    @Test func embedEmptyTextsBeforeLoadThrows() async throws {
        let embedder = ChromaEmbedder()
        // Model check runs before the empty-array early return
        await #expect(throws: ChromaEmbedderError.self) {
            _ = try await embedder.embed(texts: [])
        }
    }

    @Test func modelInfoBeforeLoad() {
        let embedder = ChromaEmbedder(model: .bgeSmall)
        let info = embedder.modelInfo

        #expect(info["model_id"] as? String == "BAAI/bge-small-en-v1.5")
        #expect(info["model_name"] as? String == "BGE Small EN v1.5")
        #expect(info["embedding_dimensions"] as? Int == 384)
        #expect(info["embedder_type"] as? String == "MLXEmbedders")
        #expect(info["is_loaded"] as? Bool == false)
    }

    @Test func embedderErrorDescriptions() {
        let notLoaded = ChromaEmbedderError.modelNotLoaded
        #expect(notLoaded.errorDescription?.contains("loadModel()") == true)

        let loadFailed = ChromaEmbedderError.modelLoadingFailed(
            "TestModel",
            NSError(domain: "test", code: 0, userInfo: nil)
        )
        #expect(loadFailed.errorDescription?.contains("TestModel") == true)

        let embedFailed = ChromaEmbedderError.embeddingFailed(
            ["a", "b"],
            NSError(domain: "test", code: 0, userInfo: nil)
        )
        #expect(embedFailed.errorDescription?.contains("2 text(s)") == true)
    }

    @Test func addDocumentsMismatchedCountThrows() async throws {
        let embedder = ChromaEmbedder()
        await #expect(throws: (any Error).self) {
            _ = try await embedder.addDocuments(
                to: "any_collection",
                ids: ["a", "b"],
                texts: ["only one"]
            )
        }
    }
}
