-- +migrate Up
CREATE TABLE user_quotas (
    user_id         UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    plan            VARCHAR(20) DEFAULT 'free',     -- 'free', 'pro', 'lifetime'
    daily_ai_limit  INTEGER DEFAULT 50,              -- Free: 50/day, Pro: 500/day
    daily_ai_used   INTEGER DEFAULT 0,
    quota_reset_at  TIMESTAMPTZ DEFAULT NOW(),       -- Daily reset timestamp
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- +migrate Down
DROP TABLE IF EXISTS user_quotas;
