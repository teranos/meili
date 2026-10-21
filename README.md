# qntx-meili

Search provider plugin for QNTX. Routes SearchService gRPC RPCs to a MeiliSearch instance.

## Configuration

The plugin is added, configured and enabled through its record on the node: [ADR-002](https://github.com/teranos/QNTX/blob/main/docs/adr/ADR-002-plugin-configuration.md). The keys below are the plugin's own, read from that record at initialize.

### Embedded mode

Spawns a MeiliSearch subprocess — no external instance needed. Data persists in `~/.qntx/meili-data/` across restarts.

```json
{"embedded": "true"}
```

`meili_bin` (default: `meilisearch` on `$PATH`) and `meili_db_path` (default: `~/.qntx/meili-data`) are read beside it.

Embedded uses `--master-key qntx-dev`, `--env development`, `--no-analytics`, `--max-indexing-memory 256MB`. The subprocess binds a random port and is killed on plugin shutdown.

Requires `meilisearch` binary on `$PATH` (e.g. `brew install meilisearch`).

### Remote mode

```json
{"url": "http://localhost:7700", "key": "your-master-key"}
```

Validates connectivity on initialize by listing indexes. A bad key surfaces immediately in logs.

## RPCs

- **Search** — full-text query against a named index, returns document JSON + hit count
- **IndexDocuments** — add/update documents (JSON bytes) to an index
- **DeleteDocuments** — remove documents by ID from an index
- **ConfigureIndex** — create index and set searchable/filterable/sortable attributes

## Build

QNTX's crates (`qntx-grpc`, `qntx-proto`) are a git dependency on [teranos/QNTX](https://github.com/teranos/QNTX) pinned to a tag in `Cargo.toml`; `Cargo.lock` holds the rev, and the flake reads it from there.

```
cargo build --release   # target/release/qntx-meili; needs protoc on PATH
make install            # build release, install to ~/.qntx/plugins/, hot-restart if running
nix build               # reproducible build via Nix flake
```

## Limitations

**Strikethrough = verified.** A limitation is only struck through after end-to-end testing confirms the fix works.

- **SPR** — Single provider. Core routes all search RPCs to one plugin. No multi-provider fanout or fallback chain.

- **NRS** — No relevance score. MeiliSearch doesn't expose scores by default. `SearchHit.score` is always 0.0.

- **PKI** — Primary key is `"id"`. Both `index_documents` and hit ID extraction assume documents have an `"id"` field. Documents without it get an empty string ID.

- **NFI** — No filter support. `req.filters` JSON bytes are accepted in the proto but not applied to MeiliSearch queries.

- **GRO** — gRPC only. No HTTP proxy endpoint or frontend integration. Search is only accessible through the core's gRPC service mesh.

- **MPG** — MeiliSearch Panel Glyph (ADR-015). No UI for browsing indexes, running queries, or managing documents.

- **NBF** — No bulk backfill. Only new attestations are indexed via the `SearchIndexObserver` write hook. Existing attestations created before meili was enabled are not in the index. A Pulse job for streaming backfill is the planned solution.
