import { Router, Request, Response } from 'express';
import { sql } from '../utils/db';
import { logger } from '../utils/logger';

const router = Router();

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/** For a staff user, verify the given batch is assigned to them */
async function assertStaffCanAccessBatch(
  tenantId: string,
  staffId: string,
  batchId: string,
): Promise<boolean> {
  const rows = await sql`
    SELECT id FROM batches
    WHERE id = ${batchId} AND tenant_id = ${tenantId} AND staff_id = ${staffId}
  `;
  return rows.length > 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /erp/attendance/my-batches  (staff: list their assigned active batches)
// ─────────────────────────────────────────────────────────────────────────────
router.get('/my-batches', async (req: Request, res: Response): Promise<void> => {
  const linkedStaffId = req.tenantUser?.linked_staff_id;
  if (!linkedStaffId) {
    res.status(403).json({ error: 'Only staff accounts can access this endpoint' });
    return;
  }

  try {
    const rows = await sql`
      SELECT
        b.id,
        b.name          AS batch_name,
        b.schedule_time,
        b.start_date,
        b.end_date,
        b.status        AS batch_status,
        c.id            AS course_id,
        c.name          AS course_name,
        COUNT(DISTINCT e.id) AS enrolled_count
      FROM   batches     b
      JOIN   courses     c ON c.id = b.course_id
      LEFT JOIN enrollments e ON e.batch_id = b.id AND e.status = 'active'
      WHERE  b.staff_id  = ${linkedStaffId}
        AND  b.tenant_id = ${req.tenantId!}
        AND  b.status    = 'active'
      GROUP  BY b.id, c.id
      ORDER  BY b.name
    `;
    res.json(rows);
  } catch (err: any) {
    logger.error('my-batches error', { error: err.message });
    res.status(500).json({ error: 'Failed to fetch batches' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /erp/attendance/batch/:batchId/members
//   Returns enrolled members + today's (or ?date=) attendance status
// ─────────────────────────────────────────────────────────────────────────────
router.get('/batch/:batchId/members', async (req: Request, res: Response): Promise<void> => {
  const role          = req.tenantUser?.role;
  const linkedStaffId = req.tenantUser?.linked_staff_id;

  // Staff can only access their own batches
  if (role === 'staff' && linkedStaffId) {
    const allowed = await assertStaffCanAccessBatch(req.tenantId!, linkedStaffId, req.params.batchId);
    if (!allowed) {
      res.status(403).json({ error: 'This batch is not assigned to you' });
      return;
    }
  }

  const targetDate = (req.query.date as string) || new Date().toISOString().substring(0, 10);

  try {
    const rows = await sql`
      SELECT
        m.id         AS member_id,
        m.name       AS member_name,
        m.member_no,
        m.photo_url,
        a.id         AS attendance_id,
        a.status     AS attendance_status,
        a.note,
        a.marked_by,
        a.updated_at AS marked_at
      FROM   enrollments e
      JOIN   members     m ON m.id = e.member_id
      LEFT JOIN attendance a
        ON  a.member_id = m.id
        AND a.tenant_id = ${req.tenantId!}
        AND a.date      = ${targetDate}::date
        AND a.batch_id  = ${req.params.batchId}::uuid
      WHERE  e.batch_id  = ${req.params.batchId}::uuid
        AND  e.tenant_id = ${req.tenantId!}
        AND  e.status    = 'active'
      ORDER  BY m.name
    `;
    res.json({ date: targetDate, batch_id: req.params.batchId, members: rows });
  } catch (err: any) {
    logger.error('batch members for attendance error', { error: err.message });
    res.status(500).json({ error: 'Failed to fetch members' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /erp/attendance/mark  (single record)
// ─────────────────────────────────────────────────────────────────────────────
router.post('/mark', async (req: Request, res: Response): Promise<void> => {
  const { member_id, staff_id, slot_id, batch_id, date, status, type, note } = req.body;

  if (!date)   { res.status(400).json({ error: 'date is required (YYYY-MM-DD)' }); return; }
  if (!status) { res.status(400).json({ error: 'status is required (present|absent|late|excused)' }); return; }

  const role          = req.tenantUser?.role;
  const linkedStaffId = req.tenantUser?.linked_staff_id;

  // Staff: verify the batch being marked is their assigned batch
  if (role === 'staff' && linkedStaffId && batch_id) {
    const allowed = await assertStaffCanAccessBatch(req.tenantId!, linkedStaffId, batch_id);
    if (!allowed) {
      res.status(403).json({ error: 'You can only mark attendance for your assigned batches' });
      return;
    }
  }

  const resolvedType = type || (member_id ? 'member' : 'staff');

  try {
    // Verify member enrollment if marking member attendance
    if (member_id && batch_id) {
      const [enrollment] = await sql`
        SELECT id FROM enrollments
        WHERE member_id = ${member_id}
          AND batch_id  = ${batch_id}
          AND tenant_id = ${req.tenantId!}
          AND status    = 'active'
      `;
      if (!enrollment) {
        res.status(400).json({ error: 'Member is not actively enrolled in this batch' });
        return;
      }
    }

    // Use a named constraint-based upsert — requires unique index:
    //   CREATE UNIQUE INDEX uq_attendance_batch_member_date
    //   ON attendance (tenant_id, batch_id, member_id, date)
    //   WHERE member_id IS NOT NULL;
    const [row] = await sql`
      INSERT INTO attendance
        (tenant_id, slot_id, batch_id, member_id, staff_id, type, status, date, note, marked_by)
      VALUES
        (${req.tenantId!}, ${slot_id ?? null}, ${batch_id ?? null},
         ${member_id ?? null}, ${staff_id ?? null},
         ${resolvedType}, ${status}, ${date}::date,
         ${note ?? null}, ${req.tenantUser!.id})
      ON CONFLICT (tenant_id, batch_id, member_id, date)
        DO UPDATE SET
          status     = EXCLUDED.status,
          note       = EXCLUDED.note,
          marked_by  = EXCLUDED.marked_by,
          updated_at = NOW()
      RETURNING *
    `;
    res.status(201).json(row);
  } catch (err: any) {
    logger.error('mark attendance error', { error: err.message });
    res.status(500).json({ error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /erp/attendance/bulk-mark  (mark full session for a batch)
// Body: { batch_id, date, records: [{ member_id, status, note? }] }
// ─────────────────────────────────────────────────────────────────────────────
router.post('/bulk-mark', async (req: Request, res: Response): Promise<void> => {
  const { batch_id, date, records } = req.body;

  if (!batch_id)                        { res.status(400).json({ error: 'batch_id is required' });          return; }
  if (!date)                            { res.status(400).json({ error: 'date is required (YYYY-MM-DD)' }); return; }
  if (!Array.isArray(records) || !records.length) {
    res.status(400).json({ error: 'records[] is required and must not be empty' });
    return;
  }

  const role          = req.tenantUser?.role;
  const linkedStaffId = req.tenantUser?.linked_staff_id;

  if (role === 'staff' && linkedStaffId) {
    const allowed = await assertStaffCanAccessBatch(req.tenantId!, linkedStaffId, batch_id);
    if (!allowed) {
      res.status(403).json({ error: 'You can only mark attendance for your assigned batches' });
      return;
    }
  }

  // Verify batch belongs to this tenant
  const [batch] = await sql`
    SELECT id FROM batches WHERE id = ${batch_id} AND tenant_id = ${req.tenantId!}
  `;
  if (!batch) { res.status(404).json({ error: 'Batch not found' }); return; }

  try {
    let markedCount = 0;
    const errors: any[] = [];

    for (const r of records as Array<{ member_id: string; status?: string; note?: string }>) {
      if (!r.member_id) continue;
      try {
        await sql`
          INSERT INTO attendance
            (tenant_id, batch_id, member_id, type, status, date, note, marked_by)
          VALUES
            (${req.tenantId!}, ${batch_id}, ${r.member_id},
             'member', ${r.status || 'present'}, ${date}::date,
             ${r.note ?? null}, ${req.tenantUser!.id})
          ON CONFLICT (tenant_id, batch_id, member_id, date)
            DO UPDATE SET
              status     = EXCLUDED.status,
              note       = EXCLUDED.note,
              marked_by  = EXCLUDED.marked_by,
              updated_at = NOW()
        `;
        markedCount++;
      } catch (e: any) {
        errors.push({ member_id: r.member_id, error: e.message });
      }
    }

    res.json({
      marked: markedCount,
      total:  records.length,
      errors: errors.length ? errors : undefined,
    });
  } catch (err: any) {
    logger.error('bulk-mark error', { error: err.message });
    res.status(500).json({ error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /erp/attendance/session/:slotId
// ─────────────────────────────────────────────────────────────────────────────
router.get('/session/:slotId', async (req: Request, res: Response): Promise<void> => {
  try {
    const rows = await sql`
      SELECT a.*, m.name AS member_name, m.member_no
      FROM   attendance a
      LEFT JOIN members m ON m.id = a.member_id
      WHERE  a.slot_id   = ${req.params.slotId}
        AND  a.tenant_id = ${req.tenantId!}
      ORDER  BY m.name
    `;
    res.json(rows);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /erp/attendance/member/:memberId
//   - Members can only see their own attendance
//   - Staff can see attendance for members in their batches
//   - Admins can see all
// ─────────────────────────────────────────────────────────────────────────────
router.get('/member/:memberId', async (req: Request, res: Response): Promise<void> => {
  const role            = req.tenantUser?.role;
  const linkedMemberId  = req.tenantUser?.linked_member_id;
  const linkedStaffId   = req.tenantUser?.linked_staff_id;

  // Members can only see their own data
  if (role === 'member' && linkedMemberId && linkedMemberId !== req.params.memberId) {
    res.status(403).json({ error: 'You can only view your own attendance' });
    return;
  }

  // Staff can only see members in their assigned batches
  if (role === 'staff' && linkedStaffId) {
    const [allowed] = await sql`
      SELECT 1 FROM enrollments e
      JOIN batches b ON b.id = e.batch_id
      WHERE e.member_id = ${req.params.memberId}
        AND b.staff_id  = ${linkedStaffId}
        AND e.tenant_id = ${req.tenantId!}
        AND e.status    = 'active'
      LIMIT 1
    `;
    if (!allowed) {
      res.status(403).json({ error: 'This member is not in any of your assigned batches' });
      return;
    }
  }

  const { from, to } = req.query as Record<string, string>;

  try {
    const rows = await sql`
      SELECT
        a.*,
        b.name AS batch_name,
        c.name AS course_name
      FROM   attendance a
      LEFT JOIN batches b ON b.id = a.batch_id
      LEFT JOIN courses c ON c.id = b.course_id
      WHERE  a.member_id  = ${req.params.memberId}
        AND  a.tenant_id  = ${req.tenantId!}
        AND  (${from ?? null}::date IS NULL OR a.date >= ${from ?? null}::date)
        AND  (${to   ?? null}::date IS NULL OR a.date <= ${to   ?? null}::date)
      ORDER  BY a.date DESC
    `;
    res.json(rows);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /erp/attendance/report
//   Summary report: per-member attendance stats within optional date range
// ─────────────────────────────────────────────────────────────────────────────
router.get('/report', async (req: Request, res: Response): Promise<void> => {
  const { batch_id, from, to } = req.query as Record<string, string>;
  const role          = req.tenantUser?.role;
  const linkedStaffId = req.tenantUser?.linked_staff_id;

  // Staff can only get reports for their batches
  if (role === 'staff' && linkedStaffId && batch_id) {
    const allowed = await assertStaffCanAccessBatch(req.tenantId!, linkedStaffId, batch_id);
    if (!allowed) {
      res.status(403).json({ error: 'You can only view reports for your assigned batches' });
      return;
    }
  }

  try {
    const rows = await sql`
      SELECT
        m.id, m.name, m.member_no,
        b.id   AS batch_id,
        b.name AS batch_name,
        COUNT(*) FILTER (WHERE a.status = 'present') AS present,
        COUNT(*) FILTER (WHERE a.status = 'absent')  AS absent,
        COUNT(*) FILTER (WHERE a.status = 'late')    AS late,
        COUNT(*) FILTER (WHERE a.status = 'excused') AS excused,
        COUNT(*)                                      AS total,
        ROUND(
          100.0 * COUNT(*) FILTER (WHERE a.status IN ('present', 'late'))
          / NULLIF(COUNT(*), 0), 1
        ) AS attendance_pct
      FROM   attendance a
      JOIN   members m ON m.id = a.member_id
      LEFT JOIN batches b ON b.id = a.batch_id
      WHERE  a.tenant_id = ${req.tenantId!}
        AND  a.type      = 'member'
        AND  (${batch_id ?? null}::uuid IS NULL OR a.batch_id = ${batch_id ?? null}::uuid)
        AND  (${from     ?? null}::date IS NULL OR a.date     >= ${from ?? null}::date)
        AND  (${to       ?? null}::date IS NULL OR a.date     <= ${to   ?? null}::date)
      GROUP  BY m.id, m.name, m.member_no, b.id, b.name
      ORDER  BY attendance_pct DESC NULLS LAST
    `;
    res.json(rows);
  } catch (err: any) {
    logger.error('attendance report error', { error: err.message });
    res.status(500).json({ error: 'Failed to generate report' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /erp/attendance/batch/:batchId/summary  (date-range summary for a batch)
// ─────────────────────────────────────────────────────────────────────────────
router.get('/batch/:batchId/summary', async (req: Request, res: Response): Promise<void> => {
  const role          = req.tenantUser?.role;
  const linkedStaffId = req.tenantUser?.linked_staff_id;

  if (role === 'staff' && linkedStaffId) {
    const allowed = await assertStaffCanAccessBatch(req.tenantId!, linkedStaffId, req.params.batchId);
    if (!allowed) {
      res.status(403).json({ error: 'This batch is not assigned to you' });
      return;
    }
  }

  const { from, to } = req.query as Record<string, string>;

  try {
    const rows = await sql`
      SELECT
        a.date,
        COUNT(*) FILTER (WHERE a.status = 'present') AS present,
        COUNT(*) FILTER (WHERE a.status = 'absent')  AS absent,
        COUNT(*) FILTER (WHERE a.status = 'late')    AS late,
        COUNT(*) FILTER (WHERE a.status = 'excused') AS excused,
        COUNT(*) AS total
      FROM attendance a
      WHERE a.batch_id  = ${req.params.batchId}::uuid
        AND a.tenant_id = ${req.tenantId!}
        AND a.type      = 'member'
        AND (${from ?? null}::date IS NULL OR a.date >= ${from ?? null}::date)
        AND (${to   ?? null}::date IS NULL OR a.date <= ${to   ?? null}::date)
      GROUP BY a.date
      ORDER BY a.date DESC
    `;
    res.json(rows);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
