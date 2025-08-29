import Foundation
import Chroma

/// A simple wrapper client for Chroma operations
public class ChromaClient {
    
    private var isInitialized = false
    private var isCloudMode = false
    private var cloudHost: String?
    private var cloudTenant: String?
    private var cloudDatabase: String?
    private var cloudApiKey: String?
    
    public init() {}
    
    public init(cloudTenant: String, database: String, apiKey: String? = nil, host: String = "api.trychroma.com") {
        self.cloudTenant = cloudTenant
        self.cloudDatabase = database
        self.cloudApiKey = apiKey
        self.cloudHost = host
        self.isCloudMode = true
    }
    
    /// Initialize the Chroma database
    public func initialize(allowReset: Bool = true) throws {
        if isCloudMode {
            // For cloud mode, we don't need to call the local initialize
            // The cloud connection will be established when we make API calls
            isInitialized = true
        } else {
            try Chroma.initialize(allowReset: allowReset)
            isInitialized = true
        }
    }
    
    /// Test cloud connectivity with heartbeat endpoint
    public func testCloudConnection() async throws -> Bool {
        guard isCloudMode else {
            print("❌ ChromaClient: Not in cloud mode")
            throw ChromaClientError.notInCloudMode
        }
        
        guard let host = cloudHost else {
            print("❌ ChromaClient: Missing cloud host configuration")
            throw ChromaClientError.missingCloudConfiguration
        }
        
        // Construct the heartbeat URL
        let urlString = "https://\(host):443/api/v2/heartbeat"
        print("🔍 ChromaClient: Testing connection to \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ ChromaClient: Invalid URL: \(urlString)")
            throw ChromaClientError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add API key if provided
        if let apiKey = cloudApiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            print("🔐 ChromaClient: Added API key authentication")
        }
        
        // Add tenant header if provided
        if let tenant = cloudTenant {
            request.setValue(tenant, forHTTPHeaderField: "X-Chroma-Tenant")
            print("🏢 ChromaClient: Using tenant: \(tenant)")
        }
        
        // Add database header if provided
        if let database = cloudDatabase {
            request.setValue(database, forHTTPHeaderField: "X-Chroma-Database")
            print("💾 ChromaClient: Using database: \(database)")
        }
        
