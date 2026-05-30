import { Router, Request, Response } from 'express';
import { sql } from '../../utils/db';
import { logger } from '../../utils/logger';

const router = Router();

// GET /erp/members
router.get('/', async (req: Request, res: Response): Promise<void> => {
  const tid = req.tenantId!;
  const { status, search, page = '1', limit = '20' } = req.query as Record<string, string>;
  const offset = (parseInt(page) - 1) * parseInt(limit);
  try {
    const rows = await sql`
      SELECT id, member_no, name, email, phone, status, joined_on, photo_url
      FROM   members
      WHERE  tenant_id = ${tid}
        AND  (${status || null}::text IS NULL OR status = ${status || null})
        AND  (${search || null}::text IS NULL OR name ILIKE ${'%' + (search || '') + '%'} OR email ILIKE ${'%' + (search || '') + '%'} OR phone ILIKE ${'%' + (search || '') + '%'})
      ORDER  BY created_at DESC
      LIMIT  ${parseInt(limit)} OFFSET ${offset}
    `;
    const [{ count }] = await sql`SELECT COUNT(*) FROM members WHERE tenant_id = ${tid}`;
    res.json({ data: rows, total: parseInt(count), page: parseInt(page), limit: parseInt(limit) });
  } catch (err: any) { logger.error('members list', { error: err.message }); res.status(500).json({ error: 'Failed' }); }
});

// POST /erp/members
router.post('/', async (req: Request, res: Response): Promise<void> => {
  const tid = req.tenantId!;
  const { name, email, phone, dob, gender, address, guardian, member_no, photo_url, metadata } = req.body;
  if (!name) { res.status(400).json({ error: 'name is required' }); return; }
  try {
    const [row] = await sql`
      INSERT INTO members (tenant_id, name, email, phone, dob, gender, address, guardian, member_no, photo_url, metadata)
      VALUES (${tid}, ${name}, ${email||null}, ${phone||null}, ${dob||null}, ${gender||null},
              ${JSON.stringify(address||{})}::jsonb, ${JSON.stringify(guardian||{})}::jsonb,
              ${member_no||null}, ${photo_url||null}, ${JSON.stringify(metadata||{})}::jsonb)
      RETURNING *
    `;
    res.status(201).json(row);
  } catch (err: any) { res.status(500).json({ error: err.message }); }
});

// GET /erp/members/:id
router.get('/:id', async (req: Request, res: Response): Promise<void> => {
  const [row] = await sql`SELECT * FROM members WHERE id = ${req.params.id} AND tenant_id = ${req.tenantId!}`;
  if (!row) { res.status(404).json({ error: 'Member not found' }); return; }
  res.json(row);
});

// PATCH /erp/members/:id
router.patch('/:id', async (req: Request, res: Response): Promise<void> => {
  const { name, email, phone, dob, gender, address, guardian, status, photo_url, metadata } = req.body;
  try {
    const [row] = await sql`
      UPDATE members SET
        name       = COALESCE(${name||null}, name),
        email      = COALESCE(${email||null}, email),
        phone      = COALESCE(${phone||null}, phone),
        dob        = COALESCE(${dob||null}::date, dob),
        gender     = COALESCE(${gender||null}, gender),
        address    = COALESCE(${address ? JSON.stringify(address) : null}::jsonb, address),
        guardian   = COALESCE(${guardian ? JSON.stringify(guardian) : null}::jsonb, guardian),
        status     = COALESCE(${status||null}, status),
        photo_url  = COALESCE(${photo_url||null}, photo_url),
        metadata   = COALESCE(${metadata ? JSON.stringify(metadata) : null}::jsonb, metadata),
        updated_at = NOW()
      WHERE id = ${req.params.id} AND tenant_id = ${req.tenantId!}
      RETURNING *
    `;
    if (!row) { res.status(404).json({ error: 'Member not found' }); return; }
    res.json(row);
  } catch (err: any) { res.status(500).json({ error: err.message }); }
});

// DELETE /erp/members/:id
router.delete('/:id', async (req: Request, res: Response): Promise<void> => {
  await sql`DELETE FROM members WHERE id = ${req.params.id} AND tenant_id = ${req.tenantId!}`;
  res.status(204).send();
});

// GET /erp/members/:id/enrollments
router.get('/:id/enrollments', async (req: Request, res: Response): Promise<void> => {
  const rows = await sql`
    SELECT e.*, b.name as batch_name, c.name as course_name
    FROM   enrollments e
    JOIN   batches b ON b.id = e.batch_id
    JOIN   courses c ON c.id = b.course_id
    WHERE  e.member_id = ${req.params.id} AND e.tenant_id = ${req.tenantId!}
    ORDER  BY e.enrolled_on DESC
  `;
  res.json(rows);
});

// POST /erp/members/:id/enroll
router.post('/:id/enroll', async (req: Request, res: Response): Promise<void> => {
  const { batch_id } = req.body;
  if (!batch_id) { res.status(400).json({ error: 'batch_id required' }); return; }
  try {
    const [row] = await sql`
      INSERT INTO enrollments (tenant_id, member_id, batch_id)
      VALUES (${req.tenantId!}, ${req.params.id}, ${batch_id})
      ON CONFLICT (member_id, batch_id) DO UPDATE SET status = 'active'
      RETURNING *
    `;
    res.status(201).json(row);
  } catch (err: any) { res.status(500).json({ error: err.message }); }
});

// GET /erp/members/:id/payments
router.get('/:id/payments', async (req: Request, res: Response): Promise<void> => {
  const rows = await sql`
    SELECT * FROM payments WHERE member_id = ${req.params.id} AND tenant_id = ${req.tenantId!} ORDER BY paid_on DESC
  `;
  res.json(rows);
});

export default router;
