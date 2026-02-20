---
name: brainx-auto-inject
description: "Auto-inject BrainX V3 context on agent bootstrap"
homepage: https://github.com/Mdx2025/brainx-v3
metadata:
  {
    "openclaw":
      {
        "emoji": "🧠",
        "events": ["agent:bootstrap"],
        "requires": { "config": ["workspace.dir"], "env": ["DATABASE_URL", "OPENAI_API_KEY"] },
        "install": [{ "id": "bundled", "kind": "local", "label": "BrainX V3 Hook" }],
      },
  }
---

# BrainX V3 Auto-Inject Hook

Automatically retrieves relevant context from BrainX V3 memory system when an agent starts.

## What It Does

When an agent bootstraps (starts a new session):

1. **Queries BrainX** - Searches for recent hot/warm memories
2. **Injects context** - Adds relevant memories to the session context
3. **Updates context file** - Creates/updates `BRAINX_CONTEXT.md` in workspace

## Injected Context Format

The hook creates/updates `<workspace>/BRAINX_CONTEXT.md`:

```markdown
# 🧠 BrainX V3 Context (Auto-Injected)

Last updated: 2026-02-20 12:00:00 UTC
Agent: <agent_name>

## Recent Memories (hot + warm)

[sim:0.92 imp:9 tier:hot type:decision agent:coder]
Decision about API configuration...

---

[sim:0.85 imp:8 tier:warm type:learning]
Important lesson learned...
```

## Configuration

```json
{
  "hooks": {
    "internal": {
      "entries": {
        "brainx-auto-inject": {
          "enabled": true,
          "limit": 5,
          "tier": "hot+warm",
          "minImportance": 5
        }
      }
    }
  }
}
```

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | boolean | true | Enable/disable the hook |
| `limit` | number | 5 | Number of memories to inject |
| `tier` | string | "hot+warm" | Tier filter (hot, warm, cold, archive) |
| `minImportance` | number | 5 | Minimum importance (1-10) |

## Requirements

- `DATABASE_URL` - PostgreSQL connection string
- `OPENAI_API_KEY` - For embedding generation
- BrainX V3 tables must exist in database

## How It Works

1. Hook triggers on `agent:bootstrap` event
2. Executes `brainx inject` with configured parameters
3. Output is written to `BRAINX_CONTEXT.md`
4. File is automatically loaded into Project Context

## Manual Trigger

To manually refresh context:

```bash
cd ~/.openclaw/skills/brainx-v3
./brainx inject --tier hot+warm --limit 5 > BRAINX_CONTEXT.md
```
