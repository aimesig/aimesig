import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { makeProxy } from '../utils/proxy';
import { config } from '../config';

const router = Router();

/**
 * /chat — Real-time chat / messaging service
 *
 * All endpoints require a valid JWT.
 * WebSocket upgrade is transparently proxied (ws: true).
 */
router.use(
  authenticate,
  makeProxy(config.upstreams.chat, '/chat', { ws: true })
);

export default router;
