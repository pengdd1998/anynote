-- +migrate Down
DROP TABLE IF EXISTS post_stats;
ALTER TABLE publish_logs DROP COLUMN IF EXISTS platform_post_id;
