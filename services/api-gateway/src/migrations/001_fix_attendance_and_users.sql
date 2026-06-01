-- ============================================================
-- Migration: Fix attendance unique constraint + tenant_users
-- Run this once against your database
-- ============================================================

-- 1. Ensure tenant_users has all required columns
-- ─────────────────────────────────────────────────────────────
ALTER TABLE tenant_users
  ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN    NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS linked_staff_id      UUID       REFERENCES staff(id)   ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS linked_member_id     UUID       REFERENCES members(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS last_login           TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS is_active            BOOLEAN    NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Prevent a staff member or member from having more than one login
CREATE UNIQUE INDEX IF NOT EXISTS uq_tenant_users_staff_id
  ON tenant_users (tenant_id, linked_staff_id)
  WHERE linked_staff_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_tenant_users_member_id
  ON tenant_users (tenant_id, linked_member_id)
  WHERE linked_member_id IS NOT NULL;

-- 2. Fix attendance unique constraint
-- ─────────────────────────────────────────────────────────────
-- Drop any old malformed constraint that used COALESCE expressions
-- (expression-based constraints/indexes cannot be used by ON CONFLICT)
DO $$
DECLARE
  idx_name text;
BEGIN
  FOR idx_name IN
    SELECT indexname FROM pg_indexes
    WHERE tablename = 'attendance'
      AND indexdef ILIKE '%coalesce%'
  LOOP
    EXECUTE 'DROP INDEX IF EXISTS ' || idx_name;
  END LOOP;
END;
$$;

-- Create clean partial unique indexes that ON CONFLICT can reference
-- For member attendance (most common)
CREATE UNIQUE INDEX IF NOT EXISTS uq_attendance_batch_member_date
  ON attendance (tenant_id, batch_id, member_id, date)
  WHERE member_id IS NOT NULL AND batch_id IS NOT NULL;

-- For staff attendance (when tracking staff presence)
CREATE UNIQUE INDEX IF NOT EXISTS uq_attendance_batch_staff_date
  ON attendance (tenant_id, batch_id, staff_id, date)
  WHERE staff_id IS NOT NULL AND batch_id IS NOT NULL;

-- For slot-based attendance (without batch)
CREATE UNIQUE INDEX IF NOT EXISTS uq_attendance_slot_member_date
  ON attendance (tenant_id, slot_id, member_id, date)
  WHERE slot_id IS NOT NULL AND member_id IS NOT NULL AND batch_id IS NULL;

-- 3. Ensure batches has staff_id and schedule_time columns
-- ─────────────────────────────────────────────────────────────
ALTER TABLE batches
  ADD COLUMN IF NOT EXISTS staff_id      UUID        REFERENCES staff(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS schedule_time VARCHAR(100),
  ADD COLUMN IF NOT EXISTS status        VARCHAR(20) NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- 4. Ensure enrollments has a unique constraint on (member_id, batch_id)
-- ─────────────────────────────────────────────────────────────
CREATE UNIQUE INDEX IF NOT EXISTS uq_enrollments_member_batch
  ON enrollments (member_id, batch_id);

-- ============================================================
-- End of migration
-- ============================================================
