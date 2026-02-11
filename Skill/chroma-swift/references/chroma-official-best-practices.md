# Chroma Official Best Practices

This file distills official Chroma guidance into actionable engineering rules.
Use these notes for design and implementation decisions.

Last reviewed: 2026-02-11.

## 1) Collection and Embedding Strategy

- Keep one embedding model per collection.
- Keep vector dimensionality stable inside a collection.
- Choose distance space intentionally at collection creation (`hnsw:space`), usually:
  - `cosine` for normalized sentence embeddings
  - `l2` or `ip` when your model/workflow requires it

Why:

- Mixed embedding spaces degrade nearest-neighbor quality.
- Metric mismatch causes surprising ranking behavior.

Sources:

- [Collections data model](https://docs.trychroma.com/docs/collections/collections)
- [Collection properties and HNSW settings](https://cookbook.chromadb.dev/core/collections/)
- [Embedding Functions](https://docs.trychroma.com/docs/embeddings/embedding-functions)

## 2) IDs and Idempotency

- Use deterministic IDs if you need idempotent ingestion.
- Prefer ULID/UUID/hash-based IDs over positional IDs.
- Treat ID strategy as part of your data contract.

Why:

- Stable IDs prevent duplicate logical records across retries/replays.
- Query ordering and internal storage behavior become easier to reason about.

Sources:

- [Document IDs guidance](https://cookbook.chromadb.dev/core/document-ids/)
- [Add data (duplicate ID behavior)](https://docs.trychroma.com/docs/collections/add-data)

## 3) Metadata and Filtering

- Keep metadata schema typed and intentional.
- Use metadata filters (`where`) for structured narrowing.
- Use document filters (`where_document`) for text-contains narrowing.
- Combine vector similarity + filters for precision and cost control.

Why:

- Filter-first narrowing reduces irrelevant candidates before ranking.
- Metadata shape drift leads to brittle filters and poor explainability.

Sources:

- [Metadata filtering](https://docs.trychroma.com/docs/querying-collections/metadata-filtering)
- [Document filtering](https://docs.trychroma.com/docs/querying-collections/full-text-search)

## 4) Query Payload Discipline

- Ask for only what you need via `include`.
- Keep response payload minimal in latency-sensitive paths.
- Increase payload only for debugging or UI views that need extra fields.

Why:

- Smaller payloads reduce serialization cost and network overhead.
- Excess fields complicate clients and increase memory usage.

Sources:

- [Query and get collection data](https://docs.trychroma.com/docs/querying-collections/query-and-get)

## 5) Write Path Strategy

- Use `add` for strictly new records.
- Use `upsert` for idempotent pipelines and retryable writes.
- Use `update` when record existence is guaranteed and semantics are explicit.
- Respect max batch size limits in your client and ingestion jobs.

Why:

- Correct write semantic choice avoids accidental duplicates or silent misses.
- Batch sizing improves reliability and throughput.

Sources:

- [Add data](https://docs.trychroma.com/docs/collections/add-data)
- [Update data](https://docs.trychroma.com/docs/collections/update-data)
- [Chroma API reference](https://docs.trychroma.com/reference/chroma-reference)

## 6) Operations and Maintenance

- Plan for WAL growth in persistent deployments.
- Add routine WAL pruning/compaction operations.
- Defragment or rebuild indexes for update-heavy workloads.
- Keep backups and restore drills for persistent state.

Why:

- Long-running systems accumulate write amplification and fragmentation.
- Maintenance keeps latency and storage growth predictable.

Sources:

- [Write-ahead Log (WAL)](https://cookbook.chromadb.dev/core/write-ahead-log-wal/)
- [WAL Pruning](https://cookbook.chromadb.dev/core/write-ahead-log-wal-pruning/)
- [Performance tips](https://cookbook.chromadb.dev/running/performance-tips/)
- [Backups](https://cookbook.chromadb.dev/strategies/backups/)

## 7) Security and Tenancy

- Enable auth in any non-local deployment.
- Require TLS for traffic that leaves localhost/trusted boundaries.
- Treat tenant and database boundaries as explicit access boundaries.
- Do not store secrets in source code.

Why:

- Chroma may hold sensitive application context and user data.
- Auth/TLS is table stakes for production risk control.

Sources:

- [Authentication in Chroma v1.0.x](https://cookbook.chromadb.dev/security/authentication-in-chroma-v1.0.x/)
- [SSL/TLS Certificates in Chroma](https://cookbook.chromadb.dev/security/ssl-tls-certificates-in-chroma/)
- [Tenants and Databases](https://cookbook.chromadb.dev/core/tenants-and-databases/)

## 8) Migration and Versioning

- Treat upgrades as planned migrations.
- Pin tested versions in production.
- Validate migration steps on a staging copy before production rollout.

Sources:

- [Migration guide](https://docs.trychroma.com/docs/overview/migration)
- [chroma-core/chroma repository](https://github.com/chroma-core/chroma)
