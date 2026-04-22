-- Store a random per-user recovery salt so that the recovery key derivation
-- uses a true random salt instead of a deterministic one derived from the
-- entropy itself.  Existing users get NULL (backward-compatible fallback on
-- the client side); new registrations always set a 32-byte random value.
ALTER TABLE users ADD COLUMN IF NOT EXISTS recovery_salt BYTEA;
