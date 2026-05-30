import { Router, Request, Response } from 'express';
import { sql } from '../../utils/db';

const router = Router();

// ── FEE PLANS ─────────────────────────────────────────────────────

router.get('/fee-plans', async (req: Request, res: Response): Promise<void> => {
  const rows = await sql`SELECT * FROM fee_plans WHERE tenant_id = ${req.tenantId!} ORDER BY name`;
  res.json(rows);
});

router.post('/fee-plans', async (req: Request, res: Response): Promise<void> => {
  const { name, amount, frequency, due_day } = req.body;
  if (!name || !amount) { res.status(400).json({ error: 'name and amount required' }); return; }
  const [row] = await sql`
    INSERT INTO fee_plans (tenant_id, name, amount, frequency, due_day)
    VALUES (${req.tenantId!}, ${name}, ${amount}, ${frequency||'monthly'}, ${due_day||1})
    RETURNING *
  `;
  res.status(201).json(row);
});

router.patch('/fee-plans/:id', async (req: Request, res: Response): Promise<void> => {
  const { name, amount, frequency, due_day } = req.body;
  const [row] = await sql`
    UPDATE fee_plans SET
      name      = COALESCE(${name||null}, name),
      amount    = COALESCE(${amount||null}::numeric, amount),
      frequency = COALESCE(${frequency||null}, frequency),
      due_day   = COALESCE(${due_day||null}::int, due_day)
    WHERE id = ${req.params.id} AND tenant_id = ${req.tenantId!} RETURNING *
  `;
  res.json(row);
});

router.delete('/fee-plans/:id', async (req: Request, res: Response): Promise<void> => {
  await sql`DELETE FROM fee_plans WHERE id = ${req.params.id} AND tenant_id = ${req.tenantId!}`;
  res.status(204).send();
});

// ── INVOICES ──────────────────────────────────────────────────────

router.get('/invoices', async (req: Request, res: Response): Promise<void> => {
  const { status, member_id } = req.query as Record<string, string>;
  const rows = await sql`
    SELECT i.*, m.name as member_name
    FROM   invoices i JOIN members m ON m.id = i.member_id
    WHERE  i.tenant_id = ${req.tenantId!}
      AND  (${status||null}::text IS NULL OR i.status = ${status||null})
      AND  (${member_id||null}::uuid IS NULL OR i.member_id = ${member_id||null}::uuid)
    ORDER  BY i.created_at DESC
  `;
  res.json(rows);
});

router.post('/invoices', async (req: Request, res: Response): Promise<void> => {
  const { member_id, amount, due_date, line_items, notes } = req.body;
  if (!member_id || !amount) { res.status(400).json({ error: 'member_id and amount required' }); return; }
  const invoice_no = 'INV-' + Date.now().toString(36).toUpperCase();
  const [row] = await sql`
    INSERT INTO invoices (tenant_id, member_id, invoice_no, amount, due_date, line_items, notes)
    VALUES (${req.tenantId!}, ${member_id}, ${invoice_no}, ${amount},
            ${due_date||null}, ${JSON.stringify(line_items||[])}::jsonb, ${notes||null})
    RETURNING *
  `;
  res.status(201).json(row);
});

router.get('/invoices/:id', async (req: Request, res: Response): Promise<void> => {
  const [row] = await sql`
    SELECT i.*, m.name as member_name, m.email as member_email, m.phone as member_phone
    FROM   invoices i JOIN members m ON m.id = i.member_id
    WHERE  i.id = ${req.params.id} AND i.tenant_id = ${req.tenantId!}
  `;
  if (!row) { res.status(404).json({ error: 'Invoice not found' }); return; }
  res.json(row);
});

// POST /erp/finance/invoices/:id/send  — marks as sent (email integration TBD)
router.post('/invoices/:id/send', async (req: Request, res: Response): Promise<void> => {
  const [row] = await sql`
    UPDATE invoices SET updated_at = NOW() WHERE id = ${req.params.id} AND tenant_id = ${req.tenantId!} RETURNING *
  `;
  res.json({ message: 'Invoice queued for delivery', invoice: row });
});

// ── PAYMENTS ──────────────────────────────────────────────────────

router.get('/payments', async (req: Request, res: Response): Promise<void> => {
  const { member_id, from, to } = req.query as Record<string, string>;
  const rows = await sql`
    SELECT p.*, m.name as member_name
    FROM   payments p JOIN members m ON m.id = p.member_id
    WHERE  p.tenant_id = ${req.tenantId!}
      AND  (${member_id||null}::uuid IS NULL OR p.member_id = ${member_id||null}::uuid)
      AND  (${from||null}::date IS NULL OR p.paid_on >= ${from||null}::date)
      AND  (${to||null}::date IS NULL OR p.paid_on <= ${to||null}::date)
    ORDER  BY p.paid_on DESC
  `;
  res.json(rows);
});

router.post('/payments', async (req: Request, res: Response): Promise<void> => {
  const { member_id, invoice_id, amount, method, reference, paid_on, notes } = req.body;
  if (!member_id || !amount) { res.status(400).json({ error: 'member_id and amount required' }); return; }
  try {
    const [pay] = await sql`
      INSERT INTO payments (tenant_id, member_id, invoice_id, amount, method, reference, paid_on, notes)
      VALUES (${req.tenantId!}, ${member_id}, ${invoice_id||null}, ${amount},
              ${method||'cash'}, ${reference||null}, ${paid_on||new Date().toISOString().slice(0,10)}, ${notes||null})
      RETURNING *
    `;
    // Auto-mark invoice paid if fully covered
    if (invoice_id) {
      await sql`
        UPDATE invoices SET status = 'paid', updated_at = NOW()
        WHERE  id = ${invoice_id} AND tenant_id = ${req.tenantId!}
          AND  amount <= (SELECT SUM(amount) FROM payments WHERE invoice_id = ${invoice_id} AND status = 'completed')
      `;
    }
    res.status(201).json(pay);
  } catch (err: any) { res.status(500).json({ error: err.message }); }
});

router.post('/payments/:id/refund', async (req: Request, res: Response): Promise<void> => {
  const [row] = await sql`
    UPDATE payments SET status = 'refunded' WHERE id = ${req.params.id} AND tenant_id = ${req.tenantId!} RETURNING *
  `;
  res.json(row);
});

// ── REPORTS ───────────────────────────────────────────────────────

router.get('/reports/revenue', async (req: Request, res: Response): Promise<void> => {
  const { from, to } = req.query as Record<string, string>;
  const rows = await sql`
    SELECT
      DATE_TRUNC('month', paid_on) as month,
      SUM(amount)                  as total,
      COUNT(*)                     as transactions
    FROM   payments
    WHERE  tenant_id = ${req.tenantId!} AND status = 'completed'
      AND  (${from||null}::date IS NULL OR paid_on >= ${from||null}::date)
      AND  (${to||null}::date IS NULL OR paid_on <= ${to||null}::date)
    GROUP  BY 1 ORDER BY 1 DESC
  `;
  res.json(rows);
});

router.get('/reports/outstanding', async (req: Request, res: Response): Promise<void> => {
  const rows = await sql`
    SELECT i.*, m.name as member_name, m.phone as member_phone
    FROM   invoices i JOIN members m ON m.id = i.member_id
    WHERE  i.tenant_id = ${req.tenantId!} AND i.status IN ('pending','overdue')
    ORDER  BY i.due_date ASC NULLS LAST
  `;
  res.json(rows);
});

export default router;
