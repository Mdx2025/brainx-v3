require('dotenv/config');

const crypto = require('crypto');
const rag = require('./openai-rag');

function usage() {
  console.log(`brainx-v3

Commands:
  health
  add --type <type> --content <text> [--context <ctx>] [--tier <hot|warm|cold|archive>] [--importance <1-10>] [--tags a,b,c] [--agent <name>] [--id <id>]
  search --query <text> [--limit <n>] [--minSimilarity <0-1>] [--context <ctx>] [--tier <tier>] [--minImportance <n>]
  inject --query <text> [--limit <n>] [--context <ctx>] [--tier <tier>] [--minImportance <n>]

Environment:
  DATABASE_URL, OPENAI_API_KEY
`);
}

function parseArgs(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const k = a.slice(2);
      const v = argv[i + 1];
      if (!v || v.startsWith('--')) out[k] = true;
      else {
        out[k] = v;
        i++;
      }
    } else {
      out._.push(a);
    }
  }
  return out;
}

function makeId() {
  return `m_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;
}

async function cmdAdd(args) {
  const type = args.type || 'note';
  const content = args.content;
  if (!content) throw new Error('--content is required');

  const memory = {
    id: args.id || makeId(),
    type,
    content,
    context: args.context || null,
    tier: args.tier || 'warm',
    importance: args.importance ? parseInt(args.importance, 10) : 5,
    agent: args.agent || process.env.OPENCLAW_AGENT || null,
    tags: args.tags ? String(args.tags).split(',').map(s => s.trim()).filter(Boolean) : []
  };

  await rag.storeMemory(memory);
  console.log(JSON.stringify({ ok: true, id: memory.id }));
}

async function cmdSearch(args) {
  const query = args.query;
  if (!query) throw new Error('--query is required');

  const limit = args.limit ? parseInt(args.limit, 10) : 10;
  const minSimilarity = args.minSimilarity ? parseFloat(args.minSimilarity) : 0.3;
  const minImportance = args.minImportance ? parseInt(args.minImportance, 10) : 0;

  const rows = await rag.search(query, {
    limit,
    minSimilarity,
    minImportance,
    tierFilter: args.tier || null,
    contextFilter: args.context || null
  });

  console.log(JSON.stringify({ ok: true, results: rows }, null, 2));
}

function formatInject(rows) {
  const lines = [];
  for (const r of rows) {
    const meta = `[sim:${(r.similarity ?? 0).toFixed(2)} imp:${r.importance} tier:${r.tier} type:${r.type} agent:${r.agent || ''} ctx:${r.context || ''}]`;
    lines.push(`${meta}\n${String(r.content).trim()}`);
  }
  return lines.join('\n\n---\n\n');
}

async function cmdInject(args) {
  const query = args.query;
  if (!query) throw new Error('--query is required');

  const limit = args.limit ? parseInt(args.limit, 10) : 10;
  const minImportance = args.minImportance ? parseInt(args.minImportance, 10) : 0;

  // Default: avoid cold/archive noise unless user explicitly asks.
  // If --tier is provided, we honor it.
  const defaultTier = process.env.BRAINX_INJECT_DEFAULT_TIER || 'warm_or_hot';

  let tierFilter = args.tier || null;
  let rows;

  if (tierFilter) {
    rows = await rag.search(query, {
      limit,
      minSimilarity: 0.15,
      minImportance,
      tierFilter,
      contextFilter: args.context || null
    });
  } else if (defaultTier === 'warm_or_hot') {
    const hot = await rag.search(query, {
      limit,
      minSimilarity: 0.15,
      minImportance,
      tierFilter: 'hot',
      contextFilter: args.context || null
    });
    const warm = await rag.search(query, {
      limit,
      minSimilarity: 0.15,
      minImportance,
      tierFilter: 'warm',
      contextFilter: args.context || null
    });
    // merge unique by id, preserve order
    const seen = new Set();
    rows = [];
    for (const r of [...hot, ...warm]) {
      if (seen.has(r.id)) continue;
      seen.add(r.id);
      rows.push(r);
      if (rows.length >= limit) break;
    }
  } else {
    rows = await rag.search(query, {
      limit,
      minSimilarity: 0.15,
      minImportance,
      tierFilter: null,
      contextFilter: args.context || null
    });
  }

  process.stdout.write(formatInject(rows));
}

async function main() {
  const argv = process.argv.slice(2);
  const cmd = argv[0];
  const args = parseArgs(argv.slice(1));

  if (!cmd || cmd === '--help' || cmd === '-h') {
    usage();
    process.exit(0);
  }

  if (cmd === 'add') return cmdAdd(args);
  if (cmd === 'search') return cmdSearch(args);
  if (cmd === 'inject') return cmdInject(args);

  throw new Error(`Unknown command: ${cmd}`);
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
