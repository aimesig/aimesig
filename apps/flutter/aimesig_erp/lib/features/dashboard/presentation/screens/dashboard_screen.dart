// lib/features/dashboard/presentation/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../members/members_service.dart';
import '../../../finance/finance_service.dart';
import '../../../admissions/admissions_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _members    = MembersService();
  final _finance    = FinanceService();
  final _admissions = AdmissionsService();

  int?    _memberCount;
  double? _revenue;
  int?    _leadCount;
  List<dynamic> _outstanding = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _members.getMembers(limit: 1),
        _finance.getRevenueReport(),
        _admissions.getLeads(),
        _finance.getOutstandingReport(),
      ]);
      final membersRes   = results[0] as Map<String, dynamic>;
      final revenueRes   = results[1] as List<dynamic>;
      final leadsRes     = results[2] as List<dynamic>;
      final outstanding  = results[3] as List<dynamic>;

      setState(() {
        _memberCount  = membersRes['total'] as int? ?? 0;
        _revenue      = revenueRes.isNotEmpty
            ? double.tryParse(revenueRes.first['total'].toString()) ?? 0
            : 0;
        _leadCount    = leadsRes.length;
        _outstanding  = outstanding.take(5).toList();
        _loading      = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Summary cards ─────────────────────────────
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      _SummaryCard(
                        icon: Icons.people_outline,
                        label: 'Total Members',
                        value: _memberCount?.toString() ?? '—',
                        color: AppTheme.primary,
                        onTap: () => context.go('/members'),
                      ),
                      _SummaryCard(
                        icon: Icons.currency_rupee,
                        label: 'Revenue (Latest)',
                        value: _revenue != null
                            ? '₹${_revenue!.toStringAsFixed(0)}'
                            : '—',
                        color: AppTheme.success,
                        onTap: () => context.go('/finance'),
                      ),
                      _SummaryCard(
                        icon: Icons.how_to_reg_outlined,
                        label: 'Open Leads',
                        value: _leadCount?.toString() ?? '—',
                        color: AppTheme.warning,
                        onTap: () => context.go('/admissions'),
                      ),
                      _SummaryCard(
                        icon: Icons.warning_amber_outlined,
                        label: 'Outstanding',
                        value: _outstanding.length.toString(),
                        color: AppTheme.error,
                        onTap: () => context.go('/finance'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Quick actions ─────────────────────────────
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _QuickAction(icon: Icons.person_add_outlined,     label: 'Add Member',    onTap: () => context.go('/members/add')),
                      _QuickAction(icon: Icons.check_circle_outline,    label: 'Mark Attendance', onTap: () => context.go('/attendance')),
                      _QuickAction(icon: Icons.receipt_long_outlined,   label: 'New Invoice',   onTap: () => context.go('/finance')),
                      _QuickAction(icon: Icons.how_to_reg_outlined,     label: 'New Lead',      onTap: () => context.go('/admissions')),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Outstanding invoices ──────────────────────
                  if (_outstanding.isNotEmpty) ...[
                    Text(
                      'Outstanding Invoices',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ..._outstanding.map((inv) => Card(
                          child: ListTile(
                            title: Text(inv['member_name'] ?? 'Unknown'),
                            subtitle: Text('Due: ${inv['due_date'] ?? 'No due date'}'),
                            trailing: Text(
                              '₹${inv['amount']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.error),
                            ),
                          ),
                        )),
                  ],
                ],
              ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
      side: BorderSide(color: Colors.grey.shade300),
      backgroundColor: Colors.white,
    );
  }
}
