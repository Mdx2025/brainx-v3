# BrainX V3

BrainX V3 is a **PostgreSQL + pgvector** memory engine intended to be used as the “shared brain” for multi-agent systems (e.g. OpenClaw).

This repository is an implementation of the **BrainX V3 — Upgrade Specification**.

## What this repo contains

- `brainx-v3` — small CLI wrapper script
- `lib/cli.js` — CLI commands (`add`, `search`, `inject`)
- `lib/openai-rag.js` — embeddings + vector search (OpenAI embeddings API)
- `lib/db.js` — PostgreSQL connection
- `sql/v3-schema.sql` — database schema (memories, learning details, trajectories, context packs, session snapshots)
- `scripts/` — migration and cleanup utilities
- `tests/` — smoke / RAG tests

## Documentation

See [`docs/INDEX.md`](./docs/INDEX.md).

## Requirements

- Node.js 18+ (Node 22 recommended)
- PostgreSQL 15+ (works with 14+, but 15+ recommended)
- `pgvector` extension installed in the target database

## Setup

### 1) Install dependencies

```bash
pnpm install
# or
npm install
```

### 2) Configure environment

Copy `.env.example` to `.env` and edit values:

```bash
cp .env.example .env
```

Required:

- `DATABASE_URL` — Postgres connection string
- `OPENAI_API_KEY` — used for embeddings

Optional:

- `OPENAI_EMBEDDING_MODEL` (default: `text-embedding-3-small`)
- `OPENAI_EMBEDDING_DIMENSIONS` (default: `1536`)
- `BRAINX_ENV` — path to a shared env file (so multiple agents can share one config)

### 3) Create database schema

Enable pgvector and create tables:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

Then run:

```bash
psql "$DATABASE_URL" -f sql/v3-schema.sql
```

## CLI usage

You can run the CLI via the wrapper:

```bash
./brainx-v3 --help
./brainx-v3 health
```

### Add memory

```bash
./brainx-v3 add \
  --type decision \
  --content "Default model is openai-codex/gpt-5.3-codex" \
  --context "openclaw" \
  --tier hot \
  --importance 9 \
  --tags models,openclaw \
  --agent coder
```

### Search

```bash
./brainx-v3 search --query "default model" --limit 5 --minSimilarity 0.2
```

### Inject (prompt-ready)

`inject` prints a compact, prompt-ready block with metadata headers per item.

```bash
./brainx-v3 inject --query "railway deploy" --limit 8
```

Useful env knobs:

- `BRAINX_INJECT_DEFAULT_TIER` (default: `warm_or_hot`)
- `BRAINX_INJECT_MAX_CHARS_PER_ITEM` (default: `2000`)
- `BRAINX_INJECT_MAX_LINES_PER_ITEM` (default: `80`)

## Scripts

- `scripts/migrate-v2-to-v3.js` — migration helper (WIP)
- `scripts/import-workspace-memory-md.js` — import from `MEMORY.md` style files
- `scripts/dedup-supersede.js` — supersede near-duplicates
- `scripts/cleanup-low-signal.js` — remove low-signal items

## Tests

```bash
pnpm test
# or
npm test
```

## Security notes

- **Do not commit `.env`** (this repo includes `.gitignore` for it).
- Prefer injecting secrets via your process manager/systemd environment.
- If you accidentally paste keys in chat/logs, rotate them.

## Status

This repo is functional for the core flow (store/search/inject) but still evolving.

Next planned steps typically include:

- additional memory types and “learning details” write-paths
- context pack builder
- session snapshot summarizer
- better migration tooling
