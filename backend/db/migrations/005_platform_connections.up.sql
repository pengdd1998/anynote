-- +migrate Up
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

-- +migrate Down
DROP TABLE IF EXISTS platform_connections;
