>  :warning: *Chroma Swift is currently in Beta*
> 
> This means that the core APIs work well - but we are still gaining full confidence over all possible edge cases.

# Chroma Swift Package

Chroma is a Swift package that provides a high-performance, cross-platform interface for working with vector stores and embeddings collections, backed by the [Chroma](https://github.com/chroma-core/chroma) database engine. It is designed for use in macOS and iOS applications, supporting both Apple Silicon and Intel architectures.

## See what this package includes

- Initialize in-memory or persistent storage
- Create, list, count, update, and delete collections
- Add, get, update, upsert, count, query, and delete documents
- Query by embeddings, including batched queries
- Optional field selection via `include` in `getDocuments` and `queryCollection`
- Database-level APIs (`createDatabase`, `getDatabase`, `listDatabases`, `deleteDatabase`)
- Typed metadata decode helpers via `ChromaMetadataValue` and `decodedMetadatas()`
- Local embeddings with `ChromaEmbedder` + MLXEmbedders models

## Check requirements

- Swift 6.2+
- macOS 14+ or iOS 17+

## Install Chroma Swift

1. Add this package dependency:

```swift
.package(url: "https://github.com/chroma-core/chroma-swift.git", from: "1.0.2")
```

2. Add the product to your app target:

```swift
.target(
    name: "YourApp",
    dependencies: [
	    .product(name: "Chroma", package: "ChromaSwift")
    ]
)
```

3. Import the module where you use it:

```swift
import Chroma
```

## Install and use the Chroma skill

This repository ships a local skill bundle at:

- `Skill/chroma-swift/`

Copy the `chroma-swift/` directory (not just `SKILL.md`) into one of the skill locations below.

### Install for Codex

Use one of these locations:

- Project scope: `.agents/skills/chroma-swift/`
- User scope: `~/.agents/skills/chroma-swift/`

### Install for Claude Code

Use one of these locations:

- Project scope: `.claude/skills/chroma-swift/`
- User scope: `~/.claude/skills/chroma-swift/`

### Invoke the skill in prompts

After installation, refer to the skill by name only:

```text
Use the chroma skill to review my collection schema and retrieval flow, then propose fixes.
```

## Run an end-to-end quick start (Ephemeral)

### What you'll do

- Initialize Chroma in memory
- Create one collection
- Add two documents with sample embeddings
- Use realistic document text content (not file names or titles)
- Define realistic metadata shape for each document
- Run one nearest-neighbour query

### Before you start

- Call `Chroma.initialize(...)` before any collection or document operation.
- This example uses tiny hand-written vectors so the end-to-end flow is easy to read.
- In real apps, generate embeddings with an embedding model, and use the same model for writes and queries in the same collection.

### Do it

1. Add this code:

```swift
import Chroma

try Chroma.initialize(allowReset: true)

let collectionName = "my_collection"
_ = try Chroma.createCollection(name: collectionName)

let ids = ["cats_doc", "dogs_doc"]
let embeddings: [[Float]] = [
    [1.0, 0.0, 0.0],
    [0.0, 1.0, 0.0]
]

let documents = [
    "Cats are small carnivores often kept as companion animals.",
    "Dogs are domesticated canids known for companionship and work."
]

let metadatas: [ChromaMetadata?] = [
    [
        "source_url": "file:///knowledge/animals/cats.txt",
        "content_type": "text/plain"
    ],
    [
        "source_url": "file:///knowledge/animals/dogs.md",
        "content_type": "text/markdown",
        "reviewed": true
    ]
]

_ = try Chroma.addDocuments(
    collectionName: collectionName,
    ids: ids,
    embeddings: embeddings,
    documents: documents,
    metadatas: metadatas
)

let result = try Chroma.queryCollection(
    collectionName: collectionName,
    queryEmbeddings: [[1.0, 0.0, 0.0]],
    nResults: 1,
    whereFilter: nil,
    ids: nil,
    include: ["documents"]
)

let topId = result.ids[0][0]
let topDocument = result.documents[0][0] ?? "<missing document>"
print("Top match: \(topId) -> \(topDocument)") // expected: Top match: cats_doc -> Cats are small carnivores often kept as companion animals.
```

### Verify it worked

- `try Chroma.countCollections()` returns `1`.
- `try Chroma.countDocuments(collectionName: "my_collection")` returns `2`.
- Printed output includes `Top match: cats_doc -> Cats are small carnivores often kept as companion animals.`.

## Persist data to disk

By default, Chroma operates in an ephemeral mode where data is stored in memory and lost when your application terminates. For persistent storage, initialize Chroma with a specific file path:

1. Initialize with `initializeWithPath`.
2. Reuse the same path next launch.

```swift
let chromaDirectory = URL.documentsDirectory
    .appendingPathComponent("chroma_db")
    .path

try Chroma.initializeWithPath(path: chromaDirectory, allowReset: false)

// Data will be preserved between app sessions
```

### Apply persistence best practices

- Set `allowReset` to `false` in production to prevent accidental data loss.
- Use one consistent path across launches.
- Back up and migrate your on-disk database as part of app updates.
- On iOS, prefer the app Documents directory if you want backup inclusion.
- On macOS, choose a user-visible location policy for supportability.

## Use local embeddings models

`ChromaEmbedder` lets you embed text on-device using `MLXEmbedders` from `mlx-swift-lm`.

1. Create an embedder.
2. Load the model once.
3. Add text documents with automatic embedding.
4. Query with text directly.

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
let count = try await embedder.addDocuments(
    to: collectionName,
    ids: ["doc1", "doc2"],
    texts: ["Document 1 text", "Document 2 text"]
)

// Query using text instead of pre-computed embeddings
let results = try await embedder.queryCollection(
    collectionName,
    queryText: "similar document",
    nResults: 5
)
```

### Verify local embeddings are ready

- `embedder.embeddingDimensions` matches the selected model.
- `try await embedder.embed(text: "...")` returns non-zero values.
- Result vector L2 norm is approximately `1.0` for supported models.

### Choose an embedding model

Approximate sizes come from current model cards and may change as upstream revisions ship.

| Case | Hugging Face model ID | Dimensions | Approximate size | Typical use |
|---|---|---:|---:|---|
| `bgeMicro` | [TaylorAI/bge-micro-v2](https://huggingface.co/TaylorAI/bge-micro-v2) | 384 | ~17MB | Mobile, constrained memory |
| `gteTiny` | [TaylorAI/gte-tiny](https://huggingface.co/TaylorAI/gte-tiny) | 384 | ~25MB | Mobile, lightweight |
| `miniLML6` | [sentence-transformers/all-MiniLM-L6-v2](https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2) | 384 | ~90MB | Balanced quality/speed |
| `miniLML12` | [sentence-transformers/all-MiniLM-L12-v2](https://huggingface.co/sentence-transformers/all-MiniLM-L12-v2) | 384 | ~130MB | Higher quality than L6 |
| `bgeSmall` | [BAAI/bge-small-en-v1.5](https://huggingface.co/BAAI/bge-small-en-v1.5) | 384 | ~130MB | Strong small model |
| `bgeBase` | [BAAI/bge-base-en-v1.5](https://huggingface.co/BAAI/bge-base-en-v1.5) | 768 | ~440MB | Desktop quality |
| `bgeLarge` | [BAAI/bge-large-en-v1.5](https://huggingface.co/BAAI/bge-large-en-v1.5) | 1024 | ~1.3GB | Maximum quality |
| `mixedbreadLarge` | [mixedbread-ai/mxbai-embed-large-v1](https://huggingface.co/mixedbread-ai/mxbai-embed-large-v1) | 1024 | ~1.3GB | Maximum quality |

## Handle metadata correctly

`ChromaMetadata` is a typealias:

```swift
public typealias ChromaMetadata = [String: ChromaMetadataValue]
```

Supported value types:

- `bool(Bool)`
- `int(Int64)`
- `float(Double)`
- `string(String)`

You can decode metadata returned by `getDocuments`:

```swift
let result = try Chroma.getDocuments(
    collectionName: "my_collection",
    ids: nil,
    whereClause: nil,
    limit: nil,
    offset: nil,
    whereDocument: nil,
    include: ["metadatas"]
)

let decoded = result.decodedMetadatas()
```

> **CAUTION**
> Metadata writes are currently blocked by the shipped Chroma core binary.
> `Chroma.addDocuments(..., metadatas: ...)` throws `ChromaMetadataError.metadataWriteUnsupported` if any metadata entry is non-`nil`.

## Use the complete API reference

### Understand result and model types

| Type | Fields |
|---|---|
| `CollectionInfo` | `name: String`, `collectionId: String`, `numDocuments: UInt32` |
| `DatabaseInfo` | `id: String`, `name: String`, `tenant: String` |
| `GetResult` | `ids: [String]`, `documents: [String?]` |
| `AdvancedGetResult` | `ids: [String]`, `embeddings: [[Float]]?`, `documents: [String?]?`, `metadatas: [String?]?`, `uris: [String?]?` |
| `QueryResult` | `ids: [[String]]`, `documents: [[String?]]`, `distances: [[Float?]]?` |
| `ChromaError` | `.Generic(message: String)` |
| `ChromaMetadataError` | `.countMismatch(expected:actual:)`, `.metadataWriteUnsupported` |
| `ChromaEmbedderError` | `.modelNotLoaded`, `.modelLoadingFailed(_,_)`, `.embeddingFailed(_,_)` |

### Call Chroma core functions

```swift
// Initialization and system
func initialize(allowReset: Bool) throws
func initializeWithPath(path: String?, allowReset: Bool) throws
func reset() throws
func getVersion() throws -> String
func getMaxBatchSize() throws -> UInt32
func heartbeat() throws -> Int64

// Collections
func createCollection(name: String) throws -> String
func getCollection(collectionName: String) throws -> CollectionInfo
func listCollections() throws -> [String]
func updateCollection(collectionName: String, newName: String?) throws
func deleteCollection(collectionName: String) throws
func countCollections() throws -> UInt32

// Documents
func addDocuments(collectionName: String, ids: [String], embeddings: [[Float]], documents: [String]) throws -> UInt32
func addDocuments(collectionName: String, ids: [String], embeddings: [[Float]], documents: [String], metadatas: [ChromaMetadata?]) throws -> UInt32
func getAllDocuments(collectionName: String) throws -> GetResult
func getDocuments(collectionName: String, ids: [String]?, whereClause: String?, limit: UInt32?, offset: UInt32?, whereDocument: String?, include: [String]?) throws -> AdvancedGetResult
func updateDocuments(collectionName: String, ids: [String], embeddings: [[Float]]?, documents: [String]?) throws
func upsertDocuments(collectionName: String, ids: [String], embeddings: [[Float]]?, documents: [String]?) throws
func deleteDocuments(collectionName: String, ids: [String]?) throws
func countDocuments(collectionName: String) throws -> UInt32

// Queries
func queryCollection(collectionName: String, queryEmbeddings: [[Float]], nResults: UInt32, whereFilter: String?, ids: [String]?, include: [String]?) throws -> QueryResult

// Databases
func createDatabase(name: String) throws -> String
func getDatabase(name: String) throws -> DatabaseInfo
func listDatabases() throws -> [String]
func deleteDatabase(name: String) throws
```

### Call ChromaEmbedder functions

```swift
public init(model: ChromaEmbedder.EmbeddingModel = .miniLML6)
public func loadModel() async throws
public func embed(text: String) async throws -> [Float]
public func embed(texts: [String]) async throws -> [[Float]]
public func addDocuments(to collectionName: String, ids: [String], texts: [String], metadatas: [ChromaMetadata?]? = nil) async throws -> UInt32
public func queryCollection(_ collectionName: String, queryTexts: [String], nResults: UInt32 = 10, whereFilter: String? = nil, ids: [String]? = nil, include: [String]? = nil) async throws -> QueryResult
public func queryCollection(_ collectionName: String, queryText: String, nResults: UInt32 = 10, whereFilter: String? = nil, ids: [String]? = nil, include: [String]? = nil) async throws -> QueryResult
public func createCollection(name: String) throws -> String
public var modelInfo: [String: Any] { get }
```

### Use `EmbeddingModel` cases

```swift
case bgeMicro
case gteTiny
case miniLML6
case miniLML12
case bgeSmall
case bgeBase
case bgeLarge
case mixedbreadLarge
```

Each case exposes:

- `rawValue`: Hugging Face model ID
- `displayName: String`
- `embeddingDimensions: Int`

### Expect these behaviour details

- `createCollection(name:)` is idempotent by name in current tests.
- `upsertDocuments(...)` inserts new IDs and updates existing IDs.
- `deleteDocuments(collectionName:ids: nil)` deletes all documents in the collection.
- `queryCollection(..., nResults: large)` returns only available matches.
- `include` controls optional return fields. Example: include `["embeddings"]` to receive embeddings from `getDocuments`.
- `decodedMetadatas()` converts metadata JSON strings to `[ChromaMetadata?]`.
- Use `countDocuments(collectionName:)` when you need an authoritative post-write document count.
- `FfiConverter*` and `uniffiEnsureChromaSwiftInitialized()` symbols are generated UniFFI scaffolding, not application-level API.

## Troubleshoot common issues

- **Symptom:** `Embedding model not loaded. Call loadModel() first.` **Cause:** `embed` or embedder query called before model load. **Fix:** call `try await embedder.loadModel()` once at startup.
- **Symptom:** `Metadata count (...) does not match ids count (...)`. **Cause:** metadata array length differs from IDs. **Fix:** pass one metadata entry per ID.
- **Symptom:** `Writing document metadata is not supported ...`. **Cause:** current binary does not support metadata writes. **Fix:** omit metadata on writes or pass only `nil` metadata placeholders.
- **Symptom:** query returns IDs but missing text. **Cause:** `documents` not requested in `include`. **Fix:** pass `include: ["documents"]`.
- **Symptom:** `reset()` fails. **Cause:** initialization may not allow reset. **Fix:** initialize with `allowReset: true` for environments where reset is required.

## Build and debug local framework changes

`ChromaSwift` normally downloads the published XCFramework from GitHub Releases.
When iterating on Rust bindings, point the package to a local framework instead of editing the manifest by hand.

1. Rebuild Swift bindings:

```bash
cd ../chroma/rust/swift_bindings
./build_swift_package.sh
```

This produces `Chroma/chroma_swift_framework.xcframework`.

2. Switch manifest to local framework:

```bash
./scripts/use_local_framework.sh
```

3. Build and run your app.
4. Switch back to release framework when ready:

```bash
./scripts/use_release_framework.sh <download-url> <checksum>
```

Pass the URL and checksum from the GitHub release asset.

## Publish a new XCFramework (manual)

1. Build the XCFramework as above. The artifact path is `chroma/rust/swift_bindings/Chroma/chroma_swift_framework.xcframework`.
2. Zip it for release:

```bash
cd chroma/rust/swift_bindings/Chroma
ditto -c -k --sequesterRsrc --keepParent chroma_swift_framework.xcframework chroma_swift_framework.xcframework.zip
```

3. Compute checksum from `chroma-swift/`:

```bash
swift package compute-checksum ../chroma/rust/swift_bindings/Chroma/chroma_swift_framework.xcframework.zip
```

4. Upload zip to GitHub Releases and update `Package.swift` with the new URL and checksum.
5. Or run:

```bash
./scripts/use_release_framework.sh <url> <checksum>
```

These steps keep local debugging and published builds separate without extra automation.

## Demo apps

See [`ChromaDemos/README.md`](ChromaDemos/README.md) for ephemeral, persistent, local-embeddings, and cloud-sync examples.

## License

ChromaSwift is available under the Apache License 2.0, same as the underlying Chroma library. See the [LICENSE](https://github.com/chroma-core/chroma-swift/blob/master/LICENSE) file for more info.

---

This package uses [cargo-swift](https://docs.rs/cargo-swift/latest/cargo_swift/) to generate Swift bindings and FFI code. The underlying FFI bindings are created with [UniFFI](https://mozilla.github.io/uniffi-rs/), enabling seamless interop between Swift and the Chroma core implemented in Rust.

*This package includes FFI bindings generated by UniFFI and links to a binary framework for the Chroma core. For advanced usage and troubleshooting, see the Chroma source code and documentation comments.*
