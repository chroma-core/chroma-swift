//  ChromaState.swift
//  LocalEmbeddingsModelDemo
//
//  Created by Nicholas Arner on 7/1/25.
//

import Foundation
import Chroma

@Observable
final class ChromaState {
    var docText: String = ""
    var queryText: String = ""
    var logs: [String] = []
    var docCounter: Int = 0
    var collectionName: String = "local_embeddings_demo"
    var collections: [String] = []
    var isInitialized: Bool = false
    var errorMessage: String? = nil
    var queryEmbeddingText: String = ""
    var includeFieldsText: String = "documents"
    
    // Local embeddings specific properties
    var embedder: ChromaEmbedder?
    var selectedModel: ChromaEmbedder.EmbeddingModel = .miniLML6
    var isEmbedderLoaded: Bool = false
    var isLoadingEmbedder: Bool = false
    var availableModels: [ChromaEmbedder.EmbeddingModel] = ChromaEmbedder.EmbeddingModel.allCases
    var queryResults: [String] = []
    var queryDistances: [Float] = []
    
    var newCollectionName: String = ""
    var selectedCollectionName: String = "local_embeddings_demo"
    
    private var currentProgressTask: Task<Void, Never>?

    func addLog(_ message: String) {
        logs.append("[\(Date().formatted(date: .omitted, time: .standard))] \(message)")
    }
    
    func refreshCollections() {
        guard isInitialized else {
            addLog("Cannot refresh collections: Chroma not initialized")
            return
        }
        
        do {
            collections = try Chroma.listCollections()
            addLog("Found \(collections.count) collections:")
            collections.forEach { collection in
                addLog("  • \(collection)")
            }
        } catch {
            addLog("Failed to list collections: \(error)")
        }
    }
    
    func initialize(allowReset: Bool = true) throws {
        try Chroma.initialize(allowReset: allowReset)
        
        isInitialized = true
        addLog("Local Embeddings Model Demo initialized (allowReset: \(allowReset))")
    }
    
    func reset() throws {
        try Chroma.reset()
        collections = []
        isInitialized = false
        addLog("Chroma reset complete")
        
        // Re-initialize Chroma after reset
        try initialize()
        addLog("System reset complete")
        
        DispatchQueue.main.async { [weak self] in
            self?.logs.removeAll()
            self?.queryResults.removeAll()
            self?.queryDistances.removeAll()
            self?.docText = ""
            self?.queryText = ""
            self?.docCounter = 0
        }
    }
    
    func createCollection() {
        guard !newCollectionName.isEmpty else {
            addLog("❌ Collection name cannot be empty")
            return
        }
        
        // Check if collection already exists
        if collections.contains(newCollectionName) {
            addLog("❌ Collection '\(newCollectionName)' already exists")
            return
        }
        
        do {
            try Chroma.createCollection(name: newCollectionName)
            addLog("✅ Collection '\(newCollectionName)' created successfully")
            selectedCollectionName = newCollectionName
            newCollectionName = ""
            refreshCollections()
        } catch {
            addLog("❌ Failed to create collection '\(newCollectionName)': \(error)")
        }
    }
    
