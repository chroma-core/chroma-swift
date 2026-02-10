import Testing
import Foundation
@testable import Chroma

// MARK: - Shared Test Environment

private enum EmbedderTestEnvironment {
    nonisolated(unsafe) static var embedder: ChromaEmbedder?

    static func shared() async throws -> ChromaEmbedder {
        if let e = embedder { return e }
        let e = ChromaEmbedder(model: .bgeMicro)
        try await e.loadModel()
        embedder = e
        return e
    }
}

// MARK: - Cosine Similarity Helper

private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
    let dot = zip(a, b).map(*).reduce(0, +)
    let normA = sqrt(a.map { $0 * $0 }.reduce(0, +))
    let normB = sqrt(b.map { $0 * $0 }.reduce(0, +))
    return dot / (normA * normB)
}

// MARK: - Tests

@Suite(.serialized)
struct EmbeddingsTests {

    // MARK: Single Text Tests

    @Test
    func singleTextEmbeddingDimensions() async throws {
        let embedder = try await EmbedderTestEnvironment.shared()
        let embedding = try await embedder.embed(text: "Hello, world!")
        #expect(embedding.count == 384)
    }

    @Test
    func singleTextEmbeddingNonZero() async throws {
        let embedder = try await EmbedderTestEnvironment.shared()
        let embedding = try await embedder.embed(text: "Hello, world!")
        let hasNonZero = embedding.contains { $0 != 0.0 }
        #expect(hasNonZero, "Embedding should not be all zeros")
    }

    @Test
    func singleTextEmbeddingNormalized() async throws {
        let embedder = try await EmbedderTestEnvironment.shared()
        let embedding = try await embedder.embed(text: "Hello, world!")
        let l2Norm = sqrt(embedding.map { $0 * $0 }.reduce(0, +))
        #expect(abs(l2Norm - 1.0) < 0.01, "L2 norm should be approximately 1.0, got \(l2Norm)")
    }

    // MARK: Batch Tests

    @Test
    func batchEmbeddingDimensions() async throws {
        let embedder = try await EmbedderTestEnvironment.shared()
        let texts = ["Hello, world!", "Swift is great", "Machine learning rocks"]
        let embeddings = try await embedder.embed(texts: texts)
        #expect(embeddings.count == texts.count)
        for (i, embedding) in embeddings.enumerated() {
            #expect(embedding.count == 384, "Embedding \(i) should have 384 dimensions, got \(embedding.count)")
        }
    }

    @Test
    func singleVsBatchConsistency() async throws {
        let embedder = try await EmbedderTestEnvironment.shared()
        let text = "The quick brown fox jumps over the lazy dog"

        let singleEmbedding = try await embedder.embed(text: text)
        let batchEmbeddings = try await embedder.embed(texts: [text])

        #expect(batchEmbeddings.count == 1)

        let similarity = cosineSimilarity(singleEmbedding, batchEmbeddings[0])
        #expect(similarity > 0.999, "Single and batch embeddings should be nearly identical, cosine similarity: \(similarity)")

        for i in 0..<singleEmbedding.count {
            let diff = abs(singleEmbedding[i] - batchEmbeddings[0][i])
            #expect(diff < 0.001, "Element \(i) differs by \(diff)")
        }
    }

    @Test
    func batchWithVariableLengths() async throws {
        let embedder = try await EmbedderTestEnvironment.shared()
        let texts = [
            "Short",
            "A medium length sentence for testing purposes",
            "This is a significantly longer piece of text that contains multiple clauses, covers various topics including natural language processing and machine learning, and is designed to test how the model handles padding for sequences of very different lengths in the same batch"
        ]

        let embeddings = try await embedder.embed(texts: texts)
        #expect(embeddings.count == texts.count)

        for (i, embedding) in embeddings.enumerated() {
            #expect(embedding.count == 384, "Embedding \(i) should have 384 dimensions, got \(embedding.count)")

            let l2Norm = sqrt(embedding.map { $0 * $0 }.reduce(0, +))
            #expect(abs(l2Norm - 1.0) < 0.01, "Embedding \(i) L2 norm should be approximately 1.0, got \(l2Norm)")

            let hasNonZero = embedding.contains { $0 != 0.0 }
            #expect(hasNonZero, "Embedding \(i) should not be all zeros")
        }
    }

    // MARK: Semantic Similarity

    @Test
    func semanticSimilarity() async throws {
        let embedder = try await EmbedderTestEnvironment.shared()
        let dogEmbedding = try await embedder.embed(text: "dog")
        let puppyEmbedding = try await embedder.embed(text: "puppy")
        let quantumEmbedding = try await embedder.embed(text: "quantum physics")

        let similarPair = cosineSimilarity(dogEmbedding, puppyEmbedding)
        let dissimilarPair = cosineSimilarity(dogEmbedding, quantumEmbedding)

        #expect(similarPair > dissimilarPair, "cosine(dog, puppy) = \(similarPair) should be > cosine(dog, quantum physics) = \(dissimilarPair)")
    }
}
