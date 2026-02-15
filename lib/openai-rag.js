const db = require('./db');

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const EMBEDDING_MODEL = process.env.OPENAI_EMBEDDING_MODEL || 'text-embedding-3-small';
const EMBEDDING_DIMENSIONS = parseInt(process.env.OPENAI_EMBEDDING_DIMENSIONS || '1536', 10);

if (!OPENAI_API_KEY) {
  throw new Error('OPENAI_API_KEY is required');
}

async function embed(text) {
  const res = await fetch('https://api.openai.com/v1/embeddings', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: EMBEDDING_MODEL,
      input: text,
      dimensions: EMBEDDING_DIMENSIONS
    })
  });

  if (!res.ok) {
    const msg = await res.text();
    throw new Error(`OpenAI embeddings failed: ${res.status} ${msg}`);
  }

  const data = await res.json();
  const vec = data?.data?.[0]?.embedding;
  if (!Array.isArray(vec)) throw new Error('Invalid embedding response');
  return vec;
}

async function storeMemory(memory) {
  const embedding = await embed(`${memory.type}: ${memory.content} [context: ${memory.context || ''}]`);

  await db.query(
    `INSERT INTO brainx_memories (id, type, content, context, tier, agent, importance, embedding, tags)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8::vector,$9)
     ON CONFLICT (id) DO UPDATE SET
       type=EXCLUDED.type,
       content=EXCLUDED.content,
       context=EXCLUDED.context,
       tier=EXCLUDED.tier,
       agent=EXCLUDED.agent,
       importance=EXCLUDED.importance,
       embedding=EXCLUDED.embedding,
       tags=EXCLUDED.tags`,
    [
      memory.id,
      memory.type,
      memory.content,
      memory.context || null,
      memory.tier || 'warm',
      memory.agent || null,
      memory.importance ?? 5,
      JSON.stringify(embedding),
      memory.tags || []
    ]
  );
}

async function search(query, options = {}) {
  const {
    limit = 10,
    minImportance = 0,
    tierFilter = null,
    contextFilter = null,
    minSimilarity = 0.3
  } = options;

  const queryEmbedding = await embed(query);

  let sql = `
    SELECT *,
      1 - (embedding <=> $1::vector) AS similarity
    FROM brainx_memories
    WHERE importance >= $2
      AND superseded_by IS NULL
  `;

  const params = [JSON.stringify(queryEmbedding), minImportance];
  let i = 3;

  if (tierFilter) {
    sql += ` AND tier = $${i}`;
    params.push(tierFilter);
    i++;
  }
  if (contextFilter) {
    sql += ` AND context = $${i}`;
    params.push(contextFilter);
    i++;
  }

  sql += `
    ORDER BY similarity DESC
    LIMIT $${i}
  `;
  params.push(limit);

  const results = await db.query(sql, params);

  // access tracking
  const ids = results.rows.map(r => r.id);
  if (ids.length) {
    await db.query(
      `UPDATE brainx_memories
       SET last_accessed = NOW(), access_count = access_count + 1
       WHERE id = ANY($1)`,
      [ids]
    );
  }

  return results.rows.filter(r => (r.similarity ?? 0) >= minSimilarity);
}

module.exports = { embed, storeMemory, search };
