import { Router, Request, Response } from 'express';
import { sql } from '../utils/db';

const router = Router();

// GET /erp/staff
router.get('/', async (req: Request, res: Response): Promise<void> => {
  const { status, search } = req.query as Record<string, string>;
  const rows = await sql`
    SELECT id, employee_no, name, email, phone, role, department, status, joined_on, photo_url
    FROM   staff
    WHERE  tenant_id = ${req.tenantId!}
      AND  (${status || null}::text IS NULL OR status = ${status || null})
      AND  (${search || null}::text IS NULL OR name ILIKE ${'%' + (search || '') + '%'})
    ORDER  BY name
  `;
  res.json(rows);
});

// POST /erp/staff
router.post('/', async (req: Request, res: Response): Promise<void> => {
  const { name, email, phone, role, department, dob, gender, salary, employee_no, photo_url } =
    req.body;
  if (!name) { res.status(400).json({ error: 'name is required' }); return; }
  const [row] = await sql`
    INSERT INTO staff
      (tenant_id, name, email, phone, role, department, dob, gender, salary, employee_no, photo_url)
    VALUES
      (${req.tenantId!}, ${name}, ${email || null}, ${phone || null},
       ${role || 'instructor'}, ${department || null}, ${dob || null},
       ${gender || null}, ${salary || null}, ${employee_no || null}, ${photo_url || null})
    RETURNING *
  `;
  res.status(201).json(row);
});

// GET /erp/staff/:id
router.get('/:id', async (req: Request, res: Response): Promise<void> => {
  const [row] = await sql`
    SELECT * FROM staff WHERE id = ${req.params.id} AND tenant_id = ${req.tenantId!}
  `;
  if (!row) { res.status(404).json({ error: 'Staff not found' }); return; }
  res.json(row);
});

// PATCH /erp/staff/:id
router.patch('/:id', async (req: Request, res: Response): Promise<void> => {
  const { name, email, phone, role, department, salary, status, photo_url } = req.body;
  const [row] = await sql`
    UPDATE staff SET
      name       = COALESCE(${name       || null}, name),
      email      = COALESCE(${email      || null}, email),
      phone      = COALESCE(${phone      || null}, phone),
      role       = COALESCE(${role       || null}, role),
      department = COALESCE(${department || null}, department),
      salary     = COALESCE(${salary     || null}::numeric, salary),
      status     = COALESCE(${status     || null}, status),
      photo_url  = COALESCE(${photo_url  || null}, photo_url),
      updated_at = NOW()
    WHERE id = ${req.params.id} AND tenant_id = ${req.tenantId!}
    RETURNING *
  `;
  if (!row) { res.status(404).json({ error: 'Staff not found' }); return; }
  res.json(row);
});

// DELETE /erp/staff/:id
router.delete('/:id', async (req: Request, res: Response): Promise<void> => {
  await sql`DELETE FROM staff WHERE id = ${req.params.id} AND tenant_id = ${req.tenantId!}`;
  res.status(204).send();
});

// GET /erp/staff/:id/schedule
router.get('/:id/schedule', async (req: Request, res: Response): Promise<void> => {
  const rows = await sql`
    SELECT s.*, b.name as batch_name, c.name as course_name
    FROM   schedule_slots s
    LEFT JOIN batches b ON b.id = s.batch_id
    LEFT JOIN courses c ON c.id = b.course_id
    WHERE  s.staff_id = ${req.params.id} AND s.tenant_id = ${req.tenantId!}
    ORDER  BY s.day_of_week, s.start_time
  `;
  res.json(rows);
});

export default router;
