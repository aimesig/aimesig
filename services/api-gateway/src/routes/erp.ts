import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth';
import { makeProxy } from '../utils/proxy';
import { config } from '../config';

const router = Router();

/**
 * /erp — Enterprise Resource Planning service
 *
 * Requires authentication + one of: admin, manager, erp_user
 */
router.use(
  authenticate,
  requireRole('admin', 'manager', 'erp_user'),
  makeProxy(config.upstreams.erp, '/erp')
);

export default router;
