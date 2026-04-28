-- +migrate Up
CREATE TABLE llm_configs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name            VARCHAR(100) NOT NULL,           -- User-friendly name
    provider        VARCHAR(50) NOT NULL,            -- 'openai', 'deepseek', 'qwen', 'custom'
    base_url        VARCHAR(500) NOT NULL,           -- e.g. "https://api.openai.com/v1"
    encrypted_key   BYTEA NOT NULL,                  -- AES-256-GCM encrypted API key
    model           VARCHAR(100) NOT NULL,           -- e.g. "gpt-4o", "deepseek-chat"
    is_default      BOOLEAN DEFAULT FALSE,
    max_tokens      INTEGER DEFAULT 4096,
    temperature     REAL DEFAULT 0.7,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_llm_configs_user ON llm_configs(user_id);

-- +migrate Down
DROP TABLE IF EXISTS llm_configs;
