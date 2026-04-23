-- +migrate Up
CREATE TABLE note_links (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    source_id   UUID NOT NULL,
    target_id   UUID NOT NULL,
    link_type   VARCHAR(50) NOT NULL DEFAULT 'reference',
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, source_id, target_id, link_type)
);
CREATE INDEX idx_note_links_source ON note_links(user_id, source_id);
CREATE INDEX idx_note_links_target ON note_links(user_id, target_id);
