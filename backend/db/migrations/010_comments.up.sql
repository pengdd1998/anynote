-- +migrate Up
CREATE TABLE note_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shared_note_id VARCHAR(26) NOT NULL REFERENCES shared_notes(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    encrypted_content TEXT NOT NULL,
    parent_id UUID REFERENCES note_comments(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_comments_shared_note ON note_comments(shared_note_id, created_at ASC) WHERE deleted_at IS NULL;
CREATE INDEX idx_comments_user ON note_comments(user_id) WHERE deleted_at IS NULL;

-- +migrate Down
DROP TABLE IF EXISTS note_comments;
