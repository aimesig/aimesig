import { Router, Request, Response } from 'express';
import { sql } from '../utils/db';

const router = Router();

// GET /erp/schedule/slots
router.get('/slots', async (req: Request, res: Response): Promise<void> => {
  const { batch_id, staff_id, date } = req.query as Record<string, string>;
  const rows = await sql`
    SELECT s.*, b.name as batch_name, st.name as staff_name, c.name as course_name
    FROM   schedule_slots s
    LEFT JOIN batches b  ON b.id  = s.batch_id
    LEFT JOIN courses c  ON c.id  = b.course_id
    LEFT JOIN staff   st ON st.id = s.staff_id
    WHERE  s.tenant_id = ${req.tenantId!}
      AND  (${batch_id || null}::uuid IS NULL OR s.batch_id = ${batch_id || null}::uuid)
      AND  (${staff_id || null}::uuid IS NULL OR s.staff_id = ${staff_id || null}::uuid)
      AND  (${date     || null}::date IS NULL OR s.slot_date = ${date    || null}::date)
      AND  s.is_cancelled = FALSE
    ORDER  BY s.day_of_week, s.start_time
  `;
  res.json(rows);
});

// POST /erp/schedule/slots
router.post('/slots', async (req: Request, res: Response): Promise<void> => {
  const { batch_id, staff_id, room, day_of_week, slot_date, start_time, end_time } = req.body;
  if (!start_time || !end_time) {
    res.status(400).json({ error: 'start_time and end_time required' }); return;
  }
  const [row] = await sql`
    INSERT INTO schedule_slots
      (tenant_id, batch_id, staff_id, room, day_of_week, slot_date, start_time, end_time)
    VALUES
      (${req.tenantId!}, ${batch_id || null}, ${staff_id || null}, ${room || null},
       ${day_of_week ?? null}, ${slot_date || null}, ${start_time}, ${end_time})
    RETURNING *
  `;
  res.status(201).json(row);
});

// PATCH /erp/schedule/slots/:id
router.patch('/slots/:id', async (req: Request, res: Response): Promise<void> => {
  const { staff_id, room, start_time, end_time, is_cancelled } = req.body;
  const [row] = await sql`
    UPDATE schedule_slots SET
      staff_id     = COALESCE(${staff_id    || null}::uuid, staff_id),
      room         = COALESCE(${room        || null}, room),
      start_time   = COALESCE(${start_time  || null}::time, start_time),
      end_time     = COALESCE(${end_time    || null}::time, end_time),
      is_cancelled = COALESCE(${is_cancelled ?? null}::boolean, is_cancelled)
    WHERE id = ${req.params.id} AND tenant_id = ${req.tenantId!}
    RETURNING *
  `;
  if (!row) { res.status(404).json({ error: 'Slot not found' }); return; }
  res.json(row);
});

// DELETE /erp/schedule/slots/:id
router.delete('/slots/:id', async (req: Request, res: Response): Promise<void> => {
  await sql`
    DELETE FROM schedule_slots WHERE id = ${req.params.id} AND tenant_id = ${req.tenantId!}
  `;
  res.status(204).send();
});

// GET /erp/schedule/conflicts
router.get('/conflicts', async (req: Request, res: Response): Promise<void> => {
  const rows = await sql`
    SELECT a.id as slot_a, b.id as slot_b, a.staff_id, a.room,
           a.day_of_week, a.start_time, b.start_time as b_start
    FROM   schedule_slots a
    JOIN   schedule_slots b ON a.tenant_id  = b.tenant_id
      AND  a.id            < b.id
      AND  a.day_of_week   = b.day_of_week
      AND  a.is_cancelled  = FALSE
      AND  b.is_cancelled  = FALSE
      AND  (a.staff_id = b.staff_id OR (a.room IS NOT NULL AND a.room = b.room))
      AND  a.start_time < b.end_time
      AND  a.end_time   > b.start_time
    WHERE  a.tenant_id = ${req.tenantId!}
  `;
  res.json({ conflicts: rows, count: rows.length });
});

export default router;
