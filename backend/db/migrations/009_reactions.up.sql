-- +migrate Up
-- Add public discovery columns to shared_notes
ALTER TABLE shared_notes ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE shared_notes ADD COLUMN IF NOT EXISTS reaction_heart INTEGER NOT NULL DEFAULT 0;
ALTER TABLE shared_notes ADD COLUMN IF NOT EXISTS reaction_bookmark INTEGER NOT NULL DEFAULT 0;

CREATE INDEX idx_shared_notes_public ON shared_notes(is_public, created_at DESC) WHERE is_public = TRUE;

-- Reactions table for tracking per-user reactions
CREATE TABLE note_reactions (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shared_note_id TEXT NOT NULL REFERENCES shared_notes(id) ON DELETE CASCADE,
    user_id      UUID REFERENCES users(id) ON DELETE CASCADE,
    reaction_type TEXT NOT NULL CHECK (reaction_type IN ('heart', 'bookmark')),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(shared_note_id, user_id, reaction_type)
);

CREATE INDEX idx_note_reactions_note ON note_reactions(shared_note_id);

-- +migrate Down
DROP TABLE IF EXISTS note_reactions;
ALTER TABLE shared_notes DROP COLUMN IF EXISTS is_public;
ALTER TABLE shared_notes DROP COLUMN IF EXISTS reaction_heart;
ALTER TABLE shared_notes DROP COLUMN IF EXISTS reaction_bookmark;
