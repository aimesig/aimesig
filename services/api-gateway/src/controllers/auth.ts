import { Router, Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { sql } from '../../utils/db';
import { config } from '../../config';
import { logger } from '../../utils/logger';

const router = Router();

// ── POST /erp/auth/register ───────────────────────────────────────
// Register a new tenant + first admin user
router.post('/register', async (req: Request, res: Response): Promise<void> => {
  const { org_name, org_type, timezone, currency, admin_name, admin_email, admin_password } = req.body;
  if (!org_name || !admin_email || !admin_password || !admin_name) {
    res.status(400).json({ error: 'org_name, admin_name, admin_email, admin_password are required' });
    return;
  }
  try {
    const slug = org_name.toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '') + '-' + Date.now().toString(36);
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
      { expiresIn: config.jwt.expiresIn } as any
    );
    res.status(201).json({ tenant, user: { id: user.id, email: user.email, name: user.name, role: user.role }, token });
  } catch (err: any) {
    if (err.message?.includes('unique')) {
      res.status(409).json({ error: 'Email or org slug already exists' });
    } else {
      logger.error('register error', { error: err.message });
      res.status(500).json({ error: 'Registration failed' });
    }
  }
});

// ── POST /erp/auth/login ──────────────────────────────────────────
router.post('/login', async (req: Request, res: Response): Promise<void> => {
  const { email, password, tenant_slug } = req.body;
  if (!email || !password) {
    res.status(400).json({ error: 'email and password are required' });
    return;
  }
  try {
    const query = tenant_slug
      ? sql`
          SELECT tu.id, tu.email, tu.name, tu.role, tu.password, tu.tenant_id, tu.is_active,
                 t.is_active as tenant_active
          FROM   tenant_users tu
          JOIN   tenants t ON t.id = tu.tenant_id
          WHERE  tu.email = ${email.toLowerCase()}
            AND  t.slug   = ${tenant_slug}
        `
      : sql`
          SELECT tu.id, tu.email, tu.name, tu.role, tu.password, tu.tenant_id, tu.is_active,
                 t.is_active as tenant_active
          FROM   tenant_users tu
          JOIN   tenants t ON t.id = tu.tenant_id
          WHERE  tu.email = ${email.toLowerCase()}
          LIMIT  1
        `;
    const rows = await query;
    if (!rows.length || !(await bcrypt.compare(password, rows[0].password))) {
      res.status(401).json({ error: 'Invalid credentials' });
      return;
    }
    const u = rows[0];
    if (!u.is_active)      { res.status(403).json({ error: 'Account disabled' });       return; }
    if (!u.tenant_active)  { res.status(403).json({ error: 'Organisation suspended' }); return; }

    await sql`UPDATE tenant_users SET last_login = NOW() WHERE id = ${u.id}`;

    const token = jwt.sign(
      { sub: u.id, email: u.email, role: u.role, tenant_id: u.tenant_id },
      config.jwt.secret,
      { expiresIn: config.jwt.expiresIn } as any
    );
    res.json({ token, user: { id: u.id, email: u.email, name: u.name, role: u.role, tenant_id: u.tenant_id } });
  } catch (err: any) {
    logger.error('login error', { error: err.message });
    res.status(500).json({ error: 'Login failed' });
  }
});

// ── POST /erp/auth/refresh ────────────────────────────────────────
router.post('/refresh', async (req: Request, res: Response): Promise<void> => {
  const auth = req.headers['authorization'];
  if (!auth?.startsWith('Bearer ')) { res.status(401).json({ error: 'No token' }); return; }
  try {
    const old = jwt.verify(auth.slice(7), config.jwt.secret) as any;
    const rows = await sql`SELECT id, email, name, role, tenant_id, is_active FROM tenant_users WHERE id = ${old.sub}`;
    if (!rows.length || !rows[0].is_active) { res.status(401).json({ error: 'User not found' }); return; }
    const u = rows[0];
    const token = jwt.sign(
      { sub: u.id, email: u.email, role: u.role, tenant_id: u.tenant_id },
      config.jwt.secret,
      { expiresIn: config.jwt.expiresIn } as any
    );
    res.json({ token });
  } catch {
    res.status(401).json({ error: 'Invalid token' });
  }
});

// ── POST /erp/auth/forgot-password ───────────────────────────────
router.post('/forgot-password', async (req: Request, res: Response): Promise<void> => {
  // In production: generate reset token, send email. Here we acknowledge safely.
  res.json({ message: 'If that email exists, a reset link has been sent.' });
});

export default router;
