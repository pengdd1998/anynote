-- +migrate Up
CREATE TABLE publish_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    platform        VARCHAR(50) NOT NULL,
    platform_conn_id UUID REFERENCES platform_connections(id),
    content_item_id UUID,                            -- Reference to generated content
    title           TEXT,
    content         TEXT,                             -- Already public, no encryption needed
    status          VARCHAR(20) DEFAULT 'pending',   -- 'pending', 'publishing', 'published', 'failed'
    platform_url    TEXT,                             -- URL of published content
    error_message   TEXT,
    published_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_publish_logs_user ON publish_logs(user_id);
CREATE INDEX idx_publish_logs_status ON publish_logs(status);

-- +migrate Down
DROP TABLE IF EXISTS publish_logs;
