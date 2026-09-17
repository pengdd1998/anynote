-- +migrate Up
-- Phase 132: semantic search over the user's shared/published notes.
--
-- Privacy model: note text never reaches the server. The CLIENT computes an
-- embedding with its own LLM provider and uploads only the vector, and only
-- for notes the user has chosen to index (shared or published content).
-- The server can therefore run vector similarity but never reconstruct text.

CREATE EXTENSION IF NOT EXISTS vector;

-- No vector(N) typmod on purpose: the embedding dimension follows the user's
-- own provider (GLM / OpenAI / Ollama all differ). Queries must filter on
-- dim = query dim. At per-user scale a sequential scan is the right trade;
-- add ivfflat/hnsw (which require a fixed dimension) only if this table
-- ever outgrows it.
CREATE TABLE note_embeddings (
    id          BIGSERIAL PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    note_id     UUID NOT NULL,
    lang        TEXT NOT NULL DEFAULT '',
    dim         INTEGER NOT NULL,
    embedding   VECTOR NOT NULL,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, note_id)
);

CREATE INDEX idx_note_embeddings_user ON note_embeddings(user_id);

-- +migrate Down
DROP TABLE IF EXISTS note_embeddings;
DROP EXTENSION IF EXISTS vector;
