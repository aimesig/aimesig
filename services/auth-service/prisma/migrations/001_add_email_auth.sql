-- Migration: Add email/password auth support
-- Run this against your Neon database once.

-- 1. Add auth_provider enum
DO $$ BEGIN
  CREATE TYPE "AuthProvider" AS ENUM ('EMAIL', 'PHONE', 'GOOGLE');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- 2. Make phone nullable (existing phone-only users keep their value)
ALTER TABLE users
  ALTER COLUMN phone DROP NOT NULL;

-- 3. Make firebase_uid nullable (email users get it on signup, but it's set async)
ALTER TABLE users
  ALTER COLUMN firebase_uid DROP NOT NULL;

-- 4. Add password_hash column
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS password_hash TEXT;

-- 5. Add auth_provider column (default EMAIL for new rows; existing rows need PHONE)
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS auth_provider "AuthProvider" NOT NULL DEFAULT 'EMAIL';

-- 6. Back-fill existing phone-auth users
UPDATE users
  SET auth_provider = 'PHONE'
  WHERE phone IS NOT NULL AND password_hash IS NULL;

-- Done.
