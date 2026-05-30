import { Router, Request, Response } from 'express';
import { sql } from '../utils/db';

const router = Router();

// GET /erp/admissions
router.get('/', async (req: Request, res: Response): Promise<void> => {
  const { stage, search } = req.query as Record<string, string>;
  const rows = await sql`
    SELECT l.*, c.name as course_name, s.name as assigned_to_name
    FROM   leads l
    LEFT JOIN courses c ON c.id = l.course_id
    LEFT JOIN staff   s ON s.id = l.assigned_to
    WHERE  l.tenant_id = ${req.tenantId!}
      AND  (${stage  || null}::text IS NULL OR l.stage = ${stage  || null})
      AND  (${search || null}::text IS NULL
            OR l.name  ILIKE ${'%' + (search || '') + '%'}
            OR l.phone ILIKE ${'%' + (search || '') + '%'})
    ORDER  BY l.created_at DESC
  `;
  res.json(rows);
});

// POST /erp/admissions
router.post('/', async (req: Request, res: Response): Promise<void> => {
  const { name, email, phone, source, course_id, notes, assigned_to } = req.body;
  if (!name) { res.status(400).json({ error: 'name required' }); return; }
  const [row] = await sql`
    INSERT INTO leads (tenant_id, name, email, phone, source, course_id, notes, assigned_to)
    VALUES (${req.tenantId!}, ${name}, ${email || null}, ${phone || null},
            ${source || null}, ${course_id || null}, ${notes || null}, ${assigned_to || null})
    RETURNING *
  `;
  res.status(201).json(row);
});

// GET /erp/admissions/pipeline
router.get('/pipeline', async (req: Request, res: Response): Promise<void> => {
  const rows = await sql`
    SELECT stage, COUNT(*) as count
    FROM   leads WHERE tenant_id = ${req.tenantId!}
    GROUP  BY stage ORDER BY stage
  `;
  res.json(rows);
});

// PATCH /erp/admissions/:id
router.patch('/:id', async (req: Request, res: Response): Promise<void> => {
  const { stage, notes, assigned_to } = req.body;
  const [row] = await sql`
    UPDATE leads SET
      stage       = COALESCE(${stage       || null}, stage),
      notes       = COALESCE(${notes       || null}, notes),
      assigned_to = COALESCE(${assigned_to || null}::uuid, assigned_to),
      updated_at  = NOW()
    WHERE id = ${req.params.id} AND tenant_id = ${req.tenantId!}
    RETURNING *
  `;
  if (!row) { res.status(404).json({ error: 'Lead not found' }); return; }
  res.json(row);
});

// POST /erp/admissions/:id/convert — convert lead → member
router.post('/:id/convert', async (req: Request, res: Response): Promise<void> => {
  const [lead] = await sql`
    SELECT * FROM leads WHERE id = ${req.params.id} AND tenant_id = ${req.tenantId!}
  `;
  if (!lead) { res.status(404).json({ error: 'Lead not found' }); return; }
  try {
    const [member] = await sql`
      INSERT INTO members (tenant_id, name, email, phone)
      VALUES (${req.tenantId!}, ${lead.name}, ${lead.email || null}, ${lead.phone || null})
      RETURNING *
    `;
    await sql`
      UPDATE leads
      SET stage = 'converted', converted_at = NOW(), member_id = ${member.id}, updated_at = NOW()
      WHERE id = ${req.params.id}
    `;
    res.status(201).json({ member, message: 'Lead converted to member' });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
