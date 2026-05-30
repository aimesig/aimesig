import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../config';
import { logger } from '../utils/logger';

export interface JwtPayload {
  sub: string;
  email: string;
  role: string;
  iat: number;
  exp: number;
}

declare global {
  namespace Express {
    interface Request {
      user?: JwtPayload;
      requestId?: string;
    }
  }
}

/**
 * Verifies the Bearer JWT in Authorization header.
 * Attaches decoded payload to req.user.
 */
export function authenticate(req: Request, res: Response, next: NextFunction): void {
  const header = req.headers['authorization'];
  if (!header?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing or malformed Authorization header' });
    return;
  }

  const token = header.slice(7);
  try {
    const payload = jwt.verify(token, config.jwt.secret) as JwtPayload;
    req.user = payload;
    // Forward user identity to upstream services
    req.headers['x-user-id']    = payload.sub;
    req.headers['x-user-email'] = payload.email;
    req.headers['x-user-role']  = payload.role;
    next();
  } catch (err) {
    logger.warn('JWT verification failed', { error: (err as Error).message });
    res.status(401).json({ error: 'Invalid or expired token' });
  }
}

/**
 * Role-based access guard. Use after authenticate().
 */
export function requireRole(...roles: string[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user) {
      res.status(401).json({ error: 'Not authenticated' });
      return;
    }
    if (!roles.includes(req.user.role)) {
      res.status(403).json({ error: `Role '${req.user.role}' is not permitted here` });
      return;
    }
    next();
  };
}
