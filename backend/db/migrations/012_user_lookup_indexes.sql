-- +migrate Up
-- Indexes for user-scoped lookups on tables that previously only had
-- composite or PK indexes. These support common queries in the handler
-- and service layers.

-- Sync blob pull-by-user (without type filter).
CREATE INDEX IF NOT EXISTS idx_sync_blobs_user_id ON sync_blobs(user_id);

-- User reaction lookup (list reactions for a user's notes).
CREATE INDEX IF NOT EXISTS idx_reactions_user_id ON note_reactions(user_id);

-- +migrate Down
DROP INDEX IF EXISTS idx_sync_blobs_user_id;
DROP INDEX IF EXISTS idx_reactions_user_id;
