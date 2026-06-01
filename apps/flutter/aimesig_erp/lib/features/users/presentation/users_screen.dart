// lib/features/users/presentation/screens/users_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../auth/auth_service.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _svc = AuthService();
  List<dynamic> _users = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try { _users = await _svc.listUsers(); } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  // ── Role chip color ──────────────────────────────────────────────
  Color _roleColor(String role) {
    switch (role) {
      case 'tenant_admin': return Colors.deepPurple;
      case 'staff':        return Colors.blue;
      case 'member':       return Colors.teal;
      default:             return Colors.grey;
    }
  }

  // ── Copy to clipboard helper ─────────────────────────────────────
  void _copy(BuildContext ctx, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text('$label copied'), duration: const Duration(seconds: 2)));
  }

  // ── Show provisioned credentials dialog ─────────────────────────
  void _showCredentials(BuildContext ctx, String email, String password) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Login Credentials Created'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Share these credentials securely. The user will be prompted to change their password on first login.'),
          const SizedBox(height: 16),
          _CredentialTile(label: 'Email',    value: email,    onCopy: () => _copy(ctx, email,    'Email')),
          const SizedBox(height: 8),
          _CredentialTile(label: 'Password', value: password, onCopy: () => _copy(ctx, password, 'Password')),
        ]),
        actions: [
          FilledButton(
            child: const Text('Done'),
            onPressed: () { Navigator.pop(ctx); _load(); },
          ),
        ],
      ),
    );
  }

  // ── Reset password ────────────────────────────────────────────────
  Future<void> _resetPassword(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text('Generate a new temporary password for ${user['name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      final result = await _svc.adminResetPassword(user['id'] as String);
      if (mounted) _showCredentials(context, result.email, result.temporaryPassword);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // ── Toggle active status ─────────────────────────────────────────
  Future<void> _toggleActive(Map<String, dynamic> user) async {
    final isActive = user['is_active'] as bool;
    final action   = isActive ? 'Disable' : 'Enable';
    final confirm  = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$action Account'),
        content: Text('$action login for ${user['name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await _svc.setUserActive(user['id'] as String, isActive: !isActive);
      _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('System Users (${_users.length})'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _load,
        ),
      ],
    ),
    body: _loading
      ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(
          onRefresh: _load,
          child: _users.isEmpty
            ? const Center(child: Text('No users yet.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _users.length,
                itemBuilder: (ctx, i) {
                  final u = _users[i] as Map<String, dynamic>;
                  final role     = u['role']      as String;
                  final isActive = u['is_active'] as bool;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _roleColor(role).withOpacity(0.15),
                        child: Icon(
                          role == 'tenant_admin'
                            ? Icons.admin_panel_settings_outlined
                            : role == 'staff'
                              ? Icons.badge_outlined
                              : Icons.person_outlined,
                          color: _roleColor(role),
                        ),
                      ),
                      title: Text(
                        u['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(u['email'] as String,
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          Wrap(spacing: 6, children: [
                            _RoleBadge(role: role, color: _roleColor(role)),
                            if (!isActive)
                              _StatusBadge(label: 'Disabled', color: Colors.red),
                            if (u['must_change_password'] == true)
                              _StatusBadge(label: 'Pwd Reset Required', color: Colors.orange),
                          ]),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'reset')  _resetPassword(u);
                          if (action == 'toggle') _toggleActive(u);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'reset',
                            child: ListTile(
                              leading: Icon(Icons.lock_reset_outlined),
                              title: Text('Reset Password'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          PopupMenuItem(value: 'toggle',
                            child: ListTile(
                              leading: Icon(isActive
                                ? Icons.block_outlined
                                : Icons.check_circle_outline),
                              title: Text(isActive ? 'Disable Account' : 'Enable Account'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
        ),
  );
}

// ── Small widgets ─────────────────────────────────────────────────────────────
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role, required this.color});
  final String role;
  final Color  color;

  String get _label {
    switch (role) {
      case 'tenant_admin': return 'Admin';
      case 'staff':        return 'Staff';
      case 'member':       return 'Member';
      default:             return role;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(_label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

class _CredentialTile extends StatelessWidget {
  const _CredentialTile({
    required this.label,
    required this.value,
    required this.onCopy,
  });
  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace')),
          ],
        )),
        IconButton(
          icon: const Icon(Icons.copy_outlined, size: 20),
          onPressed: onCopy,
          tooltip: 'Copy',
        ),
      ]),
    );
  }
}