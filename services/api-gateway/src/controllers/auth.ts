import { Router, Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { sql } from '../utils/db';
import { config } from '../config';
import { logger } from '../utils/logger';

const router = Router();

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/** "John Doe" → "john.doe" */
function toUsernameBase(name: string): string {
  return name
    .toLowerCase()
    .trim()
    .replace(/\s+/g, '.')
    .replace(/[^a-z0-9.]/g, '');
}

/** Generate a secure random password: 12 chars, mixed case + digits + symbols */
function generatePassword(): string {
  const upper   = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  const lower   = 'abcdefghjkmnpqrstuvwxyz';
  const digits  = '23456789';
  const symbols = '!@#$%&*';
  const all     = upper + lower + digits + symbols;
  const bytes   = crypto.randomBytes(12);
  let pwd = '';
  // Guarantee at least one of each category
  pwd += upper  [crypto.randomBytes(1)[0] % upper.length];
  pwd += lower  [crypto.randomBytes(1)[0] % lower.length];
  pwd += digits [crypto.randomBytes(1)[0] % digits.length];
  pwd += symbols[crypto.randomBytes(1)[0] % symbols.length];
  for (let i = 4; i < 12; i++) pwd += all[bytes[i] % all.length];
  // Fisher-Yates shuffle
  const arr = pwd.split('');
  for (let i = arr.length - 1; i > 0; i--) {
    const j = crypto.randomBytes(1)[0] % (i + 1);
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr.join('');
}

/** Build a unique username@aimesig.com address scoped to tenant */
async function buildUniqueEmail(tenantId: string, baseName: string): Promise<string> {
  const base = toUsernameBase(baseName);
  for (let i = 0; i < 50; i++) {
    const candidate = i === 0 ? `${base}@aimesig.com` : `${base}${i}@aimesig.com`;
    const rows = await sql`
      SELECT id FROM tenant_users
      WHERE email = ${candidate} AND tenant_id = ${tenantId}
    `;
    if (!rows.length) return candidate;
  }
  return `${base}.${crypto.randomBytes(3).toString('hex')}@aimesig.com`;
}

/** Simple JWT decode without verify (used only where token is already verified) */
function decodeToken(auth: string | undefined): any | null {
  if (!auth?.startsWith('Bearer ')) return null;
  try {
    return jwt.verify(auth.slice(7), config.jwt.secret);
  } catch {
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /erp/auth/register  – create tenant + first admin
// ─────────────────────────────────────────────────────────────────────────────
router.post('/register', async (req: Request, res: Response): Promise<void> => {
  const { org_name, org_type, timezone, currency, admin_name, admin_email, admin_password } = req.body;

  if (!org_name || !admin_email || !admin_password || !admin_name) {
    res.status(400).json({ error: 'org_name, admin_name, admin_email, admin_password are required' });
    return;
  }

  try {
    const slug =
      org_name.toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '') +
      '-' + Date.now().toString(36);

    const hash = await bcrypt.hash(admin_password, 12);

    const [tenant] = await sql`
      INSERT INTO tenants (name, slug, type, timezone, currency)
      VALUES (${org_name}, ${slug}, ${org_type || 'school'}, ${timezone || 'Asia/Kolkata'}, ${currency || 'INR'})
      RETURNING id, name, slug
    `;

    const [user] = await sql`
      INSERT INTO tenant_users (tenant_id, email, password, name, role)
      VALUES (${tenant.id}, ${admin_email.toLowerCase()}, ${hash}, ${admin_name}, 'tenant_admin')
      RETURNING id, email, name, role
    `;

    const token = jwt.sign(
      { sub: user.id, email: user.email, role: user.role, tenant_id: tenant.id },
      config.jwt.secret,
      { expiresIn: config.jwt.expiresIn } as any,
    );

    res.status(201).json({
      tenant,
      user: { id: user.id, email: user.email, name: user.name, role: user.role },
      token,
    });
  } catch (err: any) {
    if (err.message?.includes('unique') || err.code === '23505') {
      res.status(409).json({ error: 'Email or org slug already exists' });
    } else {
      logger.error('register error', { error: err.message });
      res.status(500).json({ error: 'Registration failed' });
    }
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /erp/auth/login
// ─────────────────────────────────────────────────────────────────────────────
router.post('/login', async (req: Request, res: Response): Promise<void> => {
  const { email, password, tenant_slug } = req.body;
  if (!email || !password) {
    res.status(400).json({ error: 'email and password are required' });
    return;
  }

  try {
    const rows = tenant_slug
      ? await sql`
          SELECT tu.id, tu.email, tu.name, tu.role, tu.password, tu.tenant_id,
                 tu.is_active, t.is_active AS tenant_active,
                 tu.must_change_password, tu.linked_staff_id, tu.linked_member_id
          FROM   tenant_users tu
          JOIN   tenants t ON t.id = tu.tenant_id
          WHERE  tu.email = ${email.toLowerCase()} AND t.slug = ${tenant_slug}
        `
      : await sql`
          SELECT tu.id, tu.email, tu.name, tu.role, tu.password, tu.tenant_id,
                 tu.is_active, t.is_active AS tenant_active,
                 tu.must_change_password, tu.linked_staff_id, tu.linked_member_id
          FROM   tenant_users tu
          JOIN   tenants t ON t.id = tu.tenant_id
          WHERE  tu.email = ${email.toLowerCase()}
          LIMIT  1
        `;

    if (!rows.length || !(await bcrypt.compare(password, rows[0].password))) {
      res.status(401).json({ error: 'Invalid credentials' });
      return;
    }

    const u = rows[0];
    if (!u.is_active)     { res.status(403).json({ error: 'Account disabled' });       return; }
    if (!u.tenant_active) { res.status(403).json({ error: 'Organisation suspended' }); return; }

    await sql`UPDATE tenant_users SET last_login = NOW() WHERE id = ${u.id}`;

    const token = jwt.sign(
      {
        sub: u.id,
        email: u.email,
        role: u.role,
        tenant_id: u.tenant_id,
        ...(u.linked_staff_id  && { linked_staff_id:  u.linked_staff_id }),
        ...(u.linked_member_id && { linked_member_id: u.linked_member_id }),
      },
      config.jwt.secret,
      { expiresIn: config.jwt.expiresIn } as any,
    );

    res.json({
      token,
      user: {
        id: u.id,
        email: u.email,
        name: u.name,
        role: u.role,
        tenant_id: u.tenant_id,
        must_change_password: u.must_change_password,
        linked_staff_id:  u.linked_staff_id  ?? null,
        linked_member_id: u.linked_member_id ?? null,
      },
    });
  } catch (err: any) {
    logger.error('login error', { error: err.message });
    res.status(500).json({ error: 'Login failed' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /erp/auth/me  (any authenticated user)
// ─────────────────────────────────────────────────────────────────────────────
router.get('/me', async (req: Request, res: Response): Promise<void> => {
  const payload = decodeToken(req.headers['authorization']);
  if (!payload) { res.status(401).json({ error: 'Unauthorized' }); return; }

  try {
    const [u] = await sql`
      SELECT tu.id, tu.email, tu.name, tu.role, tu.is_active,
             tu.must_change_password, tu.last_login,
             tu.linked_staff_id, tu.linked_member_id,
             t.name AS org_name, t.slug AS org_slug, t.type AS org_type,
             t.timezone, t.currency
      FROM   tenant_users tu
      JOIN   tenants t ON t.id = tu.tenant_id
      WHERE  tu.id = ${payload.sub} AND tu.is_active = true
    `;
    if (!u) { res.status(404).json({ error: 'User not found' }); return; }

    // Attach linked entity details
    let linked: any = null;
    if (u.linked_staff_id) {
      const [s] = await sql`
        SELECT id, name, employee_no, role AS staff_role, department, photo_url
        FROM staff WHERE id = ${u.linked_staff_id}
      `;
      linked = { type: 'staff', ...s };
    } else if (u.linked_member_id) {
      const [m] = await sql`
        SELECT id, name, member_no, photo_url
        FROM members WHERE id = ${u.linked_member_id}
      `;
      linked = { type: 'member', ...m };
    }

    res.json({ ...u, linked });
  } catch (err: any) {
    logger.error('me error', { error: err.message });
    res.status(500).json({ error: 'Failed to fetch profile' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /erp/auth/refresh
// ─────────────────────────────────────────────────────────────────────────────
router.post('/refresh', async (req: Request, res: Response): Promise<void> => {
  const payload = decodeToken(req.headers['authorization']);
  if (!payload) { res.status(401).json({ error: 'No token or invalid token' }); return; }

  try {
    const [u] = await sql`
      SELECT id, email, name, role, tenant_id, is_active,
             linked_staff_id, linked_member_id
      FROM   tenant_users WHERE id = ${payload.sub} AND is_active = true
    `;
    if (!u) { res.status(401).json({ error: 'User not found or inactive' }); return; }

    const token = jwt.sign(
      {
        sub: u.id, email: u.email, role: u.role, tenant_id: u.tenant_id,
        ...(u.linked_staff_id  && { linked_staff_id:  u.linked_staff_id }),
        ...(u.linked_member_id && { linked_member_id: u.linked_member_id }),
      },
      config.jwt.secret,
      { expiresIn: config.jwt.expiresIn } as any,
    );
    res.json({ token });
  } catch {
    res.status(401).json({ error: 'Invalid token' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /erp/auth/change-password  (authenticated; self-service reset)
// ─────────────────────────────────────────────────────────────────────────────
router.post('/change-password', async (req: Request, res: Response): Promise<void> => {
  const payload = decodeToken(req.headers['authorization']);
  if (!payload) { res.status(401).json({ error: 'Unauthorized' }); return; }

  const { current_password, new_password } = req.body;
  if (!current_password || !new_password) {
    res.status(400).json({ error: 'current_password and new_password are required' });
    return;
  }
  if ((new_password as string).length < 8) {
    res.status(400).json({ error: 'Password must be at least 8 characters' });
    return;
  }

  try {
    const [u] = await sql`SELECT id, password FROM tenant_users WHERE id = ${payload.sub}`;
    if (!u) { res.status(404).json({ error: 'User not found' }); return; }

    if (!(await bcrypt.compare(current_password, u.password))) {
      res.status(401).json({ error: 'Current password is incorrect' });
      return;
    }

    const hash = await bcrypt.hash(new_password, 12);
    await sql`
      UPDATE tenant_users
      SET password = ${hash}, must_change_password = false, updated_at = NOW()
      WHERE id = ${u.id}
    `;
    res.json({ message: 'Password updated successfully' });
  } catch {
    res.status(401).json({ error: 'Invalid token' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /erp/auth/reset-password-by-admin  (admin only)
// ─────────────────────────────────────────────────────────────────────────────
router.post('/reset-password-by-admin', async (req: Request, res: Response): Promise<void> => {
  const payload = decodeToken(req.headers['authorization']);
  if (!payload) { res.status(401).json({ error: 'Unauthorized' }); return; }
  if (payload.role !== 'tenant_admin') {
    res.status(403).json({ error: 'Admin access required' });
    return;
  }

  const { user_id } = req.body;
  if (!user_id) { res.status(400).json({ error: 'user_id required' }); return; }

  try {
    const [u] = await sql`
      SELECT id, name, email FROM tenant_users
      WHERE id = ${user_id} AND tenant_id = ${payload.tenant_id}
    `;
    if (!u) { res.status(404).json({ error: 'User not found' }); return; }

    const newPassword = generatePassword();
    const hash = await bcrypt.hash(newPassword, 12);

    await sql`
      UPDATE tenant_users
      SET password = ${hash}, must_change_password = true, updated_at = NOW()
      WHERE id = ${u.id}
    `;

    res.json({
      message: 'Password reset successfully',
      user: { id: u.id, name: u.name, email: u.email },
      temporary_password: newPassword,
    });
  } catch (err: any) {
    logger.error('reset-password-by-admin error', { error: err.message });
    res.status(500).json({ error: 'Reset failed' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /erp/auth/provision-staff  (admin: create @aimesig.com login for staff)
// ─────────────────────────────────────────────────────────────────────────────
router.post('/provision-staff', async (req: Request, res: Response): Promise<void> => {
  const payload = decodeToken(req.headers['authorization']);
  if (!payload) { res.status(401).json({ error: 'Unauthorized' }); return; }
  if (payload.role !== 'tenant_admin') {
    res.status(403).json({ error: 'Admin access required' });
    return;
  }

  const { staff_id } = req.body;
  if (!staff_id) { res.status(400).json({ error: 'staff_id required' }); return; }

  try {
    const [staff] = await sql`
      SELECT id, name FROM staff
      WHERE id = ${staff_id} AND tenant_id = ${payload.tenant_id}
    `;
    if (!staff) { res.status(404).json({ error: 'Staff not found' }); return; }

    const existing = await sql`
      SELECT id, email FROM tenant_users
      WHERE linked_staff_id = ${staff_id} AND tenant_id = ${payload.tenant_id}
    `;
    if (existing.length) {
      res.status(409).json({
        error: 'Staff already has a login account',
        existing_email: existing[0].email,
      });
      return;
    }

    const aimesigEmail = await buildUniqueEmail(payload.tenant_id, staff.name);
    const tempPassword = generatePassword();
    const hash = await bcrypt.hash(tempPassword, 12);

    const [user] = await sql`
      INSERT INTO tenant_users
        (tenant_id, email, password, name, role, linked_staff_id, must_change_password)
      VALUES
        (${payload.tenant_id}, ${aimesigEmail}, ${hash}, ${staff.name},
         'staff', ${staff_id}, true)
      RETURNING id, email, name, role, linked_staff_id
    `;

    res.status(201).json({
      message: 'Staff login created successfully',
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
        linked_staff_id: user.linked_staff_id,
      },
      temporary_password: tempPassword,
    });
  } catch (err: any) {
    logger.error('provision-staff error', { error: err.message });
    res.status(500).json({ error: 'Provisioning failed' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /erp/auth/provision-member  (admin: create @aimesig.com login for member)
// ─────────────────────────────────────────────────────────────────────────────
router.post('/provision-member', async (req: Request, res: Response): Promise<void> => {
  const payload = decodeToken(req.headers['authorization']);
  if (!payload) { res.status(401).json({ error: 'Unauthorized' }); return; }
  if (payload.role !== 'tenant_admin') {
    res.status(403).json({ error: 'Admin access required' });
    return;
  }

  const { member_id } = req.body;
  if (!member_id) { res.status(400).json({ error: 'member_id required' }); return; }

  try {
    const [member] = await sql`
      SELECT id, name FROM members
      WHERE id = ${member_id} AND tenant_id = ${payload.tenant_id}
    `;
    if (!member) { res.status(404).json({ error: 'Member not found' }); return; }

    const existing = await sql`
      SELECT id, email FROM tenant_users
      WHERE linked_member_id = ${member_id} AND tenant_id = ${payload.tenant_id}
    `;
    if (existing.length) {
      res.status(409).json({
        error: 'Member already has a login account',
        existing_email: existing[0].email,
      });
      return;
    }

    const aimesigEmail = await buildUniqueEmail(payload.tenant_id, member.name);
    const tempPassword = generatePassword();
    const hash = await bcrypt.hash(tempPassword, 12);

    const [user] = await sql`
      INSERT INTO tenant_users
        (tenant_id, email, password, name, role, linked_member_id, must_change_password)
      VALUES
        (${payload.tenant_id}, ${aimesigEmail}, ${hash}, ${member.name},
         'member', ${member_id}, true)
      RETURNING id, email, name, role, linked_member_id
    `;

    res.status(201).json({
      message: 'Member login created successfully',
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
        linked_member_id: user.linked_member_id,
      },
      temporary_password: tempPassword,
    });
  } catch (err: any) {
    logger.error('provision-member error', { error: err.message });
    res.status(500).json({ error: 'Provisioning failed' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /erp/auth/provision-bulk  (admin: provision logins for all un-provisioned)
// ─────────────────────────────────────────────────────────────────────────────
router.post('/provision-bulk', async (req: Request, res: Response): Promise<void> => {
  const payload = decodeToken(req.headers['authorization']);
  if (!payload) { res.status(401).json({ error: 'Unauthorized' }); return; }
  if (payload.role !== 'tenant_admin') {
    res.status(403).json({ error: 'Admin access required' });
    return;
  }

  const { type } = req.body; // 'staff' | 'member' | 'all'
  if (!type || !['staff', 'member', 'all'].includes(type)) {
    res.status(400).json({ error: "type must be 'staff', 'member', or 'all'" });
    return;
  }

  const provisioned: any[] = [];
  const errors: any[] = [];

  try {
    if (type === 'staff' || type === 'all') {
      const unprovisioned = await sql`
        SELECT s.id, s.name FROM staff s
        WHERE s.tenant_id = ${payload.tenant_id}
          AND NOT EXISTS (
            SELECT 1 FROM tenant_users tu
            WHERE tu.linked_staff_id = s.id AND tu.tenant_id = s.tenant_id
          )
      `;

      for (const s of unprovisioned) {
        try {
          const email = await buildUniqueEmail(payload.tenant_id, s.name);
          const pwd   = generatePassword();
          const hash  = await bcrypt.hash(pwd, 12);
          const [u]   = await sql`
            INSERT INTO tenant_users
              (tenant_id, email, password, name, role, linked_staff_id, must_change_password)
            VALUES (${payload.tenant_id}, ${email}, ${hash}, ${s.name}, 'staff', ${s.id}, true)
            RETURNING id, email, name, role
          `;
          provisioned.push({ ...u, temporary_password: pwd, entity_type: 'staff', entity_id: s.id });
        } catch (e: any) {
          errors.push({ entity_type: 'staff', entity_id: s.id, error: e.message });
        }
      }
    }

    if (type === 'member' || type === 'all') {
      const unprovisioned = await sql`
        SELECT m.id, m.name FROM members m
        WHERE m.tenant_id = ${payload.tenant_id}
          AND NOT EXISTS (
            SELECT 1 FROM tenant_users tu
            WHERE tu.linked_member_id = m.id AND tu.tenant_id = m.tenant_id
          )
      `;

      for (const m of unprovisioned) {
        try {
          const email = await buildUniqueEmail(payload.tenant_id, m.name);
          const pwd   = generatePassword();
          const hash  = await bcrypt.hash(pwd, 12);
          const [u]   = await sql`
            INSERT INTO tenant_users
              (tenant_id, email, password, name, role, linked_member_id, must_change_password)
            VALUES (${payload.tenant_id}, ${email}, ${hash}, ${m.name}, 'member', ${m.id}, true)
            RETURNING id, email, name, role
          `;
          provisioned.push({ ...u, temporary_password: pwd, entity_type: 'member', entity_id: m.id });
        } catch (e: any) {
          errors.push({ entity_type: 'member', entity_id: m.id, error: e.message });
        }
      }
    }

    res.status(201).json({ provisioned, errors, total: provisioned.length });
  } catch (err: any) {
    logger.error('provision-bulk error', { error: err.message });
    res.status(500).json({ error: 'Bulk provisioning failed' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /erp/auth/users  (admin: list all provisioned users)
// ─────────────────────────────────────────────────────────────────────────────
router.get('/users', async (req: Request, res: Response): Promise<void> => {
  const payload = decodeToken(req.headers['authorization']);
  if (!payload) { res.status(401).json({ error: 'Unauthorized' }); return; }
  if (payload.role !== 'tenant_admin') {
    res.status(403).json({ error: 'Admin access required' });
    return;
  }

  try {
    const rows = await sql`
      SELECT
        tu.id, tu.email, tu.name, tu.role, tu.is_active,
        tu.must_change_password, tu.last_login, tu.created_at,
        tu.linked_staff_id, tu.linked_member_id,
        s.name   AS staff_name,
        s.role   AS staff_role,
        m.name   AS member_name,
        m.member_no
      FROM   tenant_users tu
      LEFT JOIN staff   s ON s.id = tu.linked_staff_id
      LEFT JOIN members m ON m.id = tu.linked_member_id
      WHERE  tu.tenant_id = ${payload.tenant_id}
      ORDER  BY tu.created_at DESC
    `;
    res.json(rows);
  } catch (err: any) {
    logger.error('users list error', { error: err.message });
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /erp/auth/users/:id  (admin: enable/disable or update user)
// ─────────────────────────────────────────────────────────────────────────────
router.patch('/users/:id', async (req: Request, res: Response): Promise<void> => {
  const payload = decodeToken(req.headers['authorization']);
  if (!payload) { res.status(401).json({ error: 'Unauthorized' }); return; }
  if (payload.role !== 'tenant_admin') {
    res.status(403).json({ error: 'Admin access required' });
    return;
  }

  // Prevent admin from disabling themselves
  if (req.params.id === payload.sub && req.body.is_active === false) {
    res.status(400).json({ error: 'Cannot disable your own account' });
    return;
  }

  try {
    const { is_active } = req.body;
    const [row] = await sql`
      UPDATE tenant_users
      SET is_active = ${Boolean(is_active)}, updated_at = NOW()
      WHERE id = ${req.params.id} AND tenant_id = ${payload.tenant_id}
      RETURNING id, email, name, role, is_active
    `;
    if (!row) { res.status(404).json({ error: 'User not found' }); return; }
    res.json(row);
  } catch (err: any) {
    logger.error('patch user error', { error: err.message });
    res.status(500).json({ error: 'Update failed' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /erp/auth/forgot-password  (placeholder – hook up email service here)
// ─────────────────────────────────────────────────────────────────────────────
router.post('/forgot-password', async (_req: Request, res: Response): Promise<void> => {
  // TODO: generate token, store in DB, send via email service
  res.json({ message: 'If that email exists, a reset link has been sent.' });
});

export default router;
