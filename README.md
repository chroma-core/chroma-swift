>  :warning: *Chroma Swift is currently in Beta*
> 
> This means that the core APIs work well - but we are still gaining full confidence over all possible edge cases.

# Chroma Swift Package

Chroma is a Swift package that provides a high-performance, cross-platform interface for working with vector stores and embeddings collections, backed by the [Chroma](https://github.com/chroma-core/chroma) database engine. It is designed for use in macOS and iOS applications, supporting both Apple Silicon and Intel architectures.



## Features

- Create, list, and delete collections
- Add documents with embeddings and metadata
- Perform similarity search and queries over collections
- Retrieve, update, and delete documents
- Reset and initialize the database
- Pure Swift API with UniFFI bindings to the Chroma core



## Requirements

- Swift 6.0+
- macOS 14+ or iOS 17+



## Installation

Add Chroma to your `Package.swift` dependencies:

```swift
.package(url: "https://github.com/your-org/ChromaSwift.git", from: "1.0.0")
```

Then add `Chroma` as a dependency for your target:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "Chroma", package: "ChromaSwift")
    ]
)
```



## Usage

Import the package in your Swift file:

```swift
import Chroma
```

### Basic Example (Ephemeral)
```swift
try Chroma.initialize(allowReset: true)
let collectionName = "my_collection"
let collectionId = try Chroma.createCollection(name: collectionName)
let ids = ["doc1", "doc2"]
let embeddings: [[Float]] = [[0.1, 0.2, 0.3], [0.3, 0.2, 0.1]]
let documents = ["Document 1 text", "Document 2 text"]
try Chroma.addDocuments(collectionName: collectionName, ids: ids, embeddings: embeddings, documents: documents)
let results = try Chroma.queryCollection(collectionName: collectionName, queryEmbeddings: [[0.1, 0.2, 0.3]], nResults: 1, whereFilter: nil, ids: nil, include: nil)

```



### Persistent Storage

By default, Chroma operates in an ephemeral mode where data is stored in memory and lost when your application terminates. For persistent storage, initialize Chroma with a specific file path:

```swift
// Specify a directory path for persistent storage
let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let chromaDirectory = documentsDirectory.appendingPathComponent("chroma_db").path

// Initialize with persistent storage
try Chroma.initializeWithPath(path: chromaDirectory, allowReset: false)

// Now all operations will persist data to disk
let collectionName = "persistent_collection"
let collectionId = try Chroma.createCollection(name: collectionName)

// Add documents as usual
let ids = ["doc1", "doc2"]
let embeddings: [[Float]] = [[0.1, 0.2, 0.3], [0.3, 0.2, 0.1]]
let documents = ["Document 1 text", "Document 2 text"]
try Chroma.addDocuments(collectionName: collectionName, ids: ids, embeddings: embeddings, documents: documents)

// Data will be preserved between app sessions
```



#### Persistence Best Practices

- Set `allowReset` to `false` in production to prevent accidental data loss
- Use a consistent path across app launches to access the same database
- Consider implementing backup and migration strategies for your persistent database
- For iOS apps, use the app's Documents directory to ensure the database is included in backups
- For macOS apps, consider user preferences for database location



### Using Local Embeddings Models

ChromaSwift includes built-in support for local embeddings generation using the `ChromaEmbedder` class. This allows you to generate embeddings directly on-device without requiring external API calls.
Local embeddings are powered by `MLXEmbedders` from `mlx-swift-lm`.

```swift
import Chroma

// Initialize Chroma and create a collection
try Chroma.initialize(allowReset: true)
let collectionName = "my_collection"
let collectionId = try Chroma.createCollection(name: collectionName)

// Create an embedder with your chosen model
let embedder = ChromaEmbedder(model: .miniLML6)

// Load the model (only needs to be done once)
await embedder.loadModel()

// Add documents with automatic embedding
let ids = ["doc1", "doc2"]
let texts = ["Document 1 text", "Document 2 text"]
let count = try await embedder.addDocuments(to: collectionName, ids: ids, texts: texts)

