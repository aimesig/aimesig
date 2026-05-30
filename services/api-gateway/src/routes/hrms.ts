import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth';
import { makeProxy } from '../utils/proxy';
import { config } from '../config';

const router = Router();

/**
 * /hrms — Human Resource Management System
 *
 * Requires authentication + one of: admin, hr, hr_manager
 */
router.use(
  authenticate,
  requireRole('admin', 'hr', 'hr_manager'),
  makeProxy(config.upstreams.hrms, '/hrms')
);

export default router;
