# BrainX V3

BrainX V3 is a lightweight **memory engine** built on **PostgreSQL + pgvector**, designed to act as a “shared brain” for multi-agent systems (e.g. OpenClaw).

It provides a small CLI for:

- **Writing** memories (decisions, actions, notes, learnings)
- **Retrieving** memories via vector similarity + metadata filters
- **Injecting** prompt-ready memory snippets into LLM conversations

This repository is an implementation of the **BrainX V3 — Upgrade Specification**.

---

## Table of contents

- [Concepts](#concepts)
- [Repository layout](#repository-layout)
- [Requirements](#requirements)
- [Quickstart](#quickstart)
- [Configuration](#configuration)
- [Database setup](#database-setup)
- [CLI reference (common tasks)](#cli-reference-common-tasks)
- [Scripts](#scripts)
- [Tests](#tests)
- [How retrieval ranking works](#how-retrieval-ranking-works)
- [Security notes](#security-notes)
- [Documentation (full)](#documentation-full)

---

## Concepts

### Memory item

A memory item is one row in `brainx_memories`:

- `type`: what kind of memory it is (decision/action/note/learning…)
- `content`: the text payload
- `context`: an optional scope key (exact-match)
- `tier`: hot/warm/cold/archive (used as a ranking prior)
- `importance`: 1..10 (used as a ranking prior)
- `tags`: free-form labels
- `embedding`: a vector representation used for semantic search

### “Inject” output

The `inject` command is meant to be copy/pasted directly into an LLM prompt (or programmatically inserted).
It outputs a compact block with a metadata header per item, then the content.

---

## Repository layout

- `brainx-v3` — small bash wrapper around the Node CLI
- `lib/cli.js` — implements `add`, `search`, `inject`
- `lib/openai-rag.js` — embeddings + Postgres vector search
- `lib/db.js` — PostgreSQL pool and helpers
- `sql/v3-schema.sql` — schema for memories + supporting tables
- `scripts/` — migration/import/cleanup utilities
- `tests/` — smoke + end-to-end RAG tests
- `docs/` — detailed documentation set

---

## Requirements

- Node.js **18+** (Node **22** recommended)
- PostgreSQL **14+** (15+ recommended)
- `pgvector` extension installed in your Postgres

---

## Quickstart

### 1) Install dependencies

```bash
pnpm install
# or
npm install
```

### 2) Create `.env`

```bash
cp .env.example .env
```

Edit `.env` (minimum required):

- `DATABASE_URL=...`
- `OPENAI_API_KEY=...`

### 3) Install schema (pgvector + tables)

1) Ensure `vector` extension exists:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

2) Apply schema:

```bash
psql "$DATABASE_URL" -f sql/v3-schema.sql
```

### 4) Run a health check

```bash
./brainx-v3 health
```

### 5) Add and retrieve a memory

```bash
./brainx-v3 add \
  --type decision \
  --content "Default model is openai-codex/gpt-5.3-codex" \
  --context openclaw \
  --tier hot \
  --importance 9 \
  --tags models,openclaw \
  --agent coder

./brainx-v3 search --query "default model" --limit 5 --minSimilarity 0.2
```

---

## Configuration

BrainX V3 is configured via environment variables.

### Required

- `DATABASE_URL`
- `OPENAI_API_KEY`

### Embeddings

- `OPENAI_EMBEDDING_MODEL` (default: `text-embedding-3-small`)
- `OPENAI_EMBEDDING_DIMENSIONS` (default: `1536`)

Important:

- `OPENAI_EMBEDDING_DIMENSIONS` must match the schema type: `vector(1536)`.
- If you change dimensions, you must update schema + re-embed existing rows.

### Shared env file (optional)

- `BRAINX_ENV=/path/to/shared.env`

`lib/db.js` and `lib/openai-rag.js` support loading environment from `BRAINX_ENV` if the main env vars are not present.
This is useful when multiple agents share one secrets file.

### Inject formatting (optional)

- `BRAINX_INJECT_DEFAULT_TIER` (default: `warm_or_hot`)
- `BRAINX_INJECT_MAX_CHARS_PER_ITEM` (default: `2000`)
- `BRAINX_INJECT_MAX_LINES_PER_ITEM` (default: `80`)

---

## Database setup

### pgvector

You need pgvector installed on your Postgres server.

- Many managed Postgres providers support it.
- On self-hosted Postgres, install your distro package (varies by OS), then:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

### Apply schema

```bash
psql "$DATABASE_URL" -f sql/v3-schema.sql
```

Tables created include:

- `brainx_memories` (main table)
- `brainx_learning_details`
- `brainx_trajectories`
- `brainx_context_packs`
- `brainx_session_snapshots`
- `brainx_pilot_log`

---

## CLI reference (common tasks)

### Help

```bash
./brainx-v3 --help
```

### Health check

```bash
./brainx-v3 health
```

### Add memory

```bash
./brainx-v3 add --type note --content "..." \
  --context "project-x" \
  --tier warm \
  --importance 5 \
  --tags a,b,c \
  --agent coder
```

Notes:

- If you omit `--id`, the CLI generates one.
- `add` is an **upsert** by id.

### Search (JSON output)

```bash
./brainx-v3 search --query "how do we deploy?" \
  --limit 10 \
  --minSimilarity 0.15 \
  --minImportance 3
```

Filter by exact context:

```bash
./brainx-v3 search --query "railway" --context emailbot
```

Filter by tier:

```bash
./brainx-v3 search --query "postgres" --tier hot
```

### Inject (prompt-ready output)

```bash
./brainx-v3 inject --query "what did we decide about models?" --limit 8
```

Inject output looks like:

```text
[sim:0.62 imp:9 tier:hot type:decision agent:coder ctx:openclaw]
Default model is openai-codex/gpt-5.3-codex

---

[sim:0.41 imp:6 tier:warm type:note agent:system ctx:emailbot]
Railway deploy pending confirmation...
```

---

## Scripts

These are one-shot utilities (see also `docs/SCRIPTS.md`).

- `scripts/migrate-v2-to-v3.js`
  - migrates BrainX V2 JSON storage into V3 Postgres.
- `scripts/import-workspace-memory-md.js`
  - imports a `MEMORY.md` file by chunking into multiple `note` memories.
- `scripts/dedup-supersede.js`
  - supersedes exact duplicates by fingerprint.
- `scripts/cleanup-low-signal.js`
  - downranks/retier very short “low signal” memories.

---

## Tests

Run smoke test:

```bash
pnpm test
# or
npm test
```

Run end-to-end RAG test:

```bash
node tests/rag.js
```

---

## How retrieval ranking works

`lib/openai-rag.js` ranks results with a simple composite score:

- **Semantic similarity** (cosine)
- **Importance boost**: `(importance/10) * 0.25`
- **Tier adjustment**:
  - `hot`: +0.15
  - `warm`: +0.05
  - `cold`: -0.05
  - `archive`: -0.10

Queries also:

- filter out superseded memories: `superseded_by IS NULL`
- update access tracking: `last_accessed` and `access_count`

---

## Security notes

- Do **not** commit `.env`.
- Treat `OPENAI_API_KEY` as a secret; prefer systemd/secret managers in production.
- If a key is accidentally exposed in logs/chat, rotate it.

---

## Documentation (full)

Start here: [`docs/INDEX.md`](./docs/INDEX.md)

- [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md)
- [`docs/SCHEMA.md`](./docs/SCHEMA.md)
- [`docs/CLI.md`](./docs/CLI.md)
- [`docs/SCRIPTS.md`](./docs/SCRIPTS.md)
- [`docs/TESTS.md`](./docs/TESTS.md)
- [`docs/CONFIG.md`](./docs/CONFIG.md)
