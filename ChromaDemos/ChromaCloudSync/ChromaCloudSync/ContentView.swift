//
//  ContentView.swift
//  ChromaCloudSync
//
//  Created by Nicholas Arner on 8/23/25.
//

import SwiftUI
import Chroma

struct ContentView: View {
    @State private var client = ChromaClient()
    @State private var cloudClient: ChromaClient?
    @State private var logs: [String] = []
    @State private var isInitialized = false
    @State private var isCloudConnected = false
    @State private var cloudTenant = ""
    @State private var cloudDatabase = ""
    @State private var cloudApiKey = ""
    @State private var newCollectionName = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("ChromaCloudSync Demo")
                .font(.title)
                .bold()
            
            // Cloud Configuration Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Cloud Configuration")
                    .font(.headline)
                
                HStack {
                    Text("Tenant:")
                        .frame(width: 80, alignment: .leading)
                    TextField("tenant", text: $cloudTenant)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    Text("Database:")
                        .frame(width: 80, alignment: .leading)
                    TextField("database", text: $cloudDatabase)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    Text("API Key:")
                        .frame(width: 80, alignment: .leading)
                    SecureField("optional", text: $cloudApiKey)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Button("Test Cloud Connection") {
                            testCloudConnection()
                        }
                        .buttonStyle(.bordered)
                        .disabled(cloudTenant.isEmpty || cloudDatabase.isEmpty)
                        
                        Button("List Collections") {
                            listCloudCollections()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!isCloudConnected)
                        
                        if isCloudConnected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    
                    
                }
            }
            .padding()
            .background(Color(.gray))
            .cornerRadius(8)
            
            // Collection Management Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Collection Management")
                    .font(.headline)
                
                HStack {
                    Text("Collection Name:")
                        .frame(width: 120, alignment: .leading)
                    TextField("Enter collection name", text: $newCollectionName)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack(spacing: 12) {
                    Button("Create Collection") {
                        createCollection()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newCollectionName.isEmpty)
                    
                    Button("Add Sample Documents") {
                        addSampleDocuments()
                    }
                    .buttonStyle(.bordered)
                    .disabled(newCollectionName.isEmpty || !isInitialized)
                    
                    Button("Upload to Cloud") {
                        uploadCollectionToCloud()
                    }
                    .buttonStyle(.bordered)
                    .disabled(newCollectionName.isEmpty || !isInitialized || !isCloudConnected)
                }
            }
            .padding()
            .background(Color(.systemGreen).opacity(0.1))
            .cornerRadius(8)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(logs, id: \.self) { log in
                        Text(log)
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .cornerRadius(4)
                    }
                }
                .padding()
            }
            .frame(maxHeight: 300)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.gray), lineWidth: 1)
            )
            
            HStack(spacing: 12) {
                Button("Run Local Example") {
                    runExample()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isInitialized)
                
            }
            
            Button("Clear Logs") {
                logs.removeAll()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logs.append("[\(timestamp)] \(message)")
    }
    
    private func runExample() {
        logs.removeAll()
        
        Task {
            do {
                // Initialize the client
                try client.initialize()
                await MainActor.run {
                    addLog("✅ ChromaClient initialized")
                    isInitialized = true
                }
                
                // Create a collection
                let collectionId = try client.createCollection(name: "mytestdatabase")
                await MainActor.run {
                    addLog("✅ Collection created with ID: \(collectionId)")
                }
                
                // List collections
                let collections = try client.listCollections()
                await MainActor.run {
                    addLog("✅ Collections: \(collections)")
                }
                
                // Add a single document
                let docCount = try client.addDocument(
                    toCollection: "mytestdatabase",
                    id: "doc1",
                    text: "This is my first document",
                    embedding: [0.1, 0.2, 0.3, 0.4]
                )
                await MainActor.run {
                    addLog("✅ Added document. Total count: \(docCount)")
                }
                
                // Add multiple documents
                let documents = [
                    (id: "doc2", text: "Second document about cats", embedding: [Float(0.2), Float(0.3), Float(0.4), Float(0.5)]),
                    (id: "doc3", text: "Third document about dogs", embedding: [Float(0.3), Float(0.4), Float(0.5), Float(0.6)])
                ]
                
                let totalCount = try client.addDocuments(
                    toCollection: "mytestdatabase",
                    documents: documents
                )
                await MainActor.run {
                    addLog("✅ Added multiple documents. Total count: \(totalCount)")
                }
                
                // Get all documents
                let results = try client.getAllDocuments(fromCollection: "mytestdatabase")
                await MainActor.run {
                    addLog("✅ Retrieved \(results.ids.count) documents:")
                    for (id, doc) in zip(results.ids, results.documents) {
                        addLog("   - \(id): \(doc ?? "nil")")
                    }
                }
                
                // Query the collection
                let queryResults = try client.queryCollection(
                    name: "mytestdatabase",
                    queryEmbeddings: [[0.15, 0.25, 0.35, 0.45]],
                    nResults: 2
                )
                await MainActor.run {
                    addLog("✅ Query returned \(queryResults.ids.count) result groups")
                    if !queryResults.ids.isEmpty {
                        for (i, idGroup) in queryResults.ids.enumerated() {
                            addLog("   Group \(i): \(idGroup)")
                        }
                    }
                }
                
            } catch {
                await MainActor.run {
                    addLog("❌ Error: \(error)")
                    isInitialized = false
                }
            }
        }
    }
    
    private func testCloudConnection() {
        Task {
            do {
                // Create cloud client
                let apiKey = cloudApiKey.isEmpty ? nil : cloudApiKey
                cloudClient = ChromaClient(
                    cloudTenant: cloudTenant,
                    database: cloudDatabase,
                    apiKey: apiKey
                )
                
                // Initialize and test connection
                try cloudClient?.initialize()
                let isConnected = try await cloudClient?.testCloudConnection() ?? false
                
                await MainActor.run {
                    if isConnected {
                        addLog("✅ Cloud connection successful")
                        isCloudConnected = true
                    } else {
                        addLog("❌ Cloud connection failed")
                        isCloudConnected = false
                    }
                }
                
            } catch {
                await MainActor.run {
                    addLog("❌ Cloud connection error: \(error)")
                    isCloudConnected = false
                }
            }
        }
    }
    
    private func listCloudCollections() {
        guard let cloudClient = cloudClient else {
            addLog("❌ Cloud client not configured")
            return
        }
        
        Task {
            do {
                addLog("📋 Listing cloud collections...")
                let collections = try await cloudClient.listCloudCollections()
                await MainActor.run {
                    addLog("📦 Found \(collections.count) cloud collections: \(collections)")
                }
            } catch {
                await MainActor.run {
                    addLog("❌ List collections error: \(error)")
                }
            }
        }
    }
    
    
    private func discoverEndpoints() {
        guard let cloudClient = cloudClient else {
            addLog("❌ Cloud client not configured")
            return
        }
        
        Task {
            do {
                addLog("🔍 Discovering API endpoints...")
                try await cloudClient.discoverAPIEndpoints()
                await MainActor.run {
                    addLog("✅ Endpoint discovery completed (check console for details)")
                }
            } catch {
                await MainActor.run {
                    addLog("❌ Discovery error: \(error)")
                }
            }
        }
    }
    
    
    
    private func createCollection() {
        Task {
            do {
                // Initialize local client if not already done
                if !isInitialized {
                    addLog("🔧 Initializing local Chroma client...")
                    try client.initialize()
                    await MainActor.run {
                        isInitialized = true
                        addLog("✅ Local Chroma client initialized")
                    }
                }
                
                // Create local collection first
                addLog("🏗️ Creating local collection: \(newCollectionName)")
                let collectionId = try client.createCollection(name: newCollectionName)
                await MainActor.run {
                    addLog("✅ Local collection created with ID: \(collectionId)")
                }
                
                // Create cloud collection if connected
                if isCloudConnected, let cloudClient = cloudClient {
                    addLog("🌐 Creating cloud collection: \(newCollectionName)")
                    try await cloudClient.createCloudCollection(name: newCollectionName)
                    await MainActor.run {
                        addLog("✅ Cloud collection created: \(newCollectionName)")
                    }
                }
                
            } catch {
                await MainActor.run {
                    addLog("❌ Collection creation error: \(error)")
                }
            }
        }
    }
    
    private func addSampleDocuments() {
        Task {
            do {
                addLog("📝 Adding sample documents to collection: \(newCollectionName)")
                
                // Add sample documents to local collection
                let documents = [
                    (id: "doc1", text: "This is a sample document about Swift programming", embedding: [Float](repeating: 0.1, count: 4)),
                    (id: "doc2", text: "Another document discussing Chroma vector database", embedding: [Float](repeating: 0.2, count: 4)),
                    (id: "doc3", text: "A third document covering cloud synchronization", embedding: [Float](repeating: 0.3, count: 4))
                ]
                
                let totalCount = try client.addDocuments(
                    toCollection: newCollectionName,
                    documents: documents
                )
                
                await MainActor.run {
                    addLog("✅ Added \(documents.count) documents. Total: \(totalCount)")
                }
                
            } catch {
                await MainActor.run {
                    addLog("❌ Document creation error: \(error)")
                }
            }
        }
    }
    
    private func uploadCollectionToCloud() {
        guard let cloudClient = cloudClient else {
            addLog("❌ Cloud client not configured")
            return
        }
        
        Task {
            do {
                addLog("🔄 Uploading collection '\(newCollectionName)' to cloud...")
                
                try await cloudClient.syncCollectionToCloud(
                    fromLocalClient: client,
                    localCollectionName: newCollectionName,
                    cloudCollectionName: newCollectionName
                )
                
                await MainActor.run {
                    addLog("✅ Successfully uploaded '\(newCollectionName)' to cloud!")
                }
                
            } catch {
                await MainActor.run {
                    addLog("❌ Upload error: \(error)")
                }
            }
        }
    }
}


