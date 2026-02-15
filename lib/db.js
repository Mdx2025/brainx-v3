const { Pool } = require('pg');

// Support shared env file for all agents
if (!process.env.DATABASE_URL && process.env.BRAINX_ENV) {
  try {
    require('dotenv').config({ path: process.env.BRAINX_ENV });
  } catch (_) {}
}

const DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL) {
  throw new Error('DATABASE_URL is required');
}

const pool = new Pool({ connectionString: DATABASE_URL });

async function query(text, params) {
  return pool.query(text, params);
}

async function health() {
  const r = await query('select 1 as ok');
  return r.rows?.[0]?.ok === 1;
}

module.exports = { pool, query, health };
