# CLI Reference (brainx-v3)

Entry point: `./brainx-v3`

Internally it delegates to `lib/cli.js`.

## Global help

```bash
./brainx-v3 --help
```

## `health`

Runs a database smoke test:

```bash
./brainx-v3 health
```

Checks:

- DB connectivity (`select 1`)
- pgvector installed
- `brainx_*` tables exist

## `add`

Store (upsert) a memory item.

```bash
./brainx-v3 add \
  --type <type> \
  --content <text> \
  [--context <ctx>] \
  [--tier <hot|warm|cold|archive>] \
  [--importance <1-10>] \
  [--tags a,b,c] \
  [--agent <name>] \
  [--id <id>]
```

Notes:

- If `--id` is omitted, an id like `m_<timestamp>_<rand>` is generated.
- Embedding input is built as:
  - `${type}: ${content} [context: ${context}]`

## `search`

Semantic search returning JSON.

```bash
./brainx-v3 search \
  --query <text> \
  [--limit <n>] \
  [--minSimilarity <0-1>] \
  [--context <ctx>] \
  [--tier <tier>] \
  [--minImportance <n>]
```

Returned fields include:

- all table columns
- `similarity`
- `score`

## `inject`

Semantic search formatted as a prompt-ready block (plain text).

```bash
./brainx-v3 inject \
  --query <text> \
  [--limit <n>] \
  [--context <ctx>] \
  [--tier <tier>] \
  [--minImportance <n>] \
  [--maxCharsPerItem <n>] \
  [--maxLinesPerItem <n>]
```

Defaults:

- `BRAINX_INJECT_DEFAULT_TIER=warm_or_hot`
  - if you don’t pass `--tier`, inject searches hot then warm and merges unique ids.

Output format:

```
[sim:0.62 imp:9 tier:hot type:decision agent:coder ctx:openclaw]
<content>

---

[sim:0.41 imp:6 tier:warm type:note agent:system ctx:emailbot]
<content>
```

## Environment variables

Required:

- `DATABASE_URL`
- `OPENAI_API_KEY`

Optional:

- `BRAINX_ENV` — load a shared env file from a specific path
- `OPENAI_EMBEDDING_MODEL`
- `OPENAI_EMBEDDING_DIMENSIONS`
- `BRAINX_INJECT_DEFAULT_TIER`
- `BRAINX_INJECT_MAX_CHARS_PER_ITEM`
- `BRAINX_INJECT_MAX_LINES_PER_ITEM`

## Exit codes

- `0` on success
- `1` on error (prints message to stderr)
