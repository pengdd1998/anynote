-- name: CreatePlatformConnection :one
INSERT INTO platform_connections (user_id, platform, platform_uid, display_name, encrypted_auth, status)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *;

-- name: GetPlatformConnection :one
SELECT * FROM platform_connections
WHERE user_id = $1 AND platform = $2;

-- name: ListPlatformConnections :many
SELECT * FROM platform_connections
WHERE user_id = $1
ORDER BY created_at DESC;

-- name: UpdatePlatformConnection :one
UPDATE platform_connections SET
    platform_uid = $3,
    display_name = $4,
    encrypted_auth = $5,
    status = $6,
    last_verified = NOW(),
    updated_at = NOW()
WHERE id = $1 AND user_id = $2
RETURNING *;

-- name: DeletePlatformConnection :exec
DELETE FROM platform_connections
WHERE id = $1 AND user_id = $2;

-- name: VerifyPlatformConnection :one
UPDATE platform_connections SET
    last_verified = NOW(),
    updated_at = NOW()
WHERE id = $1 AND user_id = $2
RETURNING *;
