-- +migrate Down
ALTER TABLE users DROP COLUMN IF EXISTS plan_updated_at;