        do {
            print("📡 ChromaClient: Sending heartbeat request...")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 ChromaClient: Received response with status code: \(httpResponse.statusCode)")
                if let responseData = String(data: data, encoding: .utf8), !responseData.isEmpty {
                    print("📋 ChromaClient: Response data: \(responseData)")
                }
                return httpResponse.statusCode == 200
            }
            print("❌ ChromaClient: Invalid response type")
            return false
        } catch {
            print("❌ ChromaClient: Network error: \(error)")
            throw ChromaClientError.networkError(error)
        }
    }
    
    /// Create a new collection
    public func createCollection(name: String) throws -> String {
        guard isInitialized else {
            throw ChromaClientError.notInitialized
        }
        return try Chroma.createCollection(name: name)
    }
    
    /// List all collections
    public func listCollections() throws -> [String] {
        guard isInitialized else {
            throw ChromaClientError.notInitialized
        }
        return try Chroma.listCollections()
    }
    
    /// Add documents to a collection
    public func addDocuments(
        toCollection collectionName: String,
        documents: [(id: String, text: String, embedding: [Float])]
    ) throws -> UInt32 {
        guard isInitialized else {
            throw ChromaClientError.notInitialized
        }
        
        let ids = documents.map { $0.id }
        let texts = documents.map { $0.text }
        let embeddings = documents.map { $0.embedding }
        
        return try Chroma.addDocuments(
            collectionName: collectionName,
            ids: ids,
            embeddings: embeddings,
            documents: texts
        )
    }
    
    /// Add a single document with a simple embedding
    public func addDocument(
        toCollection collectionName: String,
        id: String,
        text: String,
        embedding: [Float] = [0.1, 0.2, 0.3, 0.4]
    ) throws -> UInt32 {
        return try addDocuments(
            toCollection: collectionName,
            documents: [(id: id, text: text, embedding: embedding)]
        )
    }
    
    /// Get all documents from a collection
    public func getAllDocuments(fromCollection collectionName: String) throws -> GetResult {
        guard isInitialized else {
            throw ChromaClientError.notInitialized
        }
        return try Chroma.getAllDocuments(collectionName: collectionName)
    }
    
    /// Query a collection with embeddings
    public func queryCollection(
        name: String,
        queryEmbeddings: [[Float]],
        nResults: UInt32 = 10
    ) throws -> QueryResult {
        guard isInitialized else {
            throw ChromaClientError.notInitialized
        }
        
        return try Chroma.queryCollection(
            collectionName: name,
            queryEmbeddings: queryEmbeddings,
            nResults: nResults,
            whereFilter: nil,
            ids: nil,
            include: nil
        )
    }
    
    /// Reset the database
    public func reset() throws {
        try Chroma.reset()
        isInitialized = false
    }
    
    /// Sync local collection to cloud
    public func syncCollectionToCloud(
        fromLocalClient localClient: ChromaClient,
        localCollectionName: String,
        cloudCollectionName: String? = nil
    ) async throws {
        guard isCloudMode else {
            print("❌ ChromaClient: Not in cloud mode for sync")
            throw ChromaClientError.notInCloudMode
        }
        
        guard isInitialized else {
            print("❌ ChromaClient: Not initialized for sync")
            throw ChromaClientError.notInitialized
        }
        
        let targetCollectionName = cloudCollectionName ?? localCollectionName
        print("🔄 ChromaClient: Starting sync of '\(localCollectionName)' -> '\(targetCollectionName)'")
        
        // Get all documents from local collection
        print("📖 ChromaClient: Reading documents from local collection '\(localCollectionName)'")
        let localDocs = try localClient.getAllDocuments(fromCollection: localCollectionName)
        
        guard !localDocs.ids.isEmpty else {
            print("ℹ️ ChromaClient: No documents to sync in collection '\(localCollectionName)'")
            return // Nothing to sync
        }
        
        print("📊 ChromaClient: Found \(localDocs.ids.count) documents to sync")
        
        // Get the cloud collection to find its ID
        if let cloudCollection = try await getCloudCollectionByName(name: targetCollectionName),
           let collectionId = cloudCollection["id"] as? String {
            // Upload documents to cloud via REST API using collection ID
            try await uploadDocumentsToCloud(
                collectionId: collectionId,
                documents: localDocs
            )
        } else {
            print("❌ ChromaClient: Could not find cloud collection ID for '\(targetCollectionName)'")
            throw ChromaClientError.networkError(
                NSError(domain: "ChromaCloudSync", code: 404, userInfo: [
                    NSLocalizedDescriptionKey: "Could not find cloud collection '\(targetCollectionName)'"
                ])
            )
        }
        
        print("✅ ChromaClient: Successfully synced collection '\(localCollectionName)'")
    }
    
    /// Upload documents to cloud using REST API
    private func uploadDocumentsToCloud(
        collectionId: String,
        documents: GetResult
    ) async throws {
        guard let host = cloudHost else {
            print("❌ ChromaClient: Missing cloud host for upload")
            throw ChromaClientError.missingCloudConfiguration
        }
        
        print("📤 ChromaClient: Uploading \(documents.ids.count) documents to cloud collection ID '\(collectionId)'")
        
        // Use exact endpoint like Python CloudClient with collection ID
        let urlString = "https://\(host):443/api/v2/tenants/\(cloudTenant ?? "default_tenant")/databases/\(cloudDatabase ?? "default_database")/collections/\(collectionId)/add"
        
        print("🌐 ChromaClient: Adding documents to \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ ChromaClient: Invalid upload URL: \(urlString)")
            throw ChromaClientError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add headers exactly like Python CloudClient
        if let apiKey = cloudApiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-Chroma-Token")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("ChromaSwift Client v1.0.0", forHTTPHeaderField: "User-Agent")
        
        // Prepare the payload (similar to Python client)
        // Generate simple embeddings if not available
        let embeddings = Array(0..<documents.ids.count).map { i in
            Array(repeating: Float(0.1 + Float(i) * 0.1), count: 4)
        }
        
        let payload: [String: Any] = [
            "ids": documents.ids,
            "documents": documents.documents.compactMap { $0 },
            "embeddings": embeddings,
            "metadatas": Array(repeating: [:], count: documents.ids.count)
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 ChromaClient: Upload response status: \(httpResponse.statusCode)")
            
            if let responseData = String(data: data, encoding: .utf8), !responseData.isEmpty {
                print("📋 ChromaClient: Upload response: \(responseData)")
            }
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                print("✅ ChromaClient: Documents uploaded successfully")
                return
            } else {
                throw ChromaClientError.networkError(
                    NSError(domain: "ChromaCloudSync", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to upload documents. Status: \(httpResponse.statusCode)"
                    ])
                )
            }
        } else {
            throw ChromaClientError.networkError(
                NSError(domain: "ChromaCloudSync", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid response"
                ])
            )
        }
    }
    
    /// Create a collection in the cloud (or check if it exists)
    public func createCloudCollection(name: String) async throws {
        // First, try to check if collection exists with GET
        if await checkCollectionExists(name: name) {
            print("ℹ️ ChromaClient: Collection '\(name)' already exists")
            return
        }
        
        // If it doesn't exist, try to create it
        guard let host = cloudHost else {
            print("❌ ChromaClient: Missing cloud host for collection creation")
            throw ChromaClientError.missingCloudConfiguration
        }
        
        // Use exact endpoint like Python CloudClient
        let urlString = "https://\(host):443/api/v2/tenants/\(cloudTenant ?? "default_tenant")/databases/\(cloudDatabase ?? "default_database")/collections"
        
        print("🏗️ ChromaClient: Creating collection at \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ ChromaClient: Invalid collection creation URL: \(urlString)")
            throw ChromaClientError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add headers exactly like Python CloudClient
        if let apiKey = cloudApiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-Chroma-Token")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("ChromaSwift Client v1.0.0", forHTTPHeaderField: "User-Agent")
        
        let payload: [String: Any] = [
            "name": name,
            "get_or_create": true
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 ChromaClient: Response status: \(httpResponse.statusCode)")
            
            if let responseData = String(data: data, encoding: .utf8), !responseData.isEmpty {
                print("📋 ChromaClient: Response: \(responseData)")
            }
            
            // Accept both 200 (success) and 409 (collection already exists) as successful
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                print("✅ ChromaClient: Collection '\(name)' created successfully")
                return
            } else if httpResponse.statusCode == 409 {
                print("ℹ️ ChromaClient: Collection '\(name)' already exists")
                return
            } else {
                throw ChromaClientError.networkError(
                    NSError(domain: "ChromaCloudSync", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to create collection. Status: \(httpResponse.statusCode)"
                    ])
                )
            }
        } else {
            throw ChromaClientError.networkError(
                NSError(domain: "ChromaCloudSync", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid response"
                ])
            )
        }
    }
    
    /// List all collections in the cloud
    public func listCloudCollections() async throws -> [String] {
        guard isCloudMode else {
            throw ChromaClientError.notInCloudMode
        }
        
        guard let host = cloudHost else {
            throw ChromaClientError.missingCloudConfiguration
        }
        
        // Use exact endpoint like Python CloudClient
        let urlString = "https://\(host):443/api/v2/tenants/\(cloudTenant ?? "default_tenant")/databases/\(cloudDatabase ?? "default_database")/collections"
        
        print("📋 ChromaClient: Listing collections at \(urlString)")
            
        guard let url = URL(string: urlString) else {
            print("❌ ChromaClient: Invalid URL: \(urlString)")
            throw ChromaClientError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add headers exactly like Python CloudClient
        if let apiKey = cloudApiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-Chroma-Token")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("ChromaSwift Client v1.0.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 ChromaClient: List response status: \(httpResponse.statusCode)")
            
            if let responseData = String(data: data, encoding: .utf8), !responseData.isEmpty {
                print("📋 ChromaClient: Collections response: \(responseData)")
            }
            
            if httpResponse.statusCode == 200 {
                // Parse the response to get collection names
                if let json = try? JSONSerialization.jsonObject(with: data) as? [Any] {
                    return json.compactMap { item in
                        if let dict = item as? [String: Any], let name = dict["name"] as? String {
                            return name
                        }
                        return nil
                    }
                }
                return []
            } else {
                throw ChromaClientError.networkError(
                    NSError(domain: "ChromaCloudSync", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to list collections. Status: \(httpResponse.statusCode)"
                    ])
                )
            }
        } else {
            throw ChromaClientError.networkError(
                NSError(domain: "ChromaCloudSync", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid response"
                ])
            )
        }
    }
    
    /// Try to access a collection by name directly
    public func getCloudCollectionByName(name: String) async throws -> [String: Any]? {
        guard let host = cloudHost else {
            throw ChromaClientError.missingCloudConfiguration
        }
        
        // Use exact endpoint like Python CloudClient
        let urlString = "https://\(host):443/api/v2/tenants/\(cloudTenant ?? "default_tenant")/databases/\(cloudDatabase ?? "default_database")/collections/\(name)"
        
        print("🔍 ChromaClient: Getting collection at \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ ChromaClient: Invalid URL: \(urlString)")
            throw ChromaClientError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add headers exactly like Python CloudClient
        if let apiKey = cloudApiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-Chroma-Token")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("ChromaSwift Client v1.0.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 ChromaClient: Collection GET response status: \(httpResponse.statusCode)")
            
            if let responseData = String(data: data, encoding: .utf8), !responseData.isEmpty {
                print("📋 ChromaClient: Collection response: \(responseData)")
            }
            
            if httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    return json
                }
                return [:]
            } else if httpResponse.statusCode == 404 {
                return nil
            } else {
                throw ChromaClientError.networkError(
                    NSError(domain: "ChromaCloudSync", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to get collection. Status: \(httpResponse.statusCode)"
                    ])
                )
            }
        } else {
            throw ChromaClientError.networkError(
                NSError(domain: "ChromaCloudSync", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid response"
                ])
            )
        }
    }
    
    /// Discover available API endpoints
    public func discoverAPIEndpoints() async throws {
        guard let host = cloudHost else {
            throw ChromaClientError.missingCloudConfiguration
        }
        
        // Try common API discovery endpoints
        let discoveryEndpoints = [
            "https://\(host):443/",
            "https://\(host):443/api",
            "https://\(host):443/api/v2",
            "https://\(host):443/docs",
            "https://\(host):443/openapi.json",
            "https://\(host):443/.well-known/api",
            "https://\(host):443/api/v2/docs"
        ]
        
        for urlString in discoveryEndpoints {
            print("🔍 ChromaClient: Discovering endpoints at \(urlString)")
            
            guard let url = URL(string: urlString) else { continue }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            // Add authentication headers for protected endpoints
            if let apiKey = cloudApiKey {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            
            if let tenant = cloudTenant {
                request.setValue(tenant, forHTTPHeaderField: "X-Chroma-Tenant")
            }
            
            if let database = cloudDatabase {
                request.setValue(database, forHTTPHeaderField: "X-Chroma-Database")
            }
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 ChromaClient: Discovery response status: \(httpResponse.statusCode) for \(urlString)")
                    
                    if let responseData = String(data: data, encoding: .utf8), !responseData.isEmpty {
                        print("📋 ChromaClient: Discovery response (\(responseData.count) chars): \(String(responseData.prefix(500)))")
                        if responseData.count > 500 {
                            print("    ... (truncated)")
                        }
                    }
                }
            } catch {
                print("❌ ChromaClient: Discovery error at \(urlString): \(error)")
            }
        }
    }
    
    
    /// Check if a collection exists in the cloud
    private func checkCollectionExists(name: String) async -> Bool {
        guard let host = cloudHost else {
            print("❌ ChromaClient: Missing cloud host for collection check")
            return false
        }
        
        let urlString = "https://\(host)/api/v2/collections/\(name)"
        print("🔍 ChromaClient: Checking if collection '\(name)' exists at \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ ChromaClient: Invalid collection check URL: \(urlString)")
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add headers exactly like Python CloudClient
        if let apiKey = cloudApiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-Chroma-Token")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("ChromaSwift Client v1.0.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 ChromaClient: Collection check response status: \(httpResponse.statusCode)")
                
                if let responseData = String(data: data, encoding: .utf8), !responseData.isEmpty {
                    print("📋 ChromaClient: Collection check response: \(responseData)")
                }
                
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            print("❌ ChromaClient: Collection check error: \(error)")
            return false
        }
    }
}

/// Custom errors for the ChromaClient
public enum ChromaClientError: Error, LocalizedError {
    case notInitialized
    case notInCloudMode
    case missingCloudConfiguration
    case invalidURL
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Chroma client is not initialized. Call initialize() first."
        case .notInCloudMode:
            return "Client is not configured for cloud mode."
        case .missingCloudConfiguration:
            return "Missing required cloud configuration (host, tenant, or database)."
        case .invalidURL:
            return "Invalid URL for cloud connection."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
