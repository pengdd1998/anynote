-- name: CreateSyncBlob :one
INSERT INTO sync_blobs (user_id, item_type, item_id, version, encrypted_data, blob_size)
VALUES ($1, $2, $3, $4, $5, $6)
ON CONFLICT (user_id, item_type, item_id)
DO UPDATE SET
    version = EXCLUDED.version,
    encrypted_data = EXCLUDED.encrypted_data,
    blob_size = EXCLUDED.blob_size,
    updated_at = NOW()
WHERE sync_blobs.version < EXCLUDED.version
RETURNING *;

-- name: GetSyncBlobsSince :many
SELECT * FROM sync_blobs
WHERE user_id = $1 AND updated_at > (
    SELECT updated_at FROM sync_blobs
    WHERE user_id = $1
    ORDER BY updated_at DESC
    LIMIT 1 OFFSET $2
)
ORDER BY updated_at ASC;

-- name: PullBlobsSinceVersion :many
SELECT * FROM sync_blobs
WHERE user_id = $1 AND version > $2
ORDER BY updated_at ASC;

-- name: GetLatestVersion :one
SELECT COALESCE(MAX(version), 0) FROM sync_blobs
WHERE user_id = $1;

-- name: CountItems :one
SELECT COUNT(*) FROM sync_blobs
WHERE user_id = $1;

-- name: GetLastUpdated :one
SELECT COALESCE(MAX(updated_at), '1970-01-01'::timestamptz) FROM sync_blobs
WHERE user_id = $1;

-- name: UpsertSyncBlob :one
INSERT INTO sync_blobs (user_id, item_type, item_id, version, encrypted_data, blob_size)
VALUES ($1, $2, $3, $4, $5, $6)
ON CONFLICT (user_id, item_type, item_id)
DO UPDATE SET
    version = EXCLUDED.version,
    encrypted_data = EXCLUDED.encrypted_data,
    blob_size = EXCLUDED.blob_size,
    updated_at = NOW()
WHERE sync_blobs.version < EXCLUDED.version
RETURNING *;

-- name: GetBlobByUserItem :one
SELECT * FROM sync_blobs
WHERE user_id = $1 AND item_type = $2 AND item_id = $3;

-- name: DeleteBlobsByUser :exec
DELETE FROM sync_blobs WHERE user_id = $1;
