-- Store the master key encrypted with a recovery-derived key.
-- During registration the client encrypts masterKey with a key derived from
-- the BIP-39 recovery mnemonic + recovery_salt and stores the blob here.
-- During account recovery the client decrypts the blob to recover the
-- original master key (and thus the encrypt key needed for E2E data).
-- Legacy accounts (registered before this column) have NULL here.
ALTER TABLE users ADD COLUMN IF NOT EXISTS encrypted_master_key BYTEA;
