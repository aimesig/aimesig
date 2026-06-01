// lib/features/staff/presentation/screens/staff_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../staff_service.dart';
import '../../../auth/auth_service.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});
  @override State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final _svc     = StaffService();
  final _authSvc = AuthService();
  List<dynamic> _staff   = [];
  bool          _loading = true;
  String?       _search;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try { _staff = await _svc.getStaff(search: _search); } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  // ── Add Staff ─────────────────────────────────────────────────────
  Future<void> _showAddStaff() async {
    final formKey  = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final empNoCtrl = TextEditingController();
    String role = 'instructor';
    bool   saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Expanded(child: Text('Add Staff',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                  IconButton(icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Full Name *', prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: empNoCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Employee No.', prefixIcon: Icon(Icons.badge_outlined)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Personal Email', prefixIcon: Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(
                      labelText: 'Role', prefixIcon: Icon(Icons.work_outline)),
                  items: const [
                    DropdownMenuItem(value: 'instructor', child: Text('Instructor')),
                    DropdownMenuItem(value: 'coordinator', child: Text('Coordinator')),
                    DropdownMenuItem(value: 'admin_staff', child: Text('Admin Staff')),
                    DropdownMenuItem(value: 'support', child: Text('Support')),
                  ],
                  onChanged: (v) => setSS(() => role = v ?? 'instructor'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: saving ? null : () async {
                    if (!formKey.currentState!.validate()) return;
                    setSS(() => saving = true);
                    try {
                      await _svc.createStaff({
                        'name':        nameCtrl.text.trim(),
                        'role':        role,
                        if (empNoCtrl.text.trim().isNotEmpty)
                          'employee_no': empNoCtrl.text.trim(),
                        if (emailCtrl.text.trim().isNotEmpty)
                          'email': emailCtrl.text.trim(),
                        if (phoneCtrl.text.trim().isNotEmpty)
                          'phone': phoneCtrl.text.trim(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      setSS(() => saving = false);
                      if (ctx.mounted)
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e')));
                    }
                  },
                  child: saving
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Add Staff Member'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    _load();
  }

  // ── Provision Login ───────────────────────────────────────────────
  Future<void> _provisionLogin(Map<String, dynamic> staff) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Login Account'),
        content: Text(
          'Create an @aimesig.com login for ${staff['name']}?\n\n'
          'They will receive a temporary password and must reset it on first login.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      final result = await _authSvc.provisionStaff(staff['id'] as String);
      if (!mounted) return;
      _showCredentialsDialog(result.email, result.temporaryPassword);
    } catch (e) {
      final msg = e.toString();
      if (!mounted) return;
      if (msg.contains('already has a login')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.orange));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $msg'), backgroundColor: Colors.red));
      }
    }
  }

  void _showCredentialsDialog(String email, String password) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Login Created'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'Share these credentials. Staff must change their password on first login.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          _CredRow('Email',    email,    () {
            Clipboard.setData(ClipboardData(text: email));
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Email copied')));
          }),
          const SizedBox(height: 8),
          _CredRow('Password', password, () {
            Clipboard.setData(ClipboardData(text: password));
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password copied')));
          }),
        ]),
        actions: [
          FilledButton(
              child: const Text('Done'),
              onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Staff (${_staff.length})'),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SearchBar(
            hintText: 'Search staff…',
            leading: const Icon(Icons.search),
            onChanged: (v) {
              _search = v.isEmpty ? null : v;
              _load();
            },
          ),
        ),
      ),
    ),
    body: _loading
      ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(
          onRefresh: _load,
          child: _staff.isEmpty
            ? const Center(child: Text('No staff found. Tap + to add.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _staff.length,
                itemBuilder: (ctx, i) {
                  final s      = _staff[i] as Map<String, dynamic>;
                  final status = s['status'] as String? ?? 'active';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          (s['name'] as String? ?? '?')
                              .substring(0, 1)
                              .toUpperCase(),
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(s['name'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${s['role'] ?? ''}'
                          '${s['department'] != null ? ' · ${s['department']}' : ''}'
                          '${s['employee_no'] != null ? ' · #${s['employee_no']}' : ''}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        _StatusDot(status),
                        PopupMenuButton<String>(
                          onSelected: (action) {
                            if (action == 'provision') _provisionLogin(s);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'provision',
                              child: ListTile(
                                leading: Icon(Icons.manage_accounts_outlined),
                                title: Text('Create Login'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ]),
                    ),
                  );
                },
              ),
        ),
    floatingActionButton: FloatingActionButton.extended(
      icon: const Icon(Icons.person_add_outlined),
      label: const Text('Add Staff'),
      onPressed: _showAddStaff,
    ),
  );
}

class _StatusDot extends StatelessWidget {
  const _StatusDot(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status == 'active' ? Colors.green : Colors.grey;
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _CredRow extends StatelessWidget {
  const _CredRow(this.label, this.value, this.onCopy);
  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceVariant,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(
            fontWeight: FontWeight.w600, fontFamily: 'monospace', fontSize: 13)),
      ])),
      IconButton(icon: const Icon(Icons.copy_outlined, size: 18), onPressed: onCopy),
    ]),
  );
}