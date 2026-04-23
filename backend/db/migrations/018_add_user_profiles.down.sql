-- +migrate Down
ALTER TABLE users DROP COLUMN IF EXISTS public_profile_enabled;
ALTER TABLE users DROP COLUMN IF EXISTS bio;
ALTER TABLE users DROP COLUMN IF EXISTS display_name;