// Query using text instead of pre-computed embeddings
let results = try await embedder.queryCollection(collectionName, queryText: "similar document", nResults: 5)
```



## API Overview

### Initialization Functions
- `initialize(allowReset: Bool)`
  
  Initializes the Chroma database.

- `initializeWithPath(path: String?, allowReset: Bool)`
  
  Initializes the Chroma database at a specific path for persistent storage. 

### Collection Management
- `createCollection(name: String) -> String`
  
  Creates a new collection. 

- `getCollection(collectionName: String) -> CollectionInfo`
  
  Gets information about a collection including name, ID, and document count.

- `listCollections() -> [String]`
  
  Returns a list of all collection names.

- `deleteCollection(collectionName: String)`
  
  Deletes a collection and all its documents. 

- `updateCollection(collectionName: String, newName: String?)`
  
  Updates a collection's name.

- `countCollections() -> UInt32`
  
  Returns the total number of collections.

### Document/Record Management
- `addDocuments(collectionName: String, ids: [String], embeddings: [[Float]], documents: [String]) -> UInt32`
  
  Adds documents with embeddings to a collection.

- `getAllDocuments(collectionName: String) -> GetResult`
  
  Retrieves all documents and their metadata from a collection.

- `getDocuments(collectionName: String, ids: [String]?, whereClause: String?, limit: UInt32?, offset: UInt32?, whereDocument: String?, include: [String]?) -> AdvancedGetResult`
  
  Advanced document retrieval with filtering, pagination, and field selection.

- `updateDocuments(collectionName: String, ids: [String], embeddings: [[Float]]?, documents: [String]?)`
  
  Updates existing documents with new embeddings and/or content.

- `upsertDocuments(collectionName: String, ids: [String], embeddings: [[Float]]?, documents: [String]?)`
  
  Insert or update documents (upsert operation).

- `deleteDocuments(collectionName: String, ids: [String]?)`
  
  Deletes documents by their IDs.

- `countDocuments(collectionName: String) -> UInt32`
  
  Returns the number of documents in a collection.

### Query Functions
- `queryCollection(collectionName: String, queryEmbeddings: [[Float]], nResults: UInt32, whereFilter: String?, ids: [String]?, include: [String]?) -> QueryResult`
  
  Performs similarity search on the collection using embeddings.

### Database Management
- `createDatabase(name: String) -> String`
  
  Creates a new database.

- `getDatabase(name: String) -> DatabaseInfo`
  
  Gets information about a database.

- `listDatabases() -> [String]`
  
  Returns a list of all database names.

- `deleteDatabase(name: String)`
  
  Deletes a database.

### System Functions
- `reset()`
  
  Resets the database, clearing all collections and documents. 

- `getVersion() -> String`
  
  Returns the version of the Chroma core.

- `getMaxBatchSize() -> UInt32`
  
  Returns the maximum batch size for operations.

- `heartbeat() -> Int64`
  
  Returns a timestamp indicating the system is alive.



## Local Embeddings Support

ChromaSwift includes built-in support for generating embeddings directly on-device using the `ChromaEmbedder` class. This eliminates the need for external API calls and enables fully offline operation.

### Available Models

| Model | Dimensions | Size | Best For | Hugging Face Model Card |
|-------|------------|------|----------|-------------------------|
| `bgeMicro` | 384 | ~17MB | Mobile, resource-constrained environments | [TaylorAI/bge-micro-v2](https://huggingface.co/TaylorAI/bge-micro-v2) |
| `gteTiny` | 384 | ~25MB | Mobile, lightweight deployments | [TaylorAI/gte-tiny](https://huggingface.co/TaylorAI/gte-tiny) |
| `miniLML6` | 384 | ~90MB | Balanced performance/quality | [sentence-transformers/all-MiniLM-L6-v2](https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2) |
| `miniLML12` | 384 | ~130MB | Better quality, moderate size | [sentence-transformers/all-MiniLM-L12-v2](https://huggingface.co/sentence-transformers/all-MiniLM-L12-v2) |
| `bgeSmall` | 384 | ~130MB | Better quality, moderate size | [BAAI/bge-small-en-v1.5](https://huggingface.co/BAAI/bge-small-en-v1.5) |
| `bgeBase` | 768 | ~440MB | Desktop apps, higher quality | [BAAI/bge-base-en-v1.5](https://huggingface.co/BAAI/bge-base-en-v1.5) |
| `bgeLarge` | 1024 | ~1.3GB | Maximum quality, desktop only | [BAAI/bge-large-en-v1.5](https://huggingface.co/BAAI/bge-large-en-v1.5) |
| `mixedbreadLarge` | 1024 | ~1.3GB | Maximum quality, desktop only | [mixedbread-ai/mxbai-embed-large-v1](https://huggingface.co/mixedbread-ai/mxbai-embed-large-v1) |



## License

ChromaSwift is available under the Apache License 2.0, same as the underlying Chroma library. See the [LICENSE](https://github.com/chroma-core/chroma-swift/blob/master/LICENSE) file for more info.

---

This package uses [cargo-swift](https://docs.rs/cargo-swift/latest/cargo_swift/) to generate Swift bindings and FFI code. The underlying FFI bindings are created with [UniFFI](https://mozilla.github.io/uniffi-rs/), enabling seamless interop between Swift and the Chroma core implemented in Rust.

*This package includes FFI bindings generated by UniFFI and links to a binary framework for the Chroma core. For advanced usage and troubleshooting, see the Chroma source code and documentation comments.*
