// lib/features/attendance/presentation/screens/attendance_screen.dart

import 'package:flutter/material.dart';
import '../../attendance_service.dart';
import '../../../../core/theme/app_theme.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  final _svc = AttendanceService();

  // Tabs: Report | Take Attendance
  late final TabController _tabs;

  // ── Report state ────────────────────────────────────────────────
  List<dynamic> _report      = [];
  List<dynamic> _myBatches   = [];
  String?       _filterBatch;
  bool          _reportLoading = true;
  String        _from = DateTime.now()
      .subtract(const Duration(days: 30))
      .toIso8601String()
      .substring(0, 10);
  String        _to  = DateTime.now().toIso8601String().substring(0, 10);

  // ── Take Attendance state ─────────────────────────────────────
  String?       _selectedBatchId;
  String?       _selectedBatchName;
  String        _sessionDate = DateTime.now().toIso8601String().substring(0, 10);
  List<dynamic> _sessionMembers = [];
  // memberId → status
  final Map<String, String> _statuses = {};
  bool _sessionLoading = false;
  bool _submitting     = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadBatches();
  }

  @override void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _loadBatches() async {
    try {
      _myBatches = await _svc.getMyBatches();
    } catch (_) {
      _myBatches = [];
    }
    await _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _reportLoading = true);
    try {
      _report = await _svc.getAttendanceReport(
        batchId: _filterBatch,
        from: _from,
        to:   _to,
      );
    } catch (_) { _report = []; }
    if (mounted) setState(() => _reportLoading = false);
  }

  Future<void> _loadSessionMembers() async {
    if (_selectedBatchId == null) return;
    setState(() { _sessionLoading = true; _statuses.clear(); });
    try {
      _sessionMembers = await _svc.getBatchMembers(
          _selectedBatchId!, date: _sessionDate);
      // Pre-fill any already-marked status
      for (final m in _sessionMembers) {
        final mm  = m as Map<String, dynamic>;
        final mid = mm['member_id'] as String;
        final existing = mm['attendance_status'] as String?;
        _statuses[mid] = existing ?? 'present';
      }
    } catch (_) { _sessionMembers = []; }
    if (mounted) setState(() => _sessionLoading = false);
  }

  Future<void> _submitBulk() async {
    if (_selectedBatchId == null || _sessionMembers.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final records = _statuses.entries
          .map((e) => {'member_id': e.key, 'status': e.value})
          .toList();
      final result = await _svc.bulkMark(
        batchId: _selectedBatchId!,
        date:    _sessionDate,
        records: records,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Attendance saved: ${result['marked']} of ${result['total']} records'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Status color ─────────────────────────────────────────────────
  Color _statusColor(String s) => switch (s) {
    'present' => AppTheme.success,
    'late'    => AppTheme.warning,
    _         => AppTheme.error,
  };

  // ── BUILD ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Attendance'),
      bottom: TabBar(
        controller: _tabs,
        tabs: const [
          Tab(icon: Icon(Icons.bar_chart_outlined),  text: 'Report'),
          Tab(icon: Icon(Icons.how_to_reg_outlined), text: 'Take Attendance'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabs,
      children: [
        _buildReport(),
        _buildTakeAttendance(),
      ],
    ),
  );

  // ── Report tab ────────────────────────────────────────────────────
  Widget _buildReport() => Column(
    children: [
      // Filter bar
      Container(
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(children: [
          // Batch filter (if batches available)
          if (_myBatches.isNotEmpty)
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _filterBatch,
                  hint: const Text('All Batches', style: TextStyle(fontSize: 13)),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Batches', style: TextStyle(fontSize: 13))),
                    ..._myBatches.map((b) {
                      final bt = b as Map<String, dynamic>;
                      return DropdownMenuItem<String?>(
                        value: bt['id'] as String,
                        child: Text(
                          '${bt['course_name']} – ${bt['batch_name']}',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (v) {
                    setState(() => _filterBatch = v);
                    _loadReport();
                  },
                ),
              ),
            ),
          const SizedBox(width: 8),
          // Date range button
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range_outlined, size: 16),
            label: Text('${_from.substring(5)} → ${_to.substring(5)}',
                style: const TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
            onPressed: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange: DateTimeRange(
                  start: DateTime.parse(_from),
                  end:   DateTime.parse(_to),
                ),
              );
              if (range != null) {
                setState(() {
                  _from = range.start.toIso8601String().substring(0, 10);
                  _to   = range.end.toIso8601String().substring(0, 10);
                });
                _loadReport();
              }
            },
          ),
        ]),
      ),
      const Divider(height: 1),
      // Report list
      Expanded(
        child: _reportLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReport,
              child: _report.isEmpty
                ? const Center(child: Text('No attendance data for this period'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _report.length,
                    itemBuilder: (_, i) {
                      final r   = _report[i] as Map<String, dynamic>;
                      final pct = double.tryParse(r['pct']?.toString() ?? '0') ?? 0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(child: Text(r['name'] as String? ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.w600))),
                                Text('${pct.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: _statusColor(
                                          pct >= 75 ? 'present' : pct >= 50 ? 'late' : 'absent'),
                                    )),
                              ]),
                              if (r['batch_name'] != null)
                                Text(r['batch_name'] as String,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.outline)),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  minHeight: 7,
                                  value: pct / 100,
                                  backgroundColor: Colors.grey.shade200,
                                  color: _statusColor(
                                    pct >= 75 ? 'present' : pct >= 50 ? 'late' : 'absent'),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(children: [
                                _StatPill('✓ ${r['present']}', Colors.green),
                                const SizedBox(width: 6),
                                _StatPill('✗ ${r['absent']}', Colors.red),
                                const SizedBox(width: 6),
                                _StatPill('⏱ ${r['late']}', Colors.orange),
                              ]),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
      ),
    ],
  );

  // ── Take Attendance tab ───────────────────────────────────────────
  Widget _buildTakeAttendance() {
    if (_myBatches.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.group_off_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No batches assigned.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('Ask your admin to assign a batch to your account.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ]),
        ),
      );
    }

    return Column(
      children: [
        // Batch + date selector
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(children: [
            DropdownButtonFormField<String>(
              value: _selectedBatchId,
              hint: const Text('Select Batch'),
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.group_outlined),
                  labelText: 'Batch',
                  isDense: true),
              items: _myBatches.map((b) {
                final bt = b as Map<String, dynamic>;
                return DropdownMenuItem<String>(
                  value: bt['id'] as String,
                  child: Text(
                    '${bt['course_name']} – ${bt['batch_name']}',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (v) {
                final batch = _myBatches.firstWhere(
                    (b) => (b as Map)['id'] == v, orElse: () => null);
                setState(() {
                  _selectedBatchId   = v;
                  _selectedBatchName = batch != null
                    ? '${batch['course_name']} – ${batch['batch_name']}'
                    : null;
                });
                _loadSessionMembers();
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text('Date: $_sessionDate'),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null) {
                  setState(() =>
                      _sessionDate = d.toIso8601String().substring(0, 10));
                  _loadSessionMembers();
                }
              },
            ),
          ]),
        ),
        const Divider(height: 1),

        // Members list
        Expanded(
          child: _sessionLoading
            ? const Center(child: CircularProgressIndicator())
            : _selectedBatchId == null
              ? const Center(
                  child: Text('Select a batch above to take attendance'))
              : _sessionMembers.isEmpty
                ? const Center(child: Text('No active members in this batch'))
                : Column(
                    children: [
                      // Quick-set row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(children: [
                          const Text('Mark all:',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 10),
                          _QuickSetBtn('Present', Colors.green, () => _markAll('present')),
                          const SizedBox(width: 6),
                          _QuickSetBtn('Absent',  Colors.red,   () => _markAll('absent')),
                          const SizedBox(width: 6),
                          _QuickSetBtn('Late',    Colors.orange,() => _markAll('late')),
                        ]),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _sessionMembers.length,
                          itemBuilder: (_, i) {
                            final m   = _sessionMembers[i] as Map<String, dynamic>;
                            final mid = m['member_id'] as String;
                            final s   = _statuses[mid] ?? 'present';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _statusColor(s).withOpacity(0.15),
                                child: Text(
                                  (m['member_name'] as String? ?? '?')
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: TextStyle(color: _statusColor(s),
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              title: Text(m['member_name'] as String? ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: m['member_no'] != null
                                ? Text(m['member_no'] as String, style: const TextStyle(fontSize: 12))
                                : null,
                              trailing: SegmentedButton<String>(
                                showSelectedIcon: false,
                                style: ButtonStyle(
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                                segments: const [
                                  ButtonSegment(value: 'present', label: Text('P', style: TextStyle(fontSize: 12))),
                                  ButtonSegment(value: 'late',    label: Text('L', style: TextStyle(fontSize: 12))),
                                  ButtonSegment(value: 'absent',  label: Text('A', style: TextStyle(fontSize: 12))),
                                ],
                                selected: {s},
                                onSelectionChanged: (sel) =>
                                    setState(() => _statuses[mid] = sel.first),
                              ),
                            );
                          },
                        ),
                      ),
                      // Submit bar
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: FilledButton.icon(
                          icon: const Icon(Icons.save_outlined),
                          label: _submitting
                            ? const SizedBox(height: 18, width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white))
                            : Text('Save Attendance (${_sessionMembers.length} members)'),
                          onPressed: _submitting ? null : _submitBulk,
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48)),
                        ),
                      ),
                    ],
                  ),
        ),
      ],
    );
  }

  void _markAll(String status) {
    setState(() {
      for (final m in _sessionMembers) {
        final mid = (m as Map<String, dynamic>)['member_id'] as String;
        _statuses[mid] = status;
      }
    });
  }
}

// ── Small widgets ─────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  const _StatPill(this.label, this.color);
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
  );
}

class _QuickSetBtn extends StatelessWidget {
  const _QuickSetBtn(this.label, this.color, this.onTap);
  final String   label;
  final Color    color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    ),
  );
}