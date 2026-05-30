import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { resolveTenant, requireErpRole } from '../middleware/tenant';

import admissionsRouter from '../controllers/admissions';
import attendanceRouter from '../controllers/attendance';
import coursesRouter    from '../controllers/courses';
import financeRouter    from '../controllers/finance';
import membersRouter    from '../controllers/members';
import scheduleRouter   from '../controllers/schedule';
import staffRouter      from '../controllers/staff';
import erpAuthRouter    from '../controllers/auth';

const router = Router();

// ── Public: no JWT required ──────────────────────────────────────
router.use('/auth', erpAuthRouter);

// ── Protected: JWT + active tenant + role check ──────────────────
const guard = [
  authenticate,
  resolveTenant,
  requireErpRole('tenant_admin', 'admin', 'manager', 'erp_user', 'hr', 'hr_manager'),
];

router.use('/admissions', guard, admissionsRouter);
router.use('/attendance',  guard, attendanceRouter);
router.use('/courses',     guard, coursesRouter);
router.use('/finance',     guard, financeRouter);
router.use('/members',     guard, membersRouter);
router.use('/schedule',    guard, scheduleRouter);
router.use('/staff',       guard, staffRouter);

export default router;
