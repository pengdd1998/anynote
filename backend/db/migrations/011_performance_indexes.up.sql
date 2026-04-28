-- +migrate Up
-- Performance indexes for common sync and publish queries.

-- Supports GROUP BY item_type queries (GetItemsByType) and filtered pull by type.
-- The UNIQUE constraint on (user_id, item_type, item_id) is not ideal for
-- aggregate queries that do not reference item_id.
CREATE INDEX IF NOT EXISTS idx_sync_blobs_user_type ON sync_blobs(user_id, item_type);

-- Supports GetLatestVersion and HasMoreSince with a descending version scan,
-- which is more efficient than the existing ASC index when the query needs
-- the maximum version value.
CREATE INDEX IF NOT EXISTS idx_sync_blobs_user_version_desc ON sync_blobs(user_id, version DESC);

-- Supports ListByUser which orders by created_at DESC. The existing
-- idx_publish_logs_user(user_id) index does not carry the sort column.
CREATE INDEX IF NOT EXISTS idx_publish_logs_user_created ON publish_logs(user_id, created_at DESC);

-- +migrate Down
DROP INDEX IF EXISTS idx_sync_blobs_user_type;
DROP INDEX IF EXISTS idx_sync_blobs_user_version_desc;
DROP INDEX IF EXISTS idx_publish_logs_user_created;
