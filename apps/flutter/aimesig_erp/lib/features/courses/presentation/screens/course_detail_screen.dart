// lib/features/courses/presentation/screens/course_detail_screen.dart

import 'package:flutter/material.dart';
import '../../courses_service.dart';
import '../../../staff/staff_service.dart';
import '../../../members/members_service.dart';

class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({super.key, required this.id});
  final String id;
  @override State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  final _svc       = CoursesService();
  final _staffSvc  = StaffService();
  final _memberSvc = MembersService();

  Map<String, dynamic>? _course;
  List<dynamic> _batches = [];
  List<dynamic> _members = [];
  List<dynamic> _staffList = [];
  late final TabController _tabs;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Future.wait<dynamic>([
        _svc.getCourse(widget.id),
        _svc.getBatches(widget.id),
        _svc.getCourseMembers(widget.id),
        _staffSvc.getStaff(status: 'active'),
      ]);
      setState(() {
        _course    = res[0] as Map<String, dynamic>;
        _batches   = res[1] as List<dynamic>;
        _members   = res[2] as List<dynamic>;
        _staffList = res[3] as List<dynamic>;
        _loading   = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  // ── Add Batch ─────────────────────────────────────────────────────
  Future<void> _showAddBatch() async {
    final formKey      = GlobalKey<FormState>();
    final nameCtrl     = TextEditingController();
    final capacityCtrl = TextEditingController();
    final scheduleCtrl = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    String?   staffId;
    bool      saving = false;

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
                // Header
                Row(children: [
                  const Expanded(child: Text('Add Batch',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                  IconButton(icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 12),

                // Batch name
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Batch Name *',
                      prefixIcon: Icon(Icons.group_outlined)),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Capacity
                TextFormField(
                  controller: capacityCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Capacity',
                      prefixIcon: Icon(Icons.people_outline)),
                ),
                const SizedBox(height: 12),

                // Schedule time
                TextFormField(
                  controller: scheduleCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Schedule (e.g. Mon/Wed 10:00 AM)',
                      prefixIcon: Icon(Icons.schedule_outlined)),
                ),
                const SizedBox(height: 12),

                // Date range row
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text(startDate == null
                          ? 'Start Date'
                          : '${startDate!.day}/${startDate!.month}/${startDate!.year}',
                          style: const TextStyle(fontSize: 13)),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (d != null) setSS(() => startDate = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event_outlined, size: 16),
                      label: Text(endDate == null
                          ? 'End Date'
                          : '${endDate!.day}/${endDate!.month}/${endDate!.year}',
                          style: const TextStyle(fontSize: 13)),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (d != null) setSS(() => endDate = d);
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 12),

                // Assign staff
                DropdownButtonFormField<String>(
                  value: staffId,
                  hint: const Text('Assign Staff (optional)'),
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.badge_outlined), labelText: 'Staff'),
                  items: _staffList.map((s) {
                    final st = s as Map<String, dynamic>;
                    return DropdownMenuItem<String>(
                      value: st['id'] as String,
                      child: Text(st['name'] as String? ?? ''),
                    );
                  }).toList(),
                  onChanged: (v) => setSS(() => staffId = v),
                ),
                const SizedBox(height: 20),

                FilledButton(
                  onPressed: saving ? null : () async {
                    if (!formKey.currentState!.validate()) return;
                    setSS(() => saving = true);
                    try {
                      await _svc.createBatch(widget.id, {
                        'name':          nameCtrl.text.trim(),
                        if (capacityCtrl.text.trim().isNotEmpty)
                          'capacity':    int.tryParse(capacityCtrl.text.trim()),
                        if (scheduleCtrl.text.trim().isNotEmpty)
                          'schedule_time': scheduleCtrl.text.trim(),
                        if (startDate != null)
                          'start_date':  startDate!.toIso8601String().substring(0, 10),
                        if (endDate != null)
                          'end_date':    endDate!.toIso8601String().substring(0, 10),
                        if (staffId != null) 'staff_id': staffId,
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
                    : const Text('Create Batch'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    _load();
  }

  // ── Add Member to batch ───────────────────────────────────────────
  Future<void> _showAddMember() async {
    if (_batches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create a batch first before adding members.')));
      return;
    }

    String? batchId   = _batches.first['id'] as String?;
    String? memberId;
    bool    saving    = false;

    // Load all members to pick from
    List<dynamic> allMembers = [];
    try {
      final res = await _memberSvc.getMembers(limit: 200);
      allMembers = (res['data'] as List<dynamic>?) ?? [];
    } catch (_) {}

    // Exclude already enrolled
    final enrolledIds = _members.map((m) => m['id'] as String).toSet();

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
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Expanded(child: Text('Add Member to Course',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              IconButton(icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 16),

            // Select batch
            DropdownButtonFormField<String>(
              value: batchId,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.group_outlined), labelText: 'Batch *'),
              items: _batches.map((b) {
                final bt = b as Map<String, dynamic>;
                return DropdownMenuItem<String>(
                  value: bt['id'] as String,
                  child: Text('${bt['name']} (${bt['enrolled_count'] ?? 0} enrolled)'),
                );
              }).toList(),
              onChanged: (v) => setSS(() => batchId = v),
            ),
            const SizedBox(height: 12),

            // Select member
            DropdownButtonFormField<String>(
              value: memberId,
              hint: const Text('Select Member *'),
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_outline), labelText: 'Member'),
              items: allMembers
                .where((m) => !enrolledIds.contains((m as Map)['id']))
                .map((m) {
                  final mb = m as Map<String, dynamic>;
                  return DropdownMenuItem<String>(
                    value: mb['id'] as String,
                    child: Text(mb['name'] as String? ?? ''),
                  );
                }).toList(),
              onChanged: (v) => setSS(() => memberId = v),
            ),
            const SizedBox(height: 20),

            FilledButton(
              onPressed: (saving || batchId == null || memberId == null) ? null : () async {
                setSS(() => saving = true);
                try {
                  await _svc.enrollMemberToCourse(
                      courseId: widget.id, memberId: memberId!, batchId: batchId!);
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
                : const Text('Enroll Member'),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
    _load();
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_course?['name'] ?? 'Course'),
      actions: [
        if (_tabs.index == 0)
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Batch',
            onPressed: _showAddBatch,
          ),
        if (_tabs.index == 1)
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Add Member',
            onPressed: _showAddMember,
          ),
      ],
      bottom: TabBar(
        controller: _tabs,
        onTap: (_) => setState(() {}),
        tabs: [
          Tab(text: 'Batches (${_batches.length})'),
          Tab(text: 'Members (${_members.length})'),
        ],
      ),
    ),
    body: _loading
      ? const Center(child: CircularProgressIndicator())
      : TabBarView(
          controller: _tabs,
          children: [
            // ── Batches tab ──────────────────────────────────────
            _batches.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.group_outlined, size: 64,
                        color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 12),
                    const Text('No batches yet'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Batch'),
                      onPressed: _showAddBatch,
                    ),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _batches.length,
                    itemBuilder: (_, i) {
                      final b = _batches[i] as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.group_outlined)),
                          title: Text(b['name'] as String,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${b['enrolled_count'] ?? 0} enrolled'
                                  '${b['capacity'] != null ? ' / ${b['capacity']} max' : ''}'),
                              if (b['staff_name'] != null)
                                Text('Instructor: ${b['staff_name']}',
                                    style: const TextStyle(fontSize: 12)),
                              if (b['schedule_time'] != null)
                                Text(b['schedule_time'] as String,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          trailing: _StatusChip(b['status'] as String? ?? 'active'),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),

            // ── Members tab ──────────────────────────────────────
            _members.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.people_outline, size: 64,
                        color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 12),
                    const Text('No members enrolled yet'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('Add Member'),
                      onPressed: _showAddMember,
                    ),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _members.length,
                    itemBuilder: (_, i) {
                      final m = _members[i] as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              (m['name'] as String? ?? '?').substring(0, 1).toUpperCase(),
                            ),
                          ),
                          title: Text(m['name'] as String? ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(m['batch_name'] as String? ?? ''),
                          trailing: _StatusChip(
                              m['enrollment_status'] as String? ?? 'active'),
                        ),
                      );
                    },
                  ),
                ),
          ],
        ),
    floatingActionButton: _loading ? null : FloatingActionButton.extended(
      icon: Icon(_tabs.index == 0 ? Icons.add : Icons.person_add_outlined),
      label: Text(_tabs.index == 0 ? 'Add Batch' : 'Add Member'),
      onPressed: _tabs.index == 0 ? _showAddBatch : _showAddMember,
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active'   => Colors.green,
      'inactive' => Colors.grey,
      'dropped'  => Colors.red,
      'completed'=> Colors.blue,
      _          => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(status,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}