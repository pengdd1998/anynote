-- +migrate Up
CREATE TABLE shared_notes (
    id                TEXT PRIMARY KEY,
    encrypted_content TEXT NOT NULL,
    encrypted_title   TEXT NOT NULL,
    share_key_hash    TEXT NOT NULL,          -- hash of the decryption key (for optional password verification)
    has_password      BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at        TIMESTAMPTZ,
    view_count        INTEGER NOT NULL DEFAULT 0,
    max_views         INTEGER,
    created_by        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_shared_notes_created_by ON shared_notes(created_by);
CREATE INDEX idx_shared_notes_expires_at ON shared_notes(expires_at);

-- +migrate Down
DROP TABLE IF EXISTS shared_notes;