    func loadEmbedder() async {
        guard !isLoadingEmbedder else {
            addLog("⚠️ Already loading a model, please wait...")
            return
        }
        
        currentProgressTask?.cancel()
        
        await MainActor.run {
            self.isLoadingEmbedder = true
            self.isEmbedderLoaded = false
            self.embedder = nil
        }
        
        addLog("🔄 Starting embedder loading process...")
        addLog("📋 Selected model: \(selectedModel.displayName)")
        addLog("📊 Model dimensions: \(selectedModel.embeddingDimensions)")
        addLog("🏷️ Model raw value: \(selectedModel.rawValue)")
        
        await MainActor.run {
            self.queryResults.removeAll()
            self.queryDistances.removeAll()
        }
        
        let startTime = Date()
        
        do {
            addLog("🏗️ Creating ChromaEmbedder instance...")
            let newEmbedder = ChromaEmbedder(model: selectedModel)
            addLog("✅ ChromaEmbedder instance created successfully")
            
            addLog("⬇️ Starting model download/loading...")
            addLog("🌐 This may take a while if the model needs to be downloaded...")
            
            currentProgressTask = Task.detached { [weak self] in
                var elapsedSeconds = 0
                let progressStartTime = Date()
                
                while !Task.isCancelled {
                    do {
                        try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                    } catch {
                        // Task was cancelled, exit gracefully
                        break
                    }
                    
                    elapsedSeconds = Int(Date().timeIntervalSince(progressStartTime))
                    
                    await MainActor.run {
                        guard let self = self else { return }
                        if self.isLoadingEmbedder {
                            self.addLog("⏱️ Still loading... (\(elapsedSeconds)s elapsed)")
                            
                            if elapsedSeconds >= 30 && elapsedSeconds < 40 {
                                self.addLog("💭 Large embedding models can take several minutes to download...")
                            } else if elapsedSeconds >= 60 && elapsedSeconds < 70 {
                                self.addLog("📱 Model downloading in background, this is normal for first-time loads")
                            } else if elapsedSeconds >= 120 && elapsedSeconds < 130 {
                                self.addLog("🔍 If this is taking unusually long, check your internet connection")
                            }
                        }
                    }
                }
            }
            
            try await newEmbedder.loadModel()
            
            currentProgressTask?.cancel()
            currentProgressTask = nil
            
            let loadTime = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                self.embedder = newEmbedder
                self.isEmbedderLoaded = true
                self.isLoadingEmbedder = false
                self.addLog("🎉 \(selectedModel.displayName) loaded successfully!")
                self.addLog("⏱️ Total loading time: \(String(format: "%.1f", loadTime)) seconds")
                self.addLog("📏 Confirmed embedding dimensions: \(selectedModel.embeddingDimensions)")
                self.addLog("🚀 Embedder is ready for use!")
            }
        } catch {
            currentProgressTask?.cancel()
            currentProgressTask = nil
            
            await MainActor.run {
                self.isLoadingEmbedder = false
                self.isEmbedderLoaded = false
                self.embedder = nil
                let loadTime = Date().timeIntervalSince(startTime)
                
                self.addLog("💥 Failed to load embedder after \(String(format: "%.1f", loadTime)) seconds")
                self.addLog("🔍 Error: \(error)")
                self.addLog("🔍 Error type: \(type(of: error))")
                
                if let nsError = error as NSError? {
                    self.addLog("📝 Error domain: \(nsError.domain)")
                    self.addLog("🔢 Error code: \(nsError.code)")
                    self.addLog("📄 Error description: \(nsError.localizedDescription)")
                    
                    if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                        self.addLog("🔗 Underlying error: \(underlyingError)")
                    }
                    
                    if let failureReason = nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String {
                        self.addLog("❓ Failure reason: \(failureReason)")
                    }
                    
                    if let recoverySuggestion = nsError.userInfo[NSLocalizedRecoverySuggestionErrorKey] as? String {
                        self.addLog("💡 Recovery suggestion: \(recoverySuggestion)")
                    }
                }
                
                self.addLog("🔄 Try switching to a different model or check your network connection")
                self.addLog("📶 Ensure you have a stable internet connection for model downloads")
            }
        }
    }
    
    func addDocumentWithEmbedding() async {
        guard let embedder = embedder, isEmbedderLoaded else {
            addLog("❌ Embedder not loaded. Please load an embedder first.")
            return
        }
        
        guard !docText.isEmpty else {
            addLog("❌ Document text is empty")
            return
        }
        
        if !collections.contains(selectedCollectionName) {
            addLog("❌ Collection '\(selectedCollectionName)' does not exist. Please create it first.")
            return
        }
        
        addLog("Generating embedding for document...")
        
        do {
            let embedding = try await embedder.embed(text: docText)
            let docId = "doc_\(docCounter)"
            
            try Chroma.addDocuments(
                collectionName: selectedCollectionName,
                ids: [docId],
                embeddings: [embedding],
                documents: [docText]
            )
            
            docCounter += 1
            addLog("✅ Document added with local embedding (ID: \(docId))")
            addLog("Embedding preview: [\(embedding.prefix(5).map { String(format: "%.3f", $0) }.joined(separator: ", "))...]")
            
            docText = ""
        } catch {
            addLog("❌ Failed to add document: \(error.localizedDescription)")
        }
    }
    
    func performQueryWithEmbedding() async {
        guard let embedder = embedder, isEmbedderLoaded else {
            addLog("❌ Embedder not loaded. Please load an embedder first.")
            return
        }
        
        guard !queryText.isEmpty else {
            addLog("❌ Query text is empty")
            return
        }
        
        if !collections.contains(selectedCollectionName) {
            addLog("❌ Collection '\(selectedCollectionName)' does not exist. Please create it first.")
            return
        }
        
        addLog("Generating embedding for query: \"\(queryText)\"")
        
        do {
            let queryEmbedding = try await embedder.embed(text: queryText)
            
            let results = try Chroma.queryCollection(
                collectionName: selectedCollectionName,
                queryEmbeddings: [queryEmbedding],
                nResults: 3,
                whereFilter: nil,
                ids: nil,
                include: ["documents"]
            )
            
            let documents = results.documents
            
            if !documents.isEmpty {
                queryResults = documents.flatMap { $0.compactMap { $0 } }
                
                // Clear distances since they're not available in the current API
                queryDistances = []
                
                addLog("🔍 Query results:")
                for (i, doc) in queryResults.enumerated() {
                    addLog("  \(i + 1). \"\(doc)\"")
                }
            } else {
                addLog("No results found")
                queryResults = []
                queryDistances = []
            }
        } catch {
            addLog("❌ Query failed: \(error.localizedDescription)")
        }
    }
}
