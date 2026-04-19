-- name: CreatePublishLog :one
INSERT INTO publish_logs (user_id, platform, platform_conn_id, content_item_id, title, content, status)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING *;

-- name: GetPublishLogByID :one
SELECT * FROM publish_logs
WHERE id = $1 AND user_id = $2;

-- name: ListPublishLogsByUser :many
SELECT * FROM publish_logs
WHERE user_id = $1
ORDER BY created_at DESC;

-- name: UpdatePublishStatus :one
UPDATE publish_logs SET
    status = $3,
    error_message = $4,
    platform_url = $5,
    published_at = CASE WHEN $3 = 'published' THEN NOW() ELSE published_at END
WHERE id = $1 AND user_id = $2
RETURNING *;

-- name: GetPendingPublishLogs :many
SELECT * FROM publish_logs
WHERE status = 'pending'
ORDER BY created_at ASC
LIMIT $1;
