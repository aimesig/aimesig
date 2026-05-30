import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { makeProxy } from '../utils/proxy';
import { config } from '../config';

const router = Router();

/**
 * /websites — Website builder / CMS service
 *
 * All endpoints require a valid JWT.
 */
router.use(
  authenticate,
  makeProxy(config.upstreams.websites, '/websites')
);

export default router;
