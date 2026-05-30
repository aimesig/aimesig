import { Request, Response, NextFunction } from 'express';
import { sql } from '../utils/db';
import { logger } from '../utils/logger';

export interface TenantUser {
  id: string;
  tenant_id: string;
  email: string;
  name: string;
  role: string;
}

declare global {
  namespace Express {
    interface Request {
      tenantUser?: TenantUser;
      tenantId?: string;
    }
  }
}

/**
 * Resolves tenant context from the already-verified JWT (req.user).
 * Confirms the account and tenant are both active, then attaches
 * req.tenantUser and req.tenantId for use by downstream controllers.
 *
 * Must be called AFTER authenticate().
 */
export async function resolveTenant(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  if (!req.user) {
    res.status(401).json({ error: 'Not authenticated' });
    return;
  }
  try {
    const rows = await sql`
      SELECT tu.id, tu.tenant_id, tu.email, tu.name, tu.role
      FROM   tenant_users tu
      JOIN   tenants t ON t.id = tu.tenant_id
      WHERE  tu.id        = ${req.user.sub}
        AND  tu.is_active = TRUE
        AND  t.is_active  = TRUE
    `;
    if (!rows.length) {
      res.status(403).json({ error: 'Account inactive or tenant suspended' });
      return;
    }
    req.tenantUser = rows[0] as TenantUser;
    req.tenantId   = rows[0].tenant_id;
    next();
  } catch (err) {
    logger.error('resolveTenant error', { error: (err as Error).message });
    res.status(500).json({ error: 'Internal error resolving tenant' });
  }
}

/**
 * Role-based ERP guard. Must be called after resolveTenant().
 */
export function requireErpRole(...roles: string[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.tenantUser) {
      res.status(401).json({ error: 'Not authenticated' });
      return;
    }
    if (!roles.includes(req.tenantUser.role)) {
      res
        .status(403)
        .json({ error: `Role '${req.tenantUser.role}' cannot access this resource` });
      return;
    }
    next();
  };
}
