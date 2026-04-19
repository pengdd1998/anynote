-- name: CreateUser :one
INSERT INTO users (email, username, auth_key_hash, salt, recovery_key, plan)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *;

-- name: GetUserByEmail :one
SELECT * FROM users
WHERE email = $1;

-- name: GetUserByID :one
SELECT * FROM users
WHERE id = $1;

-- name: UpdateUserPlan :one
UPDATE users SET plan = $2, updated_at = NOW()
WHERE id = $1
RETURNING *;
