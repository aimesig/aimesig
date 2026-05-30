import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { resolveTenant, requireErpRole } from '../middleware/tenant';

// ERP sub-controllers (all query Neon DB directly — no upstream service)
import admissionsRouter from '../controllers/admissions';
import attendanceRouter from '../controllers/attendance';
import coursesRouter    from '../controllers/courses';
import financeRouter    from '../controllers/finance';
import membersRouter    from '../controllers/members';
import scheduleRouter   from '../controllers/schedule';
import staffRouter      from '../controllers/staff';
import erpAuthRouter    from '../controllers/auth';

const router = Router();

// ── Public ERP auth (register / login / refresh / forgot-password) ──
// No authenticate() here — these ARE the login endpoints.
router.use('/auth', erpAuthRouter);

// ── All other ERP routes require a valid JWT + active tenant ────────
router.use(
  authenticate,
  resolveTenant,
  requireErpRole('tenant_admin', 'admin', 'manager', 'erp_user', 'hr', 'hr_manager'),
);

router.use('/admissions', admissionsRouter);
router.use('/attendance',  attendanceRouter);
router.use('/courses',     coursesRouter);
router.use('/finance',     financeRouter);
router.use('/members',     membersRouter);
router.use('/schedule',    scheduleRouter);
router.use('/staff',       staffRouter);

export default router;
