// lib/features/finance/presentation/screens/finance_screen.dart
import 'package:flutter/material.dart';
import '../../finance_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/members/members_service.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});
  @override State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  final _svc    = FinanceService();
  final _memSvc = MembersService();
  late final TabController _tabs;
  List<dynamic> _invoices    = [];
  List<dynamic> _payments    = [];
  List<dynamic> _outstanding = [];
  List<dynamic> _members     = [];
  bool _loading = true;

  @override void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }
  @override void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Future.wait<dynamic>([
        _svc.getInvoices(),
        _svc.getPayments(),
        _svc.getOutstandingReport(),
        _memSvc.getMembers(),
      ]);
      setState(() {
        _invoices    = res[0] as List<dynamic>;
        _payments    = res[1] as List<dynamic>;
        _outstanding = res[2] as List<dynamic>;
        _members     = res[3] as List<dynamic>;
        _loading     = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _showNewInvoice() async {
    final formKey    = GlobalKey<FormState>();
    String? memberId;
    final  amountCtrl = TextEditingController();
    final  descCtrl   = TextEditingController();
    String dueDate    = DateTime.now().add(const Duration(days: 30))
        .toIso8601String().substring(0, 10);
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Expanded(child: Text('New Invoice', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: memberId,
                  hint: const Text('Select Member *'),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline), labelText: 'Member'),
                  items: _members.map((m) {
                    final mm = m as Map<String, dynamic>;
                    return DropdownMenuItem<String>(value: mm['id'] as String, child: Text(mm['name'] as String? ?? ''));
                  }).toList(),
                  validator: (v) => v == null ? 'Select a member' : null,
                  onChanged: (v) => setS(() => memberId = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount (₹) *', prefixIcon: Icon(Icons.currency_rupee)),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description / Notes', prefixIcon: Icon(Icons.notes_outlined)),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text('Due date: $dueDate'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setS(() => dueDate = picked.toIso8601String().substring(0, 10));
                  },
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: saving ? null : () async {
                    if (!formKey.currentState!.validate()) return;
                    setS(() => saving = true);
                    try {
                      await _svc.createInvoice({
                        'member_id':   memberId,
                        'amount':      double.tryParse(amountCtrl.text.trim()) ?? 0,
                        'due_date':    dueDate,
                        if (descCtrl.text.trim().isNotEmpty) 'description': descCtrl.text.trim(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      setS(() => saving = false);
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  child: saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Create Invoice'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    _load();
  }

  Future<void> _showRecordPayment() async {
    final formKey    = GlobalKey<FormState>();
    String? memberId;
    final  amountCtrl = TextEditingController();
    String method    = 'cash';
    String paidOn    = DateTime.now().toIso8601String().substring(0, 10);
    bool   saving    = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Expanded(child: Text('Record Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: memberId,
                hint: const Text('Select Member *'),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline), labelText: 'Member'),
                items: _members.map((m) {
                  final mm = m as Map<String, dynamic>;
                  return DropdownMenuItem<String>(value: mm['id'] as String, child: Text(mm['name'] as String? ?? ''));
                }).toList(),
                validator: (v) => v == null ? 'Select a member' : null,
                onChanged: (v) => setS(() => memberId = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (₹) *', prefixIcon: Icon(Icons.currency_rupee)),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: method,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.payment_outlined), labelText: 'Payment Method'),
                items: const [
                  DropdownMenuItem(value: 'cash',   child: Text('Cash')),
                  DropdownMenuItem(value: 'upi',    child: Text('UPI')),
                  DropdownMenuItem(value: 'bank',   child: Text('Bank Transfer')),
                  DropdownMenuItem(value: 'card',   child: Text('Card')),
                  DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                ],
                onChanged: (v) => setS(() => method = v ?? 'cash'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: saving ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  setS(() => saving = true);
                  try {
                    await _svc.recordPayment({
                      'member_id': memberId,
                      'amount':    double.tryParse(amountCtrl.text.trim()) ?? 0,
                      'method':    method,
                      'paid_on':   paidOn,
                    });
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    setS(() => saving = false);
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Record Payment'),
              ),
            ]),
          ),
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Finance'),
      bottom: TabBar(
        controller: _tabs,
        tabs: const [Tab(text: 'Invoices'), Tab(text: 'Payments'), Tab(text: 'Outstanding')],
      ),
    ),
    body: _loading ? const Center(child: CircularProgressIndicator())
      : TabBarView(
          controller: _tabs,
          children: [
            _InvoiceList(invoices: _invoices),
            _PaymentList(payments: _payments),
            _OutstandingList(outstanding: _outstanding),
          ],
        ),
    floatingActionButton: AnimatedBuilder(
      animation: _tabs,
      builder: (_, __) => FloatingActionButton.extended(
        icon: Icon(_tabs.index == 1 ? Icons.currency_rupee : Icons.receipt_long_outlined),
        label: Text(_tabs.index == 1 ? 'Record Payment' : 'New Invoice'),
        onPressed: _tabs.index == 1 ? _showRecordPayment : _showNewInvoice,
      ),
    ),
  );
}

class _InvoiceList extends StatelessWidget {
  const _InvoiceList({required this.invoices});
  final List<dynamic> invoices;
  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) return const Center(child: Text('No invoices yet'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: invoices.length,
      itemBuilder: (_, i) {
        final inv = invoices[i] as Map<String, dynamic>;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.receipt_outlined),
            title: Text(inv['invoice_no'] as String? ?? ''),
            subtitle: Text(inv['member_name'] as String? ?? ''),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${inv['amount']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(inv['status'] as String? ?? '',
                  style: TextStyle(fontSize: 11,
                    color: inv['status'] == 'paid' ? AppTheme.success : AppTheme.warning)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PaymentList extends StatelessWidget {
  const _PaymentList({required this.payments});
  final List<dynamic> payments;
  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) return const Center(child: Text('No payments recorded yet'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: payments.length,
      itemBuilder: (_, i) {
        final p = payments[i] as Map<String, dynamic>;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.currency_rupee, color: AppTheme.success),
            title: Text('₹${p['amount']}'),
            subtitle: Text('${p['member_name']} • ${p['method'] ?? 'cash'}'),
            trailing: Text(p['paid_on'] as String? ?? ''),
          ),
        );
      },
    );
  }
}

class _OutstandingList extends StatelessWidget {
  const _OutstandingList({required this.outstanding});
  final List<dynamic> outstanding;
  @override
  Widget build(BuildContext context) {
    if (outstanding.isEmpty) return const Center(child: Text('No outstanding invoices 🎉'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: outstanding.length,
      itemBuilder: (_, i) {
        final inv = outstanding[i] as Map<String, dynamic>;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.warning_amber_outlined, color: AppTheme.error),
            title: Text(inv['member_name'] as String? ?? ''),
            subtitle: Text('Due: ${inv['due_date'] ?? 'no date'}'),
            trailing: Text('₹${inv['amount']}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.error)),
          ),
        );
      },
    );
  }
}