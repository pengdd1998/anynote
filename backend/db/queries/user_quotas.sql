-- name: GetQuota :one
SELECT * FROM user_quotas
WHERE user_id = $1;

-- name: CreateQuota :one
INSERT INTO user_quotas (user_id, plan, daily_ai_limit)
VALUES ($1, $2, $3)
RETURNING *;

-- name: IncrementUsage :one
UPDATE user_quotas
SET daily_ai_used = daily_ai_used + 1, updated_at = NOW()
WHERE user_id = $1
RETURNING *;

-- name: ResetQuota :one
UPDATE user_quotas
SET daily_ai_used = 0, quota_reset_at = NOW(), updated_at = NOW()
WHERE user_id = $1 AND quota_reset_at < NOW() - INTERVAL '1 day'
RETURNING *;

-- name: UpsertQuota :one
INSERT INTO user_quotas (user_id, plan, daily_ai_limit, daily_ai_used, quota_reset_at)
VALUES ($1, $2, $3, $4, NOW())
ON CONFLICT (user_id) DO UPDATE SET
    plan = EXCLUDED.plan,
    daily_ai_limit = EXCLUDED.daily_ai_limit,
    daily_ai_used = EXCLUDED.daily_ai_used,
    quota_reset_at = NOW(),
    updated_at = NOW()
RETURNING *;
