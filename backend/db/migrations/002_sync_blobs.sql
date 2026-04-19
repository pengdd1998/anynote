-- +migrate Up
CREATE TABLE sync_blobs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    item_type       VARCHAR(50) NOT NULL,       -- 'note', 'tag', 'collection', 'content'
    item_id         UUID NOT NULL,              -- Client-generated UUID
    version         INTEGER NOT NULL DEFAULT 1,
    encrypted_data  BYTEA NOT NULL,             -- Encrypted blob (server cannot read)
    blob_size       INTEGER NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, item_type, item_id)
);

CREATE INDEX idx_sync_blobs_pull ON sync_blobs(user_id, updated_at);
CREATE INDEX idx_sync_blobs_version ON sync_blobs(user_id, version);

-- +migrate Down
DROP TABLE IF EXISTS sync_blobs;
