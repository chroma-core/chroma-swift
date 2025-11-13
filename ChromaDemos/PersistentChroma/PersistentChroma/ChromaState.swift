//
//  ChromaState.swift
//  PersistentChroma
//
//  Created by Nicholas Arner on 5/21/25.
//

import Foundation
import Chroma

@Observable
final class ChromaState {
    var docText: String = ""
    var errorMessage: String? = nil
    var logs: [String] = []
    var docCounter: Int = 0
    var persistentCollectionName: String = "persistent_collection"
    var collections: [String] = []
    var isPersistentInitialized: Bool = false
    var persistentPath: String = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path + "/chroma_data"
    var persistentQueryEmbeddingText: String = "0.1,0.2,0.3,0.4"
    var persistentIncludeFieldsText: String = "documents"
    var isShowingFolderPicker: Bool = false
}

extension ChromaState {

    func addLog(_ message: String) {
        let entry = "[\(Date().formatted(date: .omitted, time: .standard))] \(message)"
        logs.append(entry)
    }
    
    func refreshCollections() {
        do {
            let names = try listCollections()
            collections = names
            self.addLog("Found \(names.count) collections:")
            names.forEach { collection in
                self.addLog("\(collection)")
            }
        } catch {
            self.addLog("Failed to list collections: \(error)")
        }
    }
    
    func logAllCollectionIds() {
        do {
            let names = try listCollections()
            guard !names.isEmpty else {
                addLog("No collections found.")
                return
            }
            
            addLog("Fetching IDs for \(names.count) collection(s)...")
            for name in names {
                do {
                    let info = try Chroma.getCollection(collectionName: name)
                    addLog("• \(name): \(info.collectionId)")
                } catch {
                    addLog("• \(name): failed to fetch info (\(error))")
                }
            }
            addLog("Finished fetching collection IDs.")
        } catch {
            addLog("Failed to list collections before fetching IDs: \(error)")
        }
    }
    
    func initializeWithPath(path: String, allowReset: Bool = false) throws {
        try Chroma.initializeWithPath(path: path, allowReset: allowReset)
        self.addLog("Persistent Chroma initialized at path: \(path)")
    }
    
    func reset() throws {
        try Chroma.reset()
        collections = []
        isPersistentInitialized = false
        self.addLog("Chroma reset complete")
        
        // Re-initialize Chroma after reset
        try self.initializeWithPath(path: persistentPath, allowReset: true)
        isPersistentInitialized = true
        
        logs.removeAll()
    }
    
    func debugFullReset() throws {
        self.addLog("Starting complete debug reset...")
        
        // Reset Chroma database
        try Chroma.reset()
        
        // Clear all state
        collections = []
        isPersistentInitialized = false
        docText = ""
        errorMessage = nil
        docCounter = 0
        persistentQueryEmbeddingText = "0.1,0.2,0.3,0.4"
        persistentIncludeFieldsText = "documents"
        
        // Clear image cache
        self.clearImageCache()
        
        // Remove persistent data directory completely
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: persistentPath) {
            try fileManager.removeItem(atPath: persistentPath)
            self.addLog("Removed persistent data directory")
        }
        
        // Recreate directory and re-initialize
        try fileManager.createDirectory(atPath: persistentPath, withIntermediateDirectories: true)
        try self.initializeWithPath(path: persistentPath, allowReset: true)
        isPersistentInitialized = true
        
        self.addLog("Complete debug reset finished")
        
        // Clear logs after a brief delay to show completion message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.logs.removeAll()
        }
    }
    
    private func clearImageCache() {
        let fileManager = FileManager.default
        
        // Clear URLSession cache
        URLCache.shared.removeAllCachedResponses()
        
        // Clear temporary directory
        let tempDir = fileManager.temporaryDirectory
        do {
            let tempContents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            for url in tempContents {
                try fileManager.removeItem(at: url)
            }
            self.addLog("Cleared temporary cache")
        } catch {
            self.addLog("Failed to clear temp cache: \(error)")
        }
        
        // Clear app's caches directory
        if let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            do {
                let cacheContents = try fileManager.contentsOfDirectory(at: cachesDir, includingPropertiesForKeys: nil)
                for url in cacheContents {
                    try fileManager.removeItem(at: url)
                }
                self.addLog("Cleared app caches")
            } catch {
                self.addLog("Failed to clear app caches: \(error)")
            }
        }
    }
    
    func reloadScreenshots() {
        self.addLog("Starting screenshot reload process...")
        
        // Reset document counter
        docCounter = 0
        
        // TODO: Add your screenshot loading logic here
        // This is where you would implement the logic to:
        // 1. Scan for screenshot files
        // 2. Process them
        // 3. Add them to the database
        // Example:
        
        Task { @MainActor in
            await self.processScreenshots()
        }
    }
    
    @MainActor
    private func processScreenshots() async {
        // This is a placeholder for your screenshot processing logic
        // You would implement the actual screenshot detection and processing here
        
        self.addLog("Scanning for screenshots...")
        
        // Example implementation structure:
        // 1. Get photos library access
        // 2. Filter for screenshots
        // 3. Process each screenshot
        // 4. Add to Chroma database
        
        self.addLog("Screenshot reload process completed")
    }
    
    func checkForPersistentData() {
        let fileManager = FileManager.default
        let dbPath = persistentPath + "/chroma.sqlite3"
        
        if fileManager.fileExists(atPath: dbPath) {
            self.addLog("Found existing persistent database at: \(dbPath)")
        }
    }
    
    func deleteCollection(name: String) throws {
        try Chroma.deleteCollection(collectionName: name)
        self.addLog("Deleted collection: \(name)")
        refreshCollections()
    }
    
    func deleteDocuments(collectionName: String, documentIds: [String]?) throws {
        try Chroma.deleteDocuments(collectionName: collectionName, ids: documentIds)
        if let ids = documentIds {
            self.addLog("Deleted \(ids.count) documents from collection '\(collectionName)': \(ids.joined(separator: ", "))")
        } else {
            self.addLog("Deleted all documents from collection '\(collectionName)'")
        }
    }
    
    func deleteAllDocumentsFromCollection(collectionName: String) throws {
        try deleteDocuments(collectionName: collectionName, documentIds: nil)
    }
}
