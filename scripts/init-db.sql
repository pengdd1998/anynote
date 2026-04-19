CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           VARCHAR(255) UNIQUE NOT NULL,
    username        VARCHAR(100) UNIQUE NOT NULL,
    auth_key_hash   BYTEA NOT NULL,            -- HKDF(master_key, "auth") hash, NOT password
    salt            BYTEA NOT NULL,             -- Argon2id salt
    recovery_key    BYTEA NOT NULL,             -- Encrypted recovery key (24-word mnemonic)
    plan            VARCHAR(20) DEFAULT 'free', -- 'free', 'pro', 'lifetime'
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_users_email ON users(email);

CREATE TABLE sync_blobs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    item_type       VARCHAR(50) NOT NULL,       -- 'note', 'tag', 'collection', 'content'
    item_id         UUID NOT NULL,              -- Client-generated UUID
    version         INTEGER NOT NULL DEFAULT 1,
    encrypted_data  BYTEA NOT NULL,             -- Encrypted blob (server cannot read)
    blob_size       INTEGER NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, item_type, item_id)
);
CREATE INDEX idx_sync_blobs_pull ON sync_blobs(user_id, updated_at);
CREATE INDEX idx_sync_blobs_version ON sync_blobs(user_id, version);

CREATE TABLE user_quotas (
    user_id         UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    plan            VARCHAR(20) DEFAULT 'free',     -- 'free', 'pro', 'lifetime'
    daily_ai_limit  INTEGER DEFAULT 50,              -- Free: 50/day, Pro: 500/day
    daily_ai_used   INTEGER DEFAULT 0,
    quota_reset_at  TIMESTAMPTZ DEFAULT NOW(),       -- Daily reset timestamp
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

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

CREATE TABLE platform_connections (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    platform        VARCHAR(50) NOT NULL,            -- 'xiaohongshu', 'wechat', 'medium', etc.
    platform_uid    VARCHAR(255),                    -- Platform-specific user ID
    display_name    VARCHAR(255),                    -- Platform display name
    encrypted_auth  BYTEA NOT NULL,                  -- AES-256-GCM encrypted auth data (cookies/tokens)
    status          VARCHAR(20) DEFAULT 'active',    -- 'active', 'expired', 'revoked'
    last_verified   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, platform)
);
CREATE INDEX idx_platform_connections_user ON platform_connections(user_id);

CREATE TABLE publish_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    platform        VARCHAR(50) NOT NULL,
    platform_conn_id UUID REFERENCES platform_connections(id),
    content_item_id UUID,                            -- Reference to generated content
    title           TEXT,
    content         TEXT,                             -- Already public, no encryption needed
    status          VARCHAR(20) DEFAULT 'pending',   -- 'pending', 'publishing', 'published', 'failed'
    platform_url    TEXT,                             -- URL of published content
    error_message   TEXT,
    published_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_publish_logs_user ON publish_logs(user_id);
CREATE INDEX idx_publish_logs_status ON publish_logs(status);

CREATE TABLE shared_notes (
    id                TEXT PRIMARY KEY,
    encrypted_content TEXT NOT NULL,
    encrypted_title   TEXT NOT NULL,
    share_key_hash    TEXT NOT NULL,          -- hash of the decryption key (for optional password verification)
    has_password      BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at        TIMESTAMPTZ,
    view_count        INTEGER NOT NULL DEFAULT 0,
    max_views         INTEGER,
    created_by        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_shared_notes_created_by ON shared_notes(created_by);
CREATE INDEX idx_shared_notes_expires_at ON shared_notes(expires_at);



-- device_tokens (no +migrate Up marker in original)
CREATE TABLE IF NOT EXISTS device_tokens (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    token TEXT NOT NULL UNIQUE,
    platform TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON device_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_device_tokens_token ON device_tokens(token);
