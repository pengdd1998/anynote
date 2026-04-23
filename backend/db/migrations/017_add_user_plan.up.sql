-- +migrate Up
-- The plan column already exists in the users table (added in 001_users.sql).
-- This migration adds a plan_updated_at column for tracking plan changes
-- and ensures the plan column has a proper default.
ALTER TABLE users ADD COLUMN IF NOT EXISTS plan_updated_at TIMESTAMPTZ;

-- Backfill existing rows: set plan to 'free' if NULL.
UPDATE users SET plan = 'free' WHERE plan IS NULL;
