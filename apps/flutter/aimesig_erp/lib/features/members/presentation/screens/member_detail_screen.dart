// lib/features/members/presentation/screens/member_detail_screen.dart

import 'package:flutter/material.dart';
import '../../members_service.dart';
import '../../../../core/theme/app_theme.dart';

class MemberDetailScreen extends StatefulWidget {
  const MemberDetailScreen({super.key, required this.id});
  final String id;

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen>
    with SingleTickerProviderStateMixin {
  final _svc = MembersService();

  Map<String, dynamic>? _member;
  List<dynamic> _enrollments = [];
  List<dynamic> _payments    = [];
  late final TabController _tabs;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _svc.getMember(widget.id),
        _svc.getMemberEnrollments(widget.id),
        _svc.getMemberPayments(widget.id),
      ]);
      setState(() {
        _member      = results[0] as Map<String, dynamic>;
        _enrollments = results[1] as List<dynamic>;
        _payments    = results[2] as List<dynamic>;
        _loading     = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_member?['name'] ?? 'Member'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Profile'),
            Tab(text: 'Enrollments'),
            Tab(text: 'Payments'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _ProfileTab(member: _member!),
                _EnrollmentsTab(enrollments: _enrollments),
                _PaymentsTab(payments: _payments),
              ],
            ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.member});
  final Map<String, dynamic> member;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundImage: member['photo_url'] != null
                ? NetworkImage(member['photo_url'] as String)
                : null,
            child: member['photo_url'] == null
                ? Text(
                    (member['name'] as String).substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 28),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            member['name'] as String,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              member['status'] ?? 'active',
              style: const TextStyle(
                  color: AppTheme.success, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _InfoRow(Icons.email_outlined,  'Email',    member['email']),
        _InfoRow(Icons.phone_outlined,  'Phone',    member['phone']),
        _InfoRow(Icons.badge_outlined,  'Member #', member['member_no']),
        _InfoRow(Icons.cake_outlined,   'DOB',      member['dob']),
        _InfoRow(Icons.people_outline,  'Gender',   member['gender']),
        _InfoRow(Icons.calendar_today,  'Joined',   member['joined_on']),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Text('$label: ',
              style:
                  const TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(
            child: Text(
              value.toString(),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnrollmentsTab extends StatelessWidget {
  const _EnrollmentsTab({required this.enrollments});
  final List<dynamic> enrollments;

  @override
  Widget build(BuildContext context) {
    if (enrollments.isEmpty) {
      return const Center(child: Text('No enrollments yet'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: enrollments.length,
      itemBuilder: (_, i) {
        final e = enrollments[i] as Map<String, dynamic>;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.school_outlined),
            title: Text(e['course_name'] ?? ''),
            subtitle: Text(e['batch_name'] ?? ''),
            trailing: Text(e['enrolled_on'] ?? ''),
          ),
        );
      },
    );
  }
}

class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab({required this.payments});
  final List<dynamic> payments;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return const Center(child: Text('No payments recorded'));
    }
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
            subtitle: Text('${p['method'] ?? 'cash'} — ${p['paid_on'] ?? ''}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: p['status'] == 'completed'
                    ? AppTheme.success.withOpacity(0.12)
                    : AppTheme.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                p['status'] ?? '',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: p['status'] == 'completed'
                      ? AppTheme.success
                      : AppTheme.warning,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
