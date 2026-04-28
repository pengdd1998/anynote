ALTER TABLE sync_blobs ADD COLUMN device_id VARCHAR(128) NOT NULL DEFAULT '';
CREATE INDEX idx_sync_blobs_device_id ON sync_blobs(device_id);
