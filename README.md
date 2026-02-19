# BrainX V3

BrainX V3 is a **PostgreSQL + pgvector** based memory engine for multi-agent systems ([OpenClaw](https://github.com/openclaw/openclaw)).

## Status

✅ **Production Ready** — Active across all agents with shared centralized memory.

## Features

- 🧠 **Semantic search** via OpenAI embeddings (text-embedding-3-small)
- 🗃️ **PostgreSQL + pgvector** for persistent vector storage
- 🔍 **On-demand injection** — only fetch context when relevant
- 🤖 **Multi-agent support** — all agents read/write the same database
- 📊 **Tiered memory** — hot, warm, cold, archive with importance scoring
- 🏷️ **Metadata filtering** — by context, tier, tags, agent, importance

## Architecture

```
Agent A ──┐                    ┌── brainx search
Agent B ──┤── brainx CLI ──── │── brainx add
Agent C ──┤    (Node.js)       │── brainx inject
Agent D ──┘        │           └── brainx health
                   ▼
          PostgreSQL + pgvector
          (centralized memory)
```

- **Storage**: PostgreSQL with pgvector extension
- **Embeddings**: OpenAI text-embedding-3-small (1536 dimensions)
- **Search**: Cosine similarity + metadata filtering
- **Injection**: On-demand (not automatic) — avoids token waste

## Philosophy: On-Demand Injection

Unlike V2 (automatic on every request), **V3 uses manual injection**:

- ✅ Call `inject` **only when relevant**
- ✅ Avoid token waste
- ✅ More specific queries = better results

## Installation

```bash
# 1. Clone
git clone https://github.com/Mdx2025/brainx-v3.git
cd brainx-v3

# 2. Install dependencies
pnpm install  # or npm install

# 3. Configure environment
cp .env.example .env
# Edit: DATABASE_URL, OPENAI_API_KEY

# 4. Setup database (requires PostgreSQL with pgvector)
psql "$DATABASE_URL" -f sql/v3-schema.sql

# 5. Verify
./brainx-v3 health
```

### OpenClaw Integration

BrainX V3 works as a native **OpenClaw skill**:

```bash
# Install as skill
cp -r brainx-v3 ~/.openclaw/skills/brainx-v3

# Add to PATH in openclaw.json
# "env": { "PATH": "/home/clawd/.openclaw/skills/brainx-v3:$PATH" }

# Add DATABASE_URL to openclaw.json env
# "DATABASE_URL": "postgresql://brainx:pass@127.0.0.1:5432/brainx_v3"

# Now all agents can use: brainx search, brainx add, brainx inject
```

The `SKILL.md` file provides OpenClaw with tool definitions (`brainx_add_memory`, `brainx_search`, `brainx_inject`, `brainx_health`).

## CLI Reference

### Health Check
```bash
./brainx-v3 health
# BrainX V3 health: OK
# - pgvector: yes
# - brainx tables: 6
```

### Add Memory
```bash
./brainx-v3 add --type decision \
  --content "Use embeddings-3-small to reduce costs" \
  --context "openclaw" \
  --tier hot \
  --importance 9 \
  --tags config,openai \
  --agent coder
```

**Types:** `decision`, `action`, `note`, `learning`, `gotcha`
**Tiers:** `hot`, `warm`, `cold`, `archive`

### Search Memories
```bash
./brainx-v3 search --query "deployment strategy" \
  --limit 10 \
  --minSimilarity 0.15 \
  --context project-x \
  --tier hot
```

### Inject Context (Prompt-Ready)
```bash
./brainx-v3 inject --query "what did we decide?" --limit 8
```

Output format (ready to paste into LLM prompts):
```
[sim:0.82 imp:9 tier:hot type:decision agent:coder ctx:openclaw]
Use embeddings-3-small to reduce costs...

---

[sim:0.41 imp:6 tier:warm type:note agent:writer ctx:project-x]
Another memory...
```

## Injection Limits

To prevent prompt bloat:

| Limit | Default | Env Override | Flag Override |
|-------|---------|--------------|---------------|
| Max chars per item | 2000 | `BRAINX_INJECT_MAX_CHARS_PER_ITEM` | `--maxCharsPerItem` |
| Max lines per item | 80 | `BRAINX_INJECT_MAX_LINES_PER_ITEM` | `--maxLinesPerItem` |

## When to Use

✅ **DO use when:**
- User references past decisions
- Resuming long-running tasks
- "What did we decide about X?"
- Need context from previous work
- Sharing knowledge between agents

❌ **DON'T use when:**
- Simple isolated questions
- General knowledge queries
- Code review without context needs
- Every message "just in case"

## Repository Layout

```
brainx-v3/
├── brainx-v3              # CLI entry point (bash)
├── brainx                 # Wrapper for PATH usage
├── SKILL.md               # OpenClaw skill definition
├── lib/
│   ├── cli.js             # Command implementations
│   ├── openai-rag.js      # Embeddings + vector search
│   └── db.js              # PostgreSQL connection pool
├── sql/
│   └── v3-schema.sql      # Database schema (6 tables)
├── scripts/               # Migration utilities
├── docs/                  # Architecture documentation
└── tests/                 # Test suite
```

## Database Schema

6 tables:

| Table | Purpose |
|-------|---------|
| `brainx_memories` | Main memory store with embeddings |
| `brainx_learning_details` | Extended learning metadata |
| `brainx_trajectories` | Agent action trajectories |
| `brainx_context_packs` | Bundled context snapshots |
| `brainx_session_snapshots` | Session summaries |
| `brainx_pilot_log` | Audit/pilot log |

## Environment Variables

```bash
# Required
DATABASE_URL=postgresql://user:pass@host:5432/brainx_v3
OPENAI_API_KEY=sk-...

# Optional
OPENAI_EMBEDDING_MODEL=text-embedding-3-small       # default
OPENAI_EMBEDDING_DIMENSIONS=1536                     # default
BRAINX_INJECT_MAX_CHARS_PER_ITEM=2000
BRAINX_INJECT_MAX_LINES_PER_ITEM=80
BRAINX_INJECT_DEFAULT_TIER=warm_or_hot
```

## Upgrading from V2

```bash
node scripts/migrate-v2-to-v3.js
```

## License

MIT
