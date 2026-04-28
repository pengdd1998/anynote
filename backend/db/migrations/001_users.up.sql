-- +migrate Up
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

-- +migrate Down
DROP TABLE IF EXISTS users;
