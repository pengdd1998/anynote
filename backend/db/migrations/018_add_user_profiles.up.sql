-- +migrate Up
-- Add profile-related columns to the users table.
ALTER TABLE users ADD COLUMN IF NOT EXISTS display_name VARCHAR(100) DEFAULT '';
ALTER TABLE users ADD COLUMN IF NOT EXISTS bio VARCHAR(500) DEFAULT '';
ALTER TABLE users ADD COLUMN IF NOT EXISTS public_profile_enabled BOOLEAN DEFAULT false;
