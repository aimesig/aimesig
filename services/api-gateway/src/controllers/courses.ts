import { Router, Request, Response } from 'express';
import { sql } from '../utils/db';

const router = Router();

// ── COURSES ──────────────────────────────────────────────────────

// GET /erp/courses
router.get('/', async (req: Request, res: Response): Promise<void> => {
  const rows = await sql`
    SELECT c.*, COUNT(b.id) as batch_count
    FROM   courses c
    LEFT JOIN batches b ON b.course_id = c.id
    WHERE  c.tenant_id = ${req.tenantId!}
    GROUP  BY c.id
    ORDER  BY c.created_at DESC
  `;
  res.json(rows);
});

// POST /erp/courses
router.post('/', async (req: Request, res: Response): Promise<void> => {
  const { name, code, description, category, duration, capacity, fee } = req.body;
  if (!name) { res.status(400).json({ error: 'name is required' }); return; }
  const [row] = await sql`
    INSERT INTO courses (tenant_id, name, code, description, category, duration, capacity, fee)
    VALUES (${req.tenantId!}, ${name}, ${code || null}, ${description || null},
            ${category || null}, ${duration || null}, ${capacity || null}, ${fee || 0})
    RETURNING *
  `;
  res.status(201).json(row);
});

// GET /erp/courses/:id
router.get('/:id', async (req: Request, res: Response): Promise<void> => {
  const [row] = await sql`
    SELECT * FROM courses WHERE id = ${req.params.id} AND tenant_id = ${req.tenantId!}
  `;
  if (!row) { res.status(404).json({ error: 'Course not found' }); return; }
  res.json(row);
});

// PATCH /erp/courses/:id
router.patch('/:id', async (req: Request, res: Response): Promise<void> => {
  const { name, code, description, category, duration, capacity, fee, status } = req.body;
  const [row] = await sql`
    UPDATE courses SET
      name        = COALESCE(${name        || null}, name),
      code        = COALESCE(${code        || null}, code),
      description = COALESCE(${description || null}, description),
      category    = COALESCE(${category    || null}, category),
      duration    = COALESCE(${duration    || null}, duration),
      capacity    = COALESCE(${capacity    || null}::int, capacity),
      fee         = COALESCE(${fee         || null}::numeric, fee),
      status      = COALESCE(${status      || null}, status),
      updated_at  = NOW()
    WHERE id = ${req.params.id} AND tenant_id = ${req.tenantId!}
    RETURNING *
  `;
  if (!row) { res.status(404).json({ error: 'Course not found' }); return; }
  res.json(row);
});

// DELETE /erp/courses/:id
router.delete('/:id', async (req: Request, res: Response): Promise<void> => {
  await sql`DELETE FROM courses WHERE id = ${req.params.id} AND tenant_id = ${req.tenantId!}`;
  res.status(204).send();
});

// POST /erp/courses/:id/publish
router.post('/:id/publish', async (req: Request, res: Response): Promise<void> => {
  const [row] = await sql`
    UPDATE courses SET status = 'active', updated_at = NOW()
    WHERE id = ${req.params.id} AND tenant_id = ${req.tenantId!}
    RETURNING *
  `;
  if (!row) { res.status(404).json({ error: 'Course not found' }); return; }
  res.json(row);
});

// ── BATCHES ───────────────────────────────────────────────────────

// GET /erp/courses/:id/batches
router.get('/:id/batches', async (req: Request, res: Response): Promise<void> => {
  const rows = await sql`
    SELECT b.*, COUNT(e.id) as enrolled_count
    FROM   batches b
    LEFT JOIN enrollments e ON e.batch_id = b.id AND e.status = 'active'
    WHERE  b.course_id = ${req.params.id} AND b.tenant_id = ${req.tenantId!}
    GROUP  BY b.id ORDER BY b.created_at DESC
  `;
  res.json(rows);
});

// POST /erp/courses/:id/batches
router.post('/:id/batches', async (req: Request, res: Response): Promise<void> => {
  const { name, start_date, end_date, capacity } = req.body;
  if (!name) { res.status(400).json({ error: 'name is required' }); return; }
  const [row] = await sql`
    INSERT INTO batches (tenant_id, course_id, name, start_date, end_date, capacity)
    VALUES (${req.tenantId!}, ${req.params.id}, ${name},
            ${start_date || null}, ${end_date || null}, ${capacity || null})
    RETURNING *
  `;
  res.status(201).json(row);
});

// PATCH /erp/courses/:id/batches/:batchId
router.patch('/:id/batches/:batchId', async (req: Request, res: Response): Promise<void> => {
  const { name, start_date, end_date, capacity, status } = req.body;
  const [row] = await sql`
    UPDATE batches SET
      name       = COALESCE(${name       || null}, name),
      start_date = COALESCE(${start_date || null}::date, start_date),
      end_date   = COALESCE(${end_date   || null}::date, end_date),
      capacity   = COALESCE(${capacity   || null}::int, capacity),
      status     = COALESCE(${status     || null}, status)
    WHERE id = ${req.params.batchId} AND course_id = ${req.params.id} AND tenant_id = ${req.tenantId!}
    RETURNING *
  `;
  if (!row) { res.status(404).json({ error: 'Batch not found' }); return; }
  res.json(row);
});

// GET /erp/courses/:id/members
router.get('/:id/members', async (req: Request, res: Response): Promise<void> => {
  const rows = await sql`
    SELECT m.id, m.name, m.email, m.phone,
           e.enrolled_on, e.status as enrollment_status, b.name as batch_name
    FROM   enrollments e
    JOIN   members m ON m.id = e.member_id
    JOIN   batches b ON b.id = e.batch_id
    WHERE  b.course_id = ${req.params.id} AND e.tenant_id = ${req.tenantId!}
    ORDER  BY m.name
  `;
  res.json(rows);
});

export default router;
