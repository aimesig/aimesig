import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../config';
import { sql } from '../utils/db';

// ─────────────────────────────────────────────────────────────────────────────
// Extend Express types
// ─────────────────────────────────────────────────────────────────────────────

export interface TenantUserPayload {
  id: string;
  email: string;
  name: string;
  role: 'tenant_admin' | 'staff' | 'member' | string;
  tenant_id: string;
  is_active: boolean;
  must_change_password: boolean;
  linked_staff_id:  string | null;
  linked_member_id: string | null;
}

declare global {
  namespace Express {
    interface Request {
      tenantId?: string;
      tenantUser?: TenantUserPayload;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// authenticate  — verify JWT and attach req.tenantId + req.tenantUser
// ─────────────────────────────────────────────────────────────────────────────
export async function authenticate(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const auth = req.headers['authorization'];
  if (!auth?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Authentication required' });
    return;
  }

  try {
    const payload = jwt.verify(auth.slice(7), config.jwt.secret) as any;

    // Always do a DB round-trip so disabled accounts are rejected immediately
    const [u] = await sql`
      SELECT
        tu.id, tu.email, tu.name, tu.role, tu.tenant_id,
        tu.is_active, tu.must_change_password,
        tu.linked_staff_id, tu.linked_member_id,
        t.is_active AS tenant_active
      FROM   tenant_users tu
      JOIN   tenants t ON t.id = tu.tenant_id
      WHERE  tu.id = ${payload.sub}
    `;

    if (!u)               { res.status(401).json({ error: 'User not found' });            return; }
    if (!u.is_active)     { res.status(403).json({ error: 'Account disabled' });          return; }
    if (!u.tenant_active) { res.status(403).json({ error: 'Organisation suspended' });    return; }

    req.tenantId   = u.tenant_id;
    req.tenantUser = {
      id:                  u.id,
      email:               u.email,
      name:                u.name,
      role:                u.role,
      tenant_id:           u.tenant_id,
      is_active:           u.is_active,
      must_change_password: u.must_change_password,
      linked_staff_id:     u.linked_staff_id  ?? null,
      linked_member_id:    u.linked_member_id ?? null,
    };

    next();
  } catch (err: any) {
    if (err.name === 'TokenExpiredError') {
      res.status(401).json({ error: 'Token expired' });
    } else {
      res.status(401).json({ error: 'Invalid token' });
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// requireRole  — gate a route to specific roles
// Usage: router.post('/admin-only', authenticate, requireRole('tenant_admin'), handler)
// ─────────────────────────────────────────────────────────────────────────────
export function requireRole(...roles: string[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.tenantUser) {
      res.status(401).json({ error: 'Unauthenticated' });
      return;
    }
    if (!roles.includes(req.tenantUser.role)) {
      res.status(403).json({
        error: `Access denied. Required role(s): ${roles.join(', ')}`,
      });
      return;
    }
    next();
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// requirePasswordChange  — force first-login password update
// ─────────────────────────────────────────────────────────────────────────────
export function requirePasswordChange(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  if (req.tenantUser?.must_change_password) {
    // Allow only the change-password endpoint
    if (req.path !== '/change-password') {
      res.status(403).json({
        error: 'You must change your temporary password before continuing',
        must_change_password: true,
      });
      return;
    }
  }
  next();
}
