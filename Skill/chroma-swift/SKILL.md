---
name: chroma
description: Comprehensive Chroma skill for designing, implementing, debugging, and operating Chroma-based retrieval systems. Covers collection design, embeddings, filters, ingestion/query workflows, performance, security, and repo-specific guidance for chroma-swift.
---

# Chroma Expert Skill

## Overview

Use this skill when working on Chroma architecture, Chroma APIs, Chroma retrieval quality, or operational concerns.
It is optimized for this repository (`chroma-swift`) and also includes upstream Chroma best practices.

Primary goals:

- Build correct, repeatable ingestion and retrieval workflows.
- Keep collection design and embedding strategy coherent.
- Improve retrieval quality before adding complexity.
- Prevent common operational failures (WAL growth, fragmentation, missing auth/TLS).

## When to Use

Activate this skill when the task includes any of the following:

- Chroma collections, vectors, metadata, filtering, or similarity query design
- ingestion/upsert/update/delete workflow design
- embedding model selection and dimension planning
- retrieval debugging and relevance tuning
- Chroma performance tuning and maintenance
- Chroma auth, TLS, tenancy, or production hardening
- implementing or reviewing `chroma-swift` usage

## Source of Truth Order

1. Local repository source and tests
2. Official Chroma docs (`docs.trychroma.com`)
3. Official Chroma Cookbook (`cookbook.chromadb.dev`)
4. Upstream Chroma repository docs/issues when needed

If sources conflict, prefer local code behavior for this repo.

## Workflow Decision Tree

1. Identify runtime mode:
- Ephemeral / in-memory
- Persistent local storage
- Remote/server or cloud deployment

2. Identify problem type:
- Data modeling
- Ingestion correctness
- Retrieval quality
- Performance/operations
- Security/multi-tenancy

3. Apply the matching playbook:
- Use `references/chroma-task-playbooks.md`

4. Validate using checklists:
- Design checklist
- Query/relevance checklist
- Production checklist

## Core Principles

- Keep one embedding model and one vector dimension per collection.
- Use deterministic IDs when idempotency matters.
- Keep metadata schema intentional and stable.
- Use metadata/document filters to narrow scope before ranking.
- Request only needed fields in `include` to reduce payload and overhead.
- Treat maintenance (WAL pruning, index defrag) as routine operations.
- Never deploy public endpoints without authentication and TLS.

## Design Checklist

- Collection purpose is single-purpose and explicit.
- Embedding model choice is documented.
- Embedding dimensions are verified end-to-end.
- ID strategy is chosen (UUID/ULID/hash/semantic key) and justified.
- Metadata keys, value types, and filter intent are documented.
- Distance metric (`l2`, `cosine`, `ip`) is selected intentionally.

## Ingestion Checklist

- Input arrays are length-aligned (`ids`, `documents`, `embeddings`).
- Batch size respects runtime limits.
- Upsert vs add semantics are chosen deliberately.
- Duplicate/failed writes are handled idempotently.
- Backfills/re-ingests have versioning strategy for embeddings/model changes.

## Query and Relevance Checklist

- Start with simplest working query, then add filters.
- Restrict candidate space with metadata/document filters when possible.
- Verify `nResults` and fallback behavior when corpus is small.
- Ask only for fields you need in `include`.
- Evaluate with a small benchmark set of known-good query/answer pairs.

## Production Checklist

- Persistence path and backup strategy are set.
- WAL pruning is scheduled and tested.
- Index defragmentation process exists for update-heavy collections.
- Auth and TLS are enforced for any external access.
- Migration policy and rollback plan are documented.
- Observability (logs/traces/health checks) is present.

## Repository-Specific Guidance (chroma-swift)

Use these facts as hard constraints for code in this repo:

- Public API surface comes from `Chroma/Sources/ChromaSwift.swift`.
- Metadata writes are currently restricted:
  - `Chroma.addDocuments(..., metadatas: ...)` throws if any metadata entry is non-nil.
  - See `ChromaMetadataError.metadataWriteUnsupported`.
- `AdvancedGetResult.decodedMetadatas()` is the intended decode helper for metadata JSON strings.
- `ChromaEmbedder` requires `loadModel()` before `embed(...)` calls.
- `ChromaEmbedder` batches internally in chunks of 32 texts.
- Tests indicate `createCollection(name:)` is idempotent by name.
- Tests cover `getCollection(collectionName:)` for existing and nonexistent collections.

Full repo notes: `references/chroma-swift-api-notes.md`.

## Execution Guidance for Agents

When implementing changes:

1. Confirm mode (ephemeral/persistent/remote).
2. Confirm embedding strategy and collection schema.
3. Implement smallest correct path first.
4. Add tests for:
- idempotency
- filter behavior
- include-field behavior
- concurrency behavior when relevant
5. Document assumptions and operational impacts.

When reviewing code:

- Prioritize correctness and retrieval behavior regressions.
- Flag schema drift and embedding/model mismatch risks.
- Flag missing security controls on networked deployments.
- Flag missing maintenance procedures for persistent deployments.

## References in This Skill

- Official best practices: `references/chroma-official-best-practices.md`
- Repo-specific API and constraints: `references/chroma-swift-api-notes.md`
- Task playbooks and checklists: `references/chroma-task-playbooks.md`
- Source index: `references/source-index.md`
