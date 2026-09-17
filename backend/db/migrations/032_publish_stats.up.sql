-- +migrate Up
-- Phase 131: per-post engagement stats for publish history.

-- The platform's own post id (returned by adapters in PublishResult),
-- needed by the stats refresher to locate the post later.
ALTER TABLE publish_logs ADD COLUMN platform_post_id TEXT;
CREATE INDEX IF NOT EXISTS idx_publish_logs_platform_post
    ON publish_logs(platform, platform_post_id)
    WHERE platform_post_id IS NOT NULL;

-- Stats snapshots; the latest row per publish is the current value,
-- older rows form the trend line (trimmed by the worker to 30 per post).
CREATE TABLE post_stats (
    id          BIGSERIAL PRIMARY KEY,
    publish_id  UUID NOT NULL REFERENCES publish_logs(id) ON DELETE CASCADE,
    views       INTEGER,
    likes       INTEGER,
    comments    INTEGER,
    fetched_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_post_stats_publish_fetched
    ON post_stats(publish_id, fetched_at DESC);

-- +migrate Down
DROP TABLE IF EXISTS post_stats;
DROP INDEX IF EXISTS idx_publish_logs_platform_post;
ALTER TABLE publish_logs DROP COLUMN IF EXISTS platform_post_id;
