-- ─────────────────────────────────────────────────────────────────
-- Aimesig ERP Schema  (Neon / PostgreSQL)
-- Run once:  psql $DATABASE_URL -f schema.sql
-- ─────────────────────────────────────────────────────────────────

-- Extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── TENANTS ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tenants (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  slug        TEXT NOT NULL UNIQUE,
  type        TEXT NOT NULL DEFAULT 'school',   -- school|dance|yoga|institute|other
  plan        TEXT NOT NULL DEFAULT 'free',     -- free|starter|pro|enterprise
  logo_url    TEXT,
  timezone    TEXT NOT NULL DEFAULT 'Asia/Kolkata',
  currency    TEXT NOT NULL DEFAULT 'INR',
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── TENANT USERS (admins / staff per tenant) ──────────────────────
CREATE TABLE IF NOT EXISTS tenant_users (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  email       TEXT NOT NULL,
  password    TEXT NOT NULL,             -- bcrypt hash
  name        TEXT NOT NULL,
  role        TEXT NOT NULL DEFAULT 'staff',  -- tenant_admin|finance|hr|staff|readonly
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  last_login  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(tenant_id, email)
);

-- ── MEMBERS (students / clients / members) ───────────────────────
CREATE TABLE IF NOT EXISTS members (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  member_no   TEXT,
  name        TEXT NOT NULL,
  email       TEXT,
  phone       TEXT,
  dob         DATE,
  gender      TEXT,
  address     JSONB,
  guardian    JSONB,
  status      TEXT NOT NULL DEFAULT 'active',  -- active|inactive|alumni
  joined_on   DATE NOT NULL DEFAULT CURRENT_DATE,
  photo_url   TEXT,
  metadata    JSONB DEFAULT '{}',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── STAFF ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS staff (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  employee_no  TEXT,
  name         TEXT NOT NULL,
  email        TEXT,
  phone        TEXT,
  role         TEXT NOT NULL DEFAULT 'instructor',
  department   TEXT,
  dob          DATE,
  gender       TEXT,
  salary       NUMERIC(12,2),
  joined_on    DATE NOT NULL DEFAULT CURRENT_DATE,
  status       TEXT NOT NULL DEFAULT 'active',
  photo_url    TEXT,
  metadata     JSONB DEFAULT '{}',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── COURSES ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS courses (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  code        TEXT,
  description TEXT,
  category    TEXT,
  duration    TEXT,
  capacity    INT,
  fee         NUMERIC(12,2) NOT NULL DEFAULT 0,
  status      TEXT NOT NULL DEFAULT 'draft',   -- draft|active|archived
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── BATCHES ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS batches (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  course_id   UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  start_date  DATE,
  end_date    DATE,
  capacity    INT,
  status      TEXT NOT NULL DEFAULT 'upcoming',  -- upcoming|ongoing|completed
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── ENROLLMENTS ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS enrollments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  member_id   UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  batch_id    UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
  enrolled_on DATE NOT NULL DEFAULT CURRENT_DATE,
  status      TEXT NOT NULL DEFAULT 'active',   -- active|completed|dropped
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(member_id, batch_id)
);

-- ── SCHEDULE SLOTS ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS schedule_slots (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  batch_id    UUID REFERENCES batches(id) ON DELETE SET NULL,
  staff_id    UUID REFERENCES staff(id) ON DELETE SET NULL,
  room        TEXT,
  day_of_week INT,                 -- 0=Sun … 6=Sat; NULL = one-off
  slot_date   DATE,                -- NULL for recurring
  start_time  TIME NOT NULL,
  end_time    TIME NOT NULL,
  is_cancelled BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── ATTENDANCE ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS attendance (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  slot_id     UUID REFERENCES schedule_slots(id) ON DELETE SET NULL,
  member_id   UUID REFERENCES members(id) ON DELETE CASCADE,
  staff_id    UUID REFERENCES staff(id) ON DELETE CASCADE,
  type        TEXT NOT NULL DEFAULT 'member',
  status      TEXT NOT NULL DEFAULT 'present',
  date        DATE NOT NULL,
  note        TEXT,
  marked_by   UUID,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_attendance_unique
ON attendance (
  tenant_id,
  type,
  COALESCE(member_id,'00000000-0000-0000-0000-000000000000'::uuid),
  COALESCE(staff_id,'00000000-0000-0000-0000-000000000000'::uuid),
  date,
  COALESCE(slot_id,'00000000-0000-0000-0000-000000000000'::uuid)
);

-- ── FEE PLANS ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS fee_plans (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  amount      NUMERIC(12,2) NOT NULL,
  frequency   TEXT NOT NULL DEFAULT 'monthly',  -- one_time|monthly|quarterly|annual
  due_day     INT DEFAULT 1,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── INVOICES ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS invoices (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  member_id     UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  invoice_no    TEXT NOT NULL,
  amount        NUMERIC(12,2) NOT NULL,
  due_date      DATE,
  status        TEXT NOT NULL DEFAULT 'pending',  -- pending|paid|overdue|cancelled
  line_items    JSONB DEFAULT '[]',
  notes         TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── PAYMENTS ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS payments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  invoice_id    UUID REFERENCES invoices(id) ON DELETE SET NULL,
  member_id     UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  amount        NUMERIC(12,2) NOT NULL,
  method        TEXT NOT NULL DEFAULT 'cash',   -- cash|upi|card|bank|cheque
  reference     TEXT,
  paid_on       DATE NOT NULL DEFAULT CURRENT_DATE,
  status        TEXT NOT NULL DEFAULT 'completed', -- completed|refunded|pending
  notes         TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── LEADS / ADMISSIONS ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS leads (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  email       TEXT,
  phone       TEXT,
  source      TEXT,
  course_id   UUID REFERENCES courses(id) ON DELETE SET NULL,
  stage       TEXT NOT NULL DEFAULT 'new',   -- new|contacted|demo|negotiation|converted|lost
  notes       TEXT,
  assigned_to UUID REFERENCES staff(id) ON DELETE SET NULL,
  converted_at TIMESTAMPTZ,
  member_id   UUID REFERENCES members(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── CERTIFICATES ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS certificates (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  member_id     UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  course_id     UUID REFERENCES courses(id) ON DELETE SET NULL,
  cert_no       TEXT NOT NULL UNIQUE,
  title         TEXT NOT NULL,
  issued_on     DATE NOT NULL DEFAULT CURRENT_DATE,
  expires_on    DATE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);



-- ── INDEXES ───────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_members_tenant        ON members(tenant_id);
CREATE INDEX IF NOT EXISTS idx_staff_tenant          ON staff(tenant_id);
CREATE INDEX IF NOT EXISTS idx_courses_tenant        ON courses(tenant_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_member    ON enrollments(member_id);
CREATE INDEX IF NOT EXISTS idx_attendance_tenant_date ON attendance(tenant_id, date);
CREATE INDEX IF NOT EXISTS idx_invoices_member       ON invoices(member_id);
CREATE INDEX IF NOT EXISTS idx_payments_tenant       ON payments(tenant_id);
CREATE INDEX IF NOT EXISTS idx_leads_tenant_stage    ON leads(tenant_id, stage);
CREATE INDEX IF NOT EXISTS idx_tenant_users_email    ON tenant_users(tenant_id, email);