#!/usr/bin/env node

require('dotenv/config');

const db = require('../lib/db');

async function main() {
  const maxLen = parseInt(process.env.CLEANUP_MAX_LEN || '12', 10);
  const newTier = process.env.CLEANUP_TIER || 'cold';
  const maxImportance = parseInt(process.env.CLEANUP_MAX_IMPORTANCE || '2', 10);

  const res = await db.query(
    `
    UPDATE brainx_memories
    SET tier = $1,
        importance = LEAST(importance, $2),
        tags = CASE
          WHEN NOT (tags @> ARRAY['low_signal']) THEN tags || ARRAY['low_signal']
          ELSE tags
        END
    WHERE superseded_by IS NULL
      AND length(coalesce(content,'')) <= $3
      AND type IN ('decision','action','learning','note')
    `,
    [newTier, maxImportance, maxLen]
  );

  console.log(
    JSON.stringify(
      { ok: true, updated: res.rowCount, maxLen, newTier, maxImportance },
      null,
      2
    )
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
