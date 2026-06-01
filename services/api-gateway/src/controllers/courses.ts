import { Router, Request, Response } from 'express';
import { sql } from '../utils/db';
import { logger } from '../utils/logger';

const router = Router();

// ─────────────────────────────────────────────────────────────────────────────
// COURSES
// ─────────────────────────────────────────────────────────────────────────────

// GET /erp/courses
router.get('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const { status, search } = req.query as Record<string, string>;
    const rows = await sql`
      SELECT
        c.*,
        COUNT(DISTINCT b.id)  AS batch_count,
        COUNT(DISTINCT e.id)  AS member_count
      FROM   courses c
      LEFT JOIN batches     b ON b.course_id  = c.id AND b.tenant_id  = c.tenant_id
      LEFT JOIN enrollments e ON e.batch_id   = b.id AND e.status     = 'active'
      WHERE  c.tenant_id = ${req.tenantId!}
        AND  (${status || null}::text IS NULL OR c.status = ${status || null})
        AND  (${search || null}::text IS NULL OR c.name ILIKE ${'%' + (search || '') + '%'})
      GROUP  BY c.id
      ORDER  BY c.created_at DESC
    `;
    res.json(rows);
  } catch (err: any) {
    logger.error('courses list error', { error: err.message });
    res.status(500).json({ error: 'Failed to fetch courses' });
  }
});

// POST /erp/courses
router.post('/', async (req: Request, res: Response): Promise<void> => {
  const { name, code, description, category, duration, capacity, fee } = req.body;
  if (!name) { res.status(400).json({ error: 'name is required' }); return; }

  try {
    const [row] = await sql`
      INSERT INTO courses
        (tenant_id, name, code, description, category, duration, capacity, fee)
      VALUES
        (${req.tenantId!}, ${name}, ${code ?? null}, ${description ?? null},
         ${category ?? null}, ${duration ?? null},
         ${capacity != null ? Number(capacity) : null},
         ${fee != null ? Number(fee) : 0})
      RETURNING *
    `;
    res.status(201).json(row);
  } catch (err: any) {
    logger.error('course create error', { error: err.message });
    res.status(500).json({ error: err.message });
  }
});

