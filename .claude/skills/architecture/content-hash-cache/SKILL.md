---
name: content-hash-cache
description: Deterministic caching with content hashes for long-term memory and expensive computations. Use when optimizing repeated operations.
argument-hint: "Cache expensive embeddings and multi-model consultation results"
department: architecture
thinking-level: medium
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
---

# Content Hash Cache Pattern

## When to Activate
- Expensive API calls (external LLM, rate-limited APIs)
- Embedding generation (vector computations)
- File analysis (AST parsing, static analysis, code review)
- Multi-model consultations (thinktank results)

## Hash Strategy

| Element | Implementation |
|---------|----------------|
| Algorithm | SHA-256 of input content |
| Cache Key | Full hash (64 chars) or prefix (8 chars + collision check) |
| TTL | Category-based: embeddings 30d, API 7d, analysis 90d |

## Cache Layers

| Layer | Storage | Speed | Scope |
|-------|---------|-------|-------|
| Memory | dict/Map | Fastest | Session only |
| File | `.claude/.cache/{prefix}/{hash}.json` | Fast | Cross-session |
| Persistent | Shared cache dir | Medium | Cross-project |

## Implementation

```
hash_key = sha256(input_content + model_version)
if cache[hash_key] exists and not expired → return cached
result = compute(input)
cache[hash_key] = {value: result, ts: now(), ttl: ttl, source: model}
```

**Eviction**: LRU for memory layer, TTL expiry + size limit for file layer.

## Integration

| Script | Cache Usage |
|--------|-------------|
| `knowledge-cache.sh` | Research results, summaries |
| `thinktank.sh` | Multi-model reasoning outputs |
| `embed-codebase.sh` | File vectors, similarity results |

## Best Practices
- Hash **inputs** not outputs — cache based on query, not response
- Include **model version** in hash for LLM calls — different models = different cache keys
- **TTL per category** — embeddings (30d) vs API responses (7d) vs analysis (90d)
- **Atomic writes** — write to temp then rename to avoid corruption
- **Same-directory temp** — avoid cross-filesystem mv (WSL/NTFS issue)
