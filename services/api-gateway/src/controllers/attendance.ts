import { Router, Request, Response } from 'express';
import { sql } from '../../utils/db';

const router = Router();

// POST /erp/attendance/mark  — single
router.post('/mark', async (req: Request, res: Response): Promise<void> => {
  const { member_id, staff_id, slot_id, date, status, type, note } = req.body;
  if (!date || !status) { res.status(400).json({ error: 'date and status required' }); return; }
  const t = type || (member_id ? 'member' : 'staff');
  try {
    const [row] = await sql`
      INSERT INTO attendance (tenant_id, slot_id, member_id, staff_id, type, status, date, note, marked_by)
      VALUES (${req.tenantId!}, ${slot_id||null}, ${member_id||null}, ${staff_id||null},
              ${t}, ${status}, ${date}, ${note||null}, ${req.tenantUser!.id})
      ON CONFLICT DO NOTHING
      RETURNING *
    `;
    res.status(201).json(row || { message: 'Already marked' });
  } catch (err: any) { res.status(500).json({ error: err.message }); }
});

// POST /erp/attendance/bulk-mark
router.post('/bulk-mark', async (req: Request, res: Response): Promise<void> => {
  const { records } = req.body;  // [{member_id, date, status, slot_id?}]
  if (!Array.isArray(records) || !records.length) {
    res.status(400).json({ error: 'records array required' }); return;
  }
  try {
    const results = await Promise.all(
      records.map((r: any) => sql`
        INSERT INTO attendance (tenant_id, slot_id, member_id, type, status, date, marked_by)
        VALUES (${req.tenantId!}, ${r.slot_id||null}, ${r.member_id}, 'member', ${r.status||'present'}, ${r.date}, ${req.tenantUser!.id})
        ON CONFLICT DO NOTHING RETURNING id
      `)
    );
    res.json({ marked: results.filter(r => r.length).length, total: records.length });
  } catch (err: any) { res.status(500).json({ error: err.message }); }
});

// GET /erp/attendance/session/:slotId
router.get('/session/:slotId', async (req: Request, res: Response): Promise<void> => {
  const rows = await sql`
    SELECT a.*, m.name as member_name
    FROM   attendance a
    LEFT JOIN members m ON m.id = a.member_id
    WHERE  a.slot_id = ${req.params.slotId} AND a.tenant_id = ${req.tenantId!}
  `;
  res.json(rows);
});

// GET /erp/attendance/member/:memberId
router.get('/member/:memberId', async (req: Request, res: Response): Promise<void> => {
  const { from, to } = req.query as Record<string, string>;
  const rows = await sql`
    SELECT a.*, s.start_time, s.end_time, b.name as batch_name
    FROM   attendance a
    LEFT JOIN schedule_slots s ON s.id = a.slot_id
    LEFT JOIN batches b ON b.id = s.batch_id
    WHERE  a.member_id = ${req.params.memberId} AND a.tenant_id = ${req.tenantId!}
      AND  (${from||null}::date IS NULL OR a.date >= ${from||null}::date)
      AND  (${to||null}::date IS NULL OR a.date <= ${to||null}::date)
    ORDER  BY a.date DESC
  `;
  res.json(rows);
});

// GET /erp/attendance/report
router.get('/report', async (req: Request, res: Response): Promise<void> => {
  const { batch_id, from, to } = req.query as Record<string, string>;
  const rows = await sql`
    SELECT
      m.id, m.name,
      COUNT(*) FILTER (WHERE a.status = 'present') as present,
      COUNT(*) FILTER (WHERE a.status = 'absent')  as absent,
      COUNT(*) FILTER (WHERE a.status = 'late')    as late,
      COUNT(*)                                      as total,
      ROUND(100.0 * COUNT(*) FILTER (WHERE a.status = 'present') / NULLIF(COUNT(*),0), 1) as pct
    FROM   attendance a
    JOIN   members m ON m.id = a.member_id
    LEFT JOIN schedule_slots s ON s.id = a.slot_id
    WHERE  a.tenant_id = ${req.tenantId!} AND a.type = 'member'
      AND  (${batch_id||null}::uuid IS NULL OR s.batch_id = ${batch_id||null}::uuid)
      AND  (${from||null}::date IS NULL OR a.date >= ${from||null}::date)
      AND  (${to||null}::date IS NULL OR a.date <= ${to||null}::date)
    GROUP  BY m.id, m.name
    ORDER  BY pct DESC
  `;
  res.json(rows);
});

export default router;
