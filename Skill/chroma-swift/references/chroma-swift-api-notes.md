# Chroma Swift API Notes (Repo Source of Truth)

This file captures repository-specific behavior for `chroma-swift`.
Use it before making claims about API behavior.

## Package and Platform Facts

- Swift tools: 6.2
- Product name: `ChromaSwift`
- Module import: `Chroma`
- Platforms: iOS 17+, macOS 14+
- Local embeddings dependency: `mlx-swift-lm` (`MLXEmbedders`)

Source:

- `Package.swift`

## Core Chroma API Surface

Public top-level functions are generated in `Chroma/Sources/ChromaSwift.swift`, including:

- Initialization/system:
  - `initialize(allowReset:)`
  - `initializeWithPath(path:allowReset:)`
  - `reset()`
  - `getVersion()`
  - `getMaxBatchSize()`
  - `heartbeat()`
- Collections:
  - `createCollection(name:)`
  - `getCollection(collectionName:)`
  - `listCollections()`
  - `updateCollection(collectionName:newName:)`
  - `deleteCollection(collectionName:)`
  - `countCollections()`
- Documents:
  - `addDocuments(...)`
  - `getAllDocuments(collectionName:)`
  - `getDocuments(collectionName:ids:whereClause:limit:offset:whereDocument:include:)`
  - `updateDocuments(...)`
  - `upsertDocuments(...)`
  - `deleteDocuments(collectionName:ids:)`
  - `countDocuments(collectionName:)`
- Query:
  - `queryCollection(collectionName:queryEmbeddings:nResults:whereFilter:ids:include:)`
- Databases:
  - `createDatabase(name:)`
  - `getDatabase(name:)`
  - `listDatabases()`
  - `deleteDatabase(name:)`

## Result Types

- `CollectionInfo { name, collectionId, numDocuments }`
- `DatabaseInfo { id, name, tenant }`
- `GetResult { ids, documents }`
- `AdvancedGetResult { ids, embeddings?, documents?, metadatas?, uris? }`
- `QueryResult { ids, documents, distances? }`

Source:

- `Chroma/Sources/ChromaSwift.swift`

## Metadata Behavior in This Repo

- `ChromaMetadataValue` supports:
  - `.bool(Bool)`
  - `.int(Int64)`
  - `.float(Double)`
  - `.string(String)`
- `AdvancedGetResult.decodedMetadatas()` decodes JSON metadata strings into typed dictionaries.
- `addDocuments(..., metadatas:)` currently throws `metadataWriteUnsupported` if any metadata entry is non-`nil`.
- Count mismatch between IDs and metadata throws `countMismatch`.

Source:

- `Chroma/Sources/ChromaMetadata.swift`

## ChromaEmbedder Behavior

- Requires `loadModel()` before any `embed(...)` call.
- `EmbeddingModel` includes:
  - `bgeMicro`, `gteTiny`, `miniLML6`, `miniLML12`, `bgeSmall`, `bgeBase`, `bgeLarge`, `mixedbreadLarge`
- Internal batch embedding uses chunk size `32`.
- Single and batch embedding APIs are async and return normalized embeddings (see tests).
- Convenience extension:
  - `addDocuments(to:ids:texts:metadatas:)`
  - `queryCollection(...queryTexts...)`
  - `queryCollection(...queryText...)`
  - `createCollection(name:)`
  - `modelInfo`

Sources:

- `Chroma/Sources/ChromaEmbedder.swift`
- `Chroma/Sources/ChromaEmbedderExtensions.swift`

## Behavior Verified by Tests

- Database tests are serialized because `reset()` can interfere across tests.
- `createCollection(name:)` behaves idempotently by name.
- `upsertDocuments(...)` inserts or updates as expected.
- `deleteDocuments(collectionName: ids: nil)` is used as delete-all semantics.
- `include` controls optional return fields (`embeddings` vs `documents`).
- Query supports:
  - nearest-neighbor behavior
  - multiple results per query
  - batch queries
  - `nResults` larger than corpus size
- Concurrency tests validate:
  - concurrent collection creation
  - concurrent writes (distinct/same collection)
  - concurrent reads during writes
- `getCollection(collectionName:)` tests cover both existing and nonexistent collections.

Source:

- `Tests/ChromaTests/ChromaTests.swift`

## Practical Guardrails for Contributors

- Prefer `countDocuments` when authoritative post-write count is required.
- Avoid relying on metadata writes until upstream binary support lands.
- For collection inventory and counts, use:
  - `listCollections()`
  - `countDocuments(collectionName:)`
- Keep README/API docs in sync with generated public signatures.
