-- BrainX V3 schema (initial)
-- Requires: CREATE EXTENSION vector;

CREATE TABLE IF NOT EXISTS brainx_memories (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL CHECK (type IN ('decision', 'action', 'learning', 'gotcha', 'note', 'feature_request')),
  content TEXT NOT NULL,
  context TEXT,
  tier TEXT DEFAULT 'warm' CHECK (tier IN ('hot', 'warm', 'cold', 'archive')),
  agent TEXT,
  importance INTEGER DEFAULT 5 CHECK (importance BETWEEN 1 AND 10),
  embedding vector(1536),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_accessed TIMESTAMPTZ DEFAULT NOW(),
  access_count INTEGER DEFAULT 0,
  source_session TEXT,
  superseded_by TEXT REFERENCES brainx_memories(id),
  tags TEXT[] DEFAULT '{}'
);

CREATE TABLE IF NOT EXISTS brainx_learning_details (
  memory_id TEXT PRIMARY KEY REFERENCES brainx_memories(id),
  category TEXT,
  what_was_wrong TEXT,
  what_is_correct TEXT,
  source TEXT,
  error_message TEXT,
  command_attempted TEXT,
  stack_trace TEXT,
  reproducible TEXT CHECK (reproducible IN ('yes', 'no', 'unknown')),
  suggested_fix TEXT,
  environment TEXT,
  related_files TEXT[],
  requested_capability TEXT,
  user_context TEXT,
  complexity TEXT CHECK (complexity IN ('simple', 'medium', 'complex')),
  suggested_implementation TEXT,
  frequency TEXT CHECK (frequency IN ('first_time', 'recurring')),
  promotion_status TEXT DEFAULT 'pending',
  promoted_to TEXT,
  promoted_at TIMESTAMPTZ,
  see_also TEXT[],
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS brainx_trajectories (
  id TEXT PRIMARY KEY,
  context TEXT,
  problem TEXT NOT NULL,
  steps JSONB,
  solution TEXT,
  outcome TEXT CHECK (outcome IN ('success', 'partial', 'failed')),
  agent TEXT,
  embedding vector(1536),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  times_used INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS brainx_context_packs (
  id TEXT PRIMARY KEY,
  data JSONB NOT NULL,
  embedding vector(1536),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS brainx_session_snapshots (
  id TEXT PRIMARY KEY,
  project TEXT NOT NULL,
  agent TEXT,
  summary TEXT NOT NULL,
  status TEXT CHECK (status IN ('in_progress', 'completed', 'blocked', 'paused')),
  pending_items JSONB DEFAULT '[]',
  blockers JSONB DEFAULT '[]',
  last_file_touched TEXT,
  last_error TEXT,
  key_urls JSONB DEFAULT '[]',
  embedding vector(1536),
  session_start TIMESTAMPTZ,
  session_end TIMESTAMPTZ DEFAULT NOW(),
  turn_count INTEGER
);

CREATE TABLE IF NOT EXISTS brainx_pilot_log (
  id SERIAL PRIMARY KEY,
  session_id TEXT,
  turn_number INTEGER,
  tokens_used INTEGER,
  capacity_percent REAL,
  memories_injected INTEGER,
  pack_injected TEXT,
  compressed BOOLEAN DEFAULT FALSE,
  recall_triggered BOOLEAN DEFAULT FALSE,
  recall_project TEXT,
  recall_confidence REAL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mem_embedding ON brainx_memories USING ivfflat (embedding vector_cosine_ops) WITH (lists = 20);
CREATE INDEX IF NOT EXISTS idx_mem_tier ON brainx_memories (tier, importance DESC);
CREATE INDEX IF NOT EXISTS idx_mem_context ON brainx_memories (context);
CREATE INDEX IF NOT EXISTS idx_mem_tags ON brainx_memories USING gin (tags);

CREATE INDEX IF NOT EXISTS idx_traj_embedding ON brainx_trajectories USING ivfflat (embedding vector_cosine_ops) WITH (lists = 10);
CREATE INDEX IF NOT EXISTS idx_pack_embedding ON brainx_context_packs USING ivfflat (embedding vector_cosine_ops) WITH (lists = 5);

CREATE INDEX IF NOT EXISTS idx_snapshots_project ON brainx_session_snapshots (project, session_end DESC);
CREATE INDEX IF NOT EXISTS idx_snapshots_embedding ON brainx_session_snapshots USING ivfflat (embedding vector_cosine_ops) WITH (lists = 10);
