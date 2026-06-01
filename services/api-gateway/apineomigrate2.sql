-- =============================================================================
-- Migration: User provisioning + batch staff assignment + attendance fixes
-- Run once against your PostgreSQL database
-- =============================================================================

-- ── tenant_users: add provisioning columns ───────────────────────────────────
ALTER TABLE tenant_users
  ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN     NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS linked_staff_id      UUID        REFERENCES staff(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS linked_member_id     UUID        REFERENCES members(id) ON DELETE SET NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uidx_tenant_users_linked_staff
  ON tenant_users (tenant_id, linked_staff_id)
  WHERE linked_staff_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uidx_tenant_users_linked_member
  ON tenant_users (tenant_id, linked_member_id)
  WHERE linked_member_id IS NOT NULL;

-- ── batches: add staff assignment + schedule_time columns ────────────────────
ALTER TABLE batches
  ADD COLUMN IF NOT EXISTS staff_id      UUID REFERENCES staff(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS schedule_time TEXT;

CREATE INDEX IF NOT EXISTS idx_batches_staff_id ON batches (staff_id);

-- ── attendance: add batch_id column (direct FK for faster queries) ────────────
ALTER TABLE attendance
  ADD COLUMN IF NOT EXISTS batch_id UUID REFERENCES batches(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_attendance_batch_id    ON attendance (batch_id);
CREATE INDEX IF NOT EXISTS idx_attendance_member_date ON attendance (member_id, date);

-- Drop the old DO NOTHING conflict target and replace with a proper one
-- (adjust if your table already has a unique constraint name)
ALTER TABLE attendance
  DROP CONSTRAINT IF EXISTS attendance_no_dup;

ALTER TABLE attendance
  ADD CONSTRAINT attendance_no_dup
  UNIQUE (
    tenant_id,
    COALESCE(batch_id,   '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(member_id,  '00000000-0000-0000-0000-000000000000'::uuid),
    date
  );

-- ── Seed roles for existing tenant_admin check ───────────────────────────────
-- (No data changes needed — roles already exist as 'tenant_admin' in auth.ts)