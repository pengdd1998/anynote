DROP INDEX IF EXISTS idx_sync_blobs_device_id;
ALTER TABLE sync_blobs DROP COLUMN IF EXISTS device_id;
