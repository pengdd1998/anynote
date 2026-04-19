-- name: CreateLLMConfig :one
INSERT INTO llm_configs (user_id, name, provider, base_url, encrypted_key, model, is_default, max_tokens, temperature)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
RETURNING *;

-- name: GetLLMConfigByID :one
SELECT * FROM llm_configs
WHERE id = $1;

-- name: ListLLMConfigsByUser :many
SELECT * FROM llm_configs
WHERE user_id = $1
ORDER BY created_at DESC;

-- name: GetDefaultLLMConfig :one
SELECT * FROM llm_configs
WHERE user_id = $1 AND is_default = true
LIMIT 1;

-- name: UpdateLLMConfig :one
UPDATE llm_configs SET
    name = $3,
    provider = $4,
    base_url = $5,
    encrypted_key = $6,
    model = $7,
    is_default = $8,
    max_tokens = $9,
    temperature = $10,
    updated_at = NOW()
WHERE id = $1 AND user_id = $2
RETURNING *;

-- name: DeleteLLMConfig :exec
DELETE FROM llm_configs
WHERE id = $1 AND user_id = $2;

-- name: SetDefaultLLMConfig :exec
UPDATE llm_configs SET is_default = false
WHERE user_id = $1 AND is_default = true;
