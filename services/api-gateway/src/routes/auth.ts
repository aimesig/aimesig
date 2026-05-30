import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { config } from '../config';
import { makeProxy } from '../utils/proxy';

const router = Router();

/**
 * /auth — Public auth service (login, register, refresh, logout, verify)
 *
 * This route intentionally has NO authenticate() guard so clients can reach
 * the login/register endpoints.  A tighter rate-limit protects against brute-force.
 */
const authLimiter = rateLimit({
  windowMs: config.rateLimit.windowMs,
  max:      config.rateLimit.authMax,
  standardHeaders: true,
  legacyHeaders:   false,
  message: { error: 'Too many auth requests, please slow down.' },
});

router.use(authLimiter, makeProxy(config.upstreams.auth, '/auth'));

export default router;
