# Chroma Task Playbooks

Use these playbooks to execute common Chroma tasks with fewer mistakes.

## Playbook A: Design a New Collection

1. Define the retrieval job in one sentence.
2. Pick one embedding model and document why.
3. Choose distance space (`cosine`, `l2`, `ip`) intentionally.
4. Define metadata schema:
- key names
- value types
- expected filter operators
5. Choose ID strategy:
- UUID/ULID/hash/semantic key
6. Confirm ingestion write semantic:
- `add` for new-only
- `upsert` for idempotent pipelines
7. Record all choices in docs.

Done criteria:

- A new engineer can create and query the collection without guessing.

## Playbook B: Build an Ingestion Pipeline

1. Validate input:
- array lengths aligned (`ids`, `embeddings`, `documents`)
- dimension matches collection expectation
2. Determine batch size:
- check service limits
- in `chroma-swift`, use `getMaxBatchSize()` where applicable
3. Choose retry strategy:
- idempotent IDs + `upsert` for replay safety
4. Add observability:
- batch counts
- failed ID logs
- retry counts
5. Add post-write verification:
- `countDocuments`
- sample `getDocuments` check

Done criteria:

- Re-running the same batch does not duplicate logical records.

## Playbook C: Improve Retrieval Quality

1. Build a small benchmark set:
- query text
- expected top documents
2. Run baseline vector-only query.
3. Add metadata/document filters where domain constraints exist.
4. Tune `nResults` and compare recall/precision.
5. Inspect returned fields:
- include only what you need in production
- include extra fields while debugging
6. Re-check failure cases:
- ambiguous queries
- sparse metadata
- short documents

Done criteria:

- Benchmark quality improves with measured evidence.

## Playbook D: Productionize a Persistent Deployment

1. Set persistence path and backup policy.
2. Enable authentication and TLS.
3. Define tenant/database access boundaries.
4. Add WAL maintenance schedule.
5. Add index maintenance/defrag process for update-heavy workloads.
6. Write runbook steps for:
- restart
- restore
- rollback
7. Load test ingestion and query with realistic sizes.

Done criteria:

- Team can recover from common incidents without tribal knowledge.

## Playbook E: Implement Chroma in This Repo (`chroma-swift`)

1. Use public APIs in `Chroma/Sources/ChromaSwift.swift`.
2. If using local embeddings:
- create `ChromaEmbedder`
- call `loadModel()` before embedding
3. Handle metadata limitations:
- no non-`nil` metadata writes currently
- use `decodedMetadatas()` for reads
4. Prefer serialized test setup for DB-reset-heavy tests.
5. Add tests for:
- `include` behavior
- upsert/update/delete behavior
- concurrency path if changed
6. Update docs if public behavior changed.

Done criteria:

- Tests cover new behavior and docs remain accurate.

## Anti-Patterns to Avoid

- Mixing multiple embedding models in one collection.
- Using unstable IDs when idempotency is required.
- Returning large unused payloads by overusing `include`.
- Skipping auth/TLS on non-local deployments.
- Ignoring WAL/index maintenance in long-running persistent systems.
- Assuming wrapper metadata writes work without checking current binary support.
