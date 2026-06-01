// lib/features/members/presentation/screens/members_list_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../members_service.dart';
import '../../../../core/theme/app_theme.dart';

class MembersListScreen extends StatefulWidget {
  const MembersListScreen({super.key});

  @override
  State<MembersListScreen> createState() => _MembersListScreenState();
}

class _MembersListScreenState extends State<MembersListScreen> {
  final _svc    = MembersService();
  final _search = TextEditingController();

  List<dynamic> _members = [];
  int _total    = 0;
  int _page     = 1;
  bool _loading = true;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) _page = 1;
    setState(() => _loading = true);
    try {
      final res = await _svc.getMembers(
        status: _status,
        search: _search.text.isEmpty ? null : _search.text.trim(),
        page: _page,
      );
      setState(() {
        _members = res['data'] as List<dynamic>;
        _total   = res['total'] as int? ?? 0;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'active':   return AppTheme.success;
      case 'inactive': return Colors.grey;
      case 'banned':   return AppTheme.error;
      default:         return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Members ($_total)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => context.go('/members/add'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search + filter bar ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      hintText: 'Search by name, email, phone…',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => _load(reset: true),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String?>(
                  value: _status,
                  hint: const Text('All'),
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: null,       child: Text('All')),
                    DropdownMenuItem(value: 'active',   child: Text('Active')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                    DropdownMenuItem(value: 'banned',   child: Text('Banned')),
                  ],
                  onChanged: (v) {
                    setState(() => _status = v);
                    _load(reset: true);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── List ──────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _load(reset: true),
                    child: _members.isEmpty
                        ? const Center(child: Text('No members found'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: _members.length,
                            itemBuilder: (_, i) {
                              final m = _members[i] as Map<String, dynamic>;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: m['photo_url'] != null
                                        ? NetworkImage(m['photo_url'] as String)
                                        : null,
                                    child: m['photo_url'] == null
                                        ? Text((m['name'] as String)
                                            .substring(0, 1)
                                            .toUpperCase())
                                        : null,
                                  ),
                                  title: Text(m['name'] as String),
                                  subtitle: Text(m['email'] ?? m['phone'] ?? ''),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _statusColor(m['status'] as String?)
                                          .withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      (m['status'] as String?) ?? 'active',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _statusColor(m['status'] as String?),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  onTap: () =>
                                      context.go('/members/${m['id']}'),
                                ),
                              );
                            },
                          ),
                  ),
          ),

          // ── Pagination ────────────────────────────────────────
          if (_total > 20)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _page > 1
                        ? () { setState(() => _page--); _load(); }
                        : null,
                  ),
                  Text('Page $_page of ${(_total / 20).ceil()}'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _page < (_total / 20).ceil()
                        ? () { setState(() => _page++); _load(); }
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
