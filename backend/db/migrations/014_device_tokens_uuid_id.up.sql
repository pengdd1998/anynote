-- Convert device_tokens.id from TEXT to UUID with server-side default.
-- Existing rows with valid UUID text are preserved; rows with non-UUID text
-- will cause a migration failure (intentional -- data should always be UUID).

ALTER TABLE device_tokens ALTER COLUMN id DROP DEFAULT;
ALTER TABLE device_tokens ALTER COLUMN id SET DATA TYPE UUID USING id::UUID;
ALTER TABLE device_tokens ALTER COLUMN id SET DEFAULT gen_random_uuid();