// GET /erp/courses/:id
router.get('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const [row] = await sql`
      SELECT * FROM courses WHERE id = ${req.params.id} AND tenant_id = ${req.tenantId!}
    `;
    if (!row) { res.status(404).json({ error: 'Course not found' }); return; }
    res.json(row);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// PATCH /erp/courses/:id
router.patch('/:id', async (req: Request, res: Response): Promise<void> => {
  const { name, code, description, category, duration, capacity, fee, status } = req.body;
  try {
    // Build dynamic update to avoid COALESCE swallowing intentional nulls or 0
    const [row] = await sql`
      UPDATE courses SET
        name        = CASE WHEN ${name        !== undefined} THEN ${name        ?? null} ELSE name        END,
        code        = CASE WHEN ${code        !== undefined} THEN ${code        ?? null} ELSE code        END,
        description = CASE WHEN ${description !== undefined} THEN ${description ?? null} ELSE description END,
        category    = CASE WHEN ${category    !== undefined} THEN ${category    ?? null} ELSE category    END,
        duration    = CASE WHEN ${duration    !== undefined} THEN ${duration    ?? null} ELSE duration    END,
        capacity    = CASE WHEN ${capacity    !== undefined} THEN ${capacity != null ? Number(capacity) : null}::int ELSE capacity END,
        fee         = CASE WHEN ${fee         !== undefined} THEN ${fee     != null ? Number(fee)      : null}::numeric ELSE fee END,
        status      = CASE WHEN ${status      !== undefined} THEN ${status      ?? null} ELSE status      END,
        updated_at  = NOW()
      WHERE id = ${req.params.id} AND tenant_id = ${req.tenantId!}
      RETURNING *
    `;
    if (!row) { res.status(404).json({ error: 'Course not found' }); return; }
    res.json(row);
  } catch (err: any) {
    logger.error('course update error', { error: err.message });
    res.status(500).json({ error: err.message });
  }
});

// DELETE /erp/courses/:id
router.delete('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    await sql`DELETE FROM courses WHERE id = ${req.params.id} AND tenant_id = ${req.tenantId!}`;
    res.status(204).send();
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
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

// ─────────────────────────────────────────────────────────────────────────────
// BATCHES
// ─────────────────────────────────────────────────────────────────────────────

// GET /erp/courses/:id/batches
router.get('/:id/batches', async (req: Request, res: Response): Promise<void> => {
  try {
    const role          = req.tenantUser?.role;
    const linkedStaffId = req.tenantUser?.linked_staff_id;

    // First verify the course exists for this tenant
    const [course] = await sql`
      SELECT id FROM courses WHERE id = ${req.params.id} AND tenant_id = ${req.tenantId!}
    `;
    if (!course) { res.status(404).json({ error: 'Course not found' }); return; }

    const rows = (role === 'staff' && linkedStaffId)
      ? await sql`
          SELECT b.*,
                 COUNT(DISTINCT e.id) AS enrolled_count,
                 s.name               AS staff_name,
                 s.id                 AS staff_id
          FROM   batches b
          LEFT JOIN enrollments e ON e.batch_id = b.id AND e.status = 'active'
          LEFT JOIN staff       s ON s.id = b.staff_id
          WHERE  b.course_id = ${req.params.id}
            AND  b.tenant_id = ${req.tenantId!}
            AND  b.staff_id  = ${linkedStaffId}
          GROUP  BY b.id, s.name, s.id
          ORDER  BY b.created_at DESC
        `
      : await sql`
          SELECT b.*,
                 COUNT(DISTINCT e.id) AS enrolled_count,
                 s.name               AS staff_name,
                 s.id                 AS staff_id
          FROM   batches b
          LEFT JOIN enrollments e ON e.batch_id = b.id AND e.status = 'active'
          LEFT JOIN staff       s ON s.id = b.staff_id
          WHERE  b.course_id = ${req.params.id} AND b.tenant_id = ${req.tenantId!}
          GROUP  BY b.id, s.name, s.id
          ORDER  BY b.created_at DESC
        `;

    res.json(rows);
  } catch (err: any) {
    logger.error('batches list error', { error: err.message });
    res.status(500).json({ error: 'Failed to fetch batches' });
  }
});

// POST /erp/courses/:id/batches
router.post('/:id/batches', async (req: Request, res: Response): Promise<void> => {
  const { name, start_date, end_date, capacity, staff_id, schedule_time } = req.body;
  if (!name) { res.status(400).json({ error: 'name is required' }); return; }

  try {
    // Verify the course exists for this tenant
    const [course] = await sql`
      SELECT id FROM courses WHERE id = ${req.params.id} AND tenant_id = ${req.tenantId!}
    `;
    if (!course) { res.status(404).json({ error: 'Course not found' }); return; }

    // Validate staff belongs to this tenant if provided
    if (staff_id) {
      const [staffRow] = await sql`
        SELECT id FROM staff WHERE id = ${staff_id} AND tenant_id = ${req.tenantId!}
      `;
      if (!staffRow) {
        res.status(400).json({ error: 'Staff not found in this organisation' });
        return;
      }
    }

    const [row] = await sql`
      INSERT INTO batches
        (tenant_id, course_id, name, start_date, end_date, capacity, staff_id, schedule_time)
      VALUES
        (${req.tenantId!}, ${req.params.id}, ${name},
         ${start_date ?? null},
         ${end_date   ?? null},
         ${capacity   != null ? Number(capacity) : null},
         ${staff_id   ?? null},
         ${schedule_time ?? null})
      RETURNING *
    `;
    res.status(201).json(row);
  } catch (err: any) {
    logger.error('batch create error', { error: err.message });
    res.status(500).json({ error: err.message });
  }
});

// PATCH /erp/courses/:id/batches/:batchId
router.patch('/:id/batches/:batchId', async (req: Request, res: Response): Promise<void> => {
  const { name, start_date, end_date, capacity, status, staff_id, schedule_time } = req.body;
  try {
    // Validate staff if being updated
    if (staff_id !== undefined && staff_id !== null) {
      const [staffRow] = await sql`
        SELECT id FROM staff WHERE id = ${staff_id} AND tenant_id = ${req.tenantId!}
      `;
      if (!staffRow) {
        res.status(400).json({ error: 'Staff not found in this organisation' });
        return;
      }
    }

    const [row] = await sql`
      UPDATE batches SET
        name          = CASE WHEN ${name          !== undefined} THEN ${name          ?? null}                       ELSE name          END,
        start_date    = CASE WHEN ${start_date    !== undefined} THEN ${start_date    ?? null}::date                 ELSE start_date    END,
        end_date      = CASE WHEN ${end_date      !== undefined} THEN ${end_date      ?? null}::date                 ELSE end_date      END,
        capacity      = CASE WHEN ${capacity      !== undefined} THEN ${capacity      != null ? Number(capacity) : null}::int ELSE capacity END,
        status        = CASE WHEN ${status        !== undefined} THEN ${status        ?? null}                       ELSE status        END,
        staff_id      = CASE WHEN ${staff_id      !== undefined} THEN ${staff_id      ?? null}::uuid                 ELSE staff_id      END,
        schedule_time = CASE WHEN ${schedule_time !== undefined} THEN ${schedule_time ?? null}                       ELSE schedule_time END,
        updated_at    = NOW()
      WHERE id = ${req.params.batchId}
        AND course_id = ${req.params.id}
        AND tenant_id = ${req.tenantId!}
      RETURNING *
    `;
    if (!row) { res.status(404).json({ error: 'Batch not found' }); return; }
    res.json(row);
  } catch (err: any) {
    logger.error('batch update error', { error: err.message });
    res.status(500).json({ error: err.message });
  }
});

// DELETE /erp/courses/:id/batches/:batchId
router.delete('/:id/batches/:batchId', async (req: Request, res: Response): Promise<void> => {
  try {
    // Check for active enrollments first
    const [{ count }] = await sql`
      SELECT COUNT(*) FROM enrollments
      WHERE batch_id = ${req.params.batchId} AND status = 'active'
    `;
    if (parseInt(count) > 0) {
      res.status(409).json({
        error: 'Cannot delete batch with active enrollments. Drop or transfer members first.',
      });
      return;
    }
    await sql`
      DELETE FROM batches
      WHERE id = ${req.params.batchId}
        AND course_id = ${req.params.id}
        AND tenant_id = ${req.tenantId!}
    `;
    res.status(204).send();
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// MEMBERS / ENROLLMENTS
// ─────────────────────────────────────────────────────────────────────────────

// GET /erp/courses/:id/members
router.get('/:id/members', async (req: Request, res: Response): Promise<void> => {
  try {
    // Verify course belongs to this tenant
    const [course] = await sql`
      SELECT id FROM courses WHERE id = ${req.params.id} AND tenant_id = ${req.tenantId!}
    `;
    if (!course) { res.status(404).json({ error: 'Course not found' }); return; }

    const rows = await sql`
      SELECT
        m.id, m.name, m.email, m.phone, m.member_no, m.photo_url, m.status AS member_status,
        e.id          AS enrollment_id,
        e.enrolled_on AS enrolled_on,
        e.status      AS enrollment_status,
        b.id          AS batch_id,
        b.name        AS batch_name
      FROM   enrollments e
      JOIN   members m ON m.id  = e.member_id
      JOIN   batches b ON b.id  = e.batch_id
      WHERE  b.course_id = ${req.params.id}
        AND  e.tenant_id = ${req.tenantId!}
      ORDER  BY m.name
    `;
    res.json(rows);
  } catch (err: any) {
    logger.error('course members error', { error: err.message });
    res.status(500).json({ error: 'Failed to fetch course members' });
  }
});

// POST /erp/courses/:id/members  — enroll a member into a batch of this course
router.post('/:id/members', async (req: Request, res: Response): Promise<void> => {
  const { member_id, batch_id } = req.body;

  if (!member_id) { res.status(400).json({ error: 'member_id is required' }); return; }
  if (!batch_id)  { res.status(400).json({ error: 'batch_id is required' });  return; }

  try {
    // Verify batch belongs to this course AND tenant
    const [batch] = await sql`
      SELECT id, capacity FROM batches
      WHERE id        = ${batch_id}
        AND course_id = ${req.params.id}
        AND tenant_id = ${req.tenantId!}
    `;
    if (!batch) {
      res.status(404).json({ error: 'Batch not found in this course' });
      return;
    }

    // Check capacity
    if (batch.capacity) {
      const [{ count }] = await sql`
        SELECT COUNT(*) FROM enrollments
        WHERE batch_id = ${batch_id} AND status = 'active'
      `;
      if (parseInt(count) >= Number(batch.capacity)) {
        res.status(409).json({ error: 'Batch is at full capacity' });
        return;
      }
    }

    // Verify member belongs to this tenant
    const [member] = await sql`
      SELECT id, name FROM members WHERE id = ${member_id} AND tenant_id = ${req.tenantId!}
    `;
    if (!member) {
      res.status(404).json({ error: 'Member not found in this organisation' });
      return;
    }

    // Check for duplicate active enrollment in same course
    const [existingInCourse] = await sql`
      SELECT e.id, b.name AS batch_name FROM enrollments e
      JOIN batches b ON b.id = e.batch_id
      WHERE e.member_id = ${member_id}
        AND b.course_id = ${req.params.id}
        AND e.status    = 'active'
        AND e.tenant_id = ${req.tenantId!}
    `;
    if (existingInCourse) {
      res.status(409).json({
        error: `Member is already enrolled in batch "${existingInCourse.batch_name}" of this course`,
        enrollment_id: existingInCourse.id,
      });
      return;
    }

    const [row] = await sql`
      INSERT INTO enrollments (tenant_id, member_id, batch_id)
      VALUES (${req.tenantId!}, ${member_id}, ${batch_id})
      ON CONFLICT (member_id, batch_id)
        DO UPDATE SET status = 'active', updated_at = NOW()
      RETURNING *
    `;
    res.status(201).json(row);
  } catch (err: any) {
    logger.error('enrollment create error', { error: err.message });
    res.status(500).json({ error: err.message });
  }
});

// DELETE /erp/courses/:id/members/:enrollmentId — drop member from batch
router.delete('/:id/members/:enrollmentId', async (req: Request, res: Response): Promise<void> => {
  try {
    const [row] = await sql`
      UPDATE enrollments
      SET    status = 'dropped', updated_at = NOW()
      WHERE  id         = ${req.params.enrollmentId}
        AND  tenant_id  = ${req.tenantId!}
        AND  batch_id IN (
          SELECT id FROM batches WHERE course_id = ${req.params.id}
        )
      RETURNING id
    `;
    if (!row) { res.status(404).json({ error: 'Enrollment not found' }); return; }
    res.status(204).send();
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// GET /erp/courses/:id/batches/:batchId/members  — members of a specific batch
router.get('/:id/batches/:batchId/members', async (req: Request, res: Response): Promise<void> => {
  try {
    const [batch] = await sql`
      SELECT id FROM batches
      WHERE id = ${req.params.batchId}
        AND course_id = ${req.params.id}
        AND tenant_id = ${req.tenantId!}
    `;
    if (!batch) { res.status(404).json({ error: 'Batch not found' }); return; }

    const rows = await sql`
      SELECT
        m.id, m.name, m.email, m.phone, m.member_no, m.photo_url,
        e.id          AS enrollment_id,
        e.enrolled_on,
        e.status      AS enrollment_status
      FROM   enrollments e
      JOIN   members m ON m.id = e.member_id
      WHERE  e.batch_id   = ${req.params.batchId}
        AND  e.tenant_id  = ${req.tenantId!}
        AND  e.status     = 'active'
      ORDER  BY m.name
    `;
    res.json(rows);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
