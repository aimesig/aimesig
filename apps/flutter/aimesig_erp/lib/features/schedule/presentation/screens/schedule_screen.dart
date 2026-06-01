// lib/features/schedule/presentation/screens/schedule_screen.dart
import 'package:flutter/material.dart';
import '../../schedule_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/courses/courses_service.dart';
import '../../../../features/staff/staff_service.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _svc     = ScheduleService();
  final _crsvc   = CoursesService();
  final _staffsvc = StaffService();
  List<dynamic>         _slots     = [];
  List<dynamic>         _courses   = [];
  List<dynamic>         _staff     = [];
  Map<String, dynamic>? _conflicts;
  bool _loading = true;

  static const _days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Future.wait<dynamic>([
        _svc.getSlots(),
        _svc.getConflicts(),
        _crsvc.getCourses(),
        _staffsvc.getStaff(),
      ]);
      setState(() {
        _slots     = res[0] as List<dynamic>;
        _conflicts = res[1] as Map<String, dynamic>?;
        _courses   = res[2] as List<dynamic>;
        _staff     = res[3] as List<dynamic>;
        _loading   = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _showAddSlot() async {
    final formKey      = GlobalKey<FormState>();
    String? courseId;
    String? batchId;
    String? staffId;
    List<dynamic> batches = [];
    int    dayOfWeek   = 0;
    final  startCtrl   = TextEditingController(text: '09:00');
    final  endCtrl     = TextEditingController(text: '10:00');
    final  roomCtrl    = TextEditingController();
    bool   saving      = false;
    bool   loadingBatches = false;

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
                  const Expanded(child: Text('New Schedule Slot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 12),
                // Course picker
                DropdownButtonFormField<String>(
                  value: courseId,
                  hint: const Text('Select Course *'),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.school_outlined), labelText: 'Course'),
                  validator: (v) => v == null ? 'Select a course' : null,
                  items: _courses.map((c) {
                    final cc = c as Map<String, dynamic>;
                    return DropdownMenuItem<String>(value: cc['id'] as String, child: Text(cc['name'] as String? ?? ''));
                  }).toList(),
                  onChanged: (v) async {
                    setS(() { courseId = v; batchId = null; batches = []; loadingBatches = true; });
                    try {
                      final b = await _crsvc.getBatches(v!);
                      setS(() { batches = b; loadingBatches = false; });
                    } catch (_) { setS(() => loadingBatches = false); }
                  },
                ),
                const SizedBox(height: 12),
                // Batch picker
                if (loadingBatches)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator())
                else if (batches.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: batchId,
                    hint: const Text('Select Batch'),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.group_outlined), labelText: 'Batch'),
                    items: batches.map((b) {
                      final bb = b as Map<String, dynamic>;
                      return DropdownMenuItem<String>(value: bb['id'] as String, child: Text(bb['name'] as String? ?? ''));
                    }).toList(),
                    onChanged: (v) => setS(() => batchId = v),
                  ),
                const SizedBox(height: 12),
                // Staff picker
                DropdownButtonFormField<String>(
                  value: staffId,
                  hint: const Text('Assign Staff'),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.badge_outlined), labelText: 'Staff'),
                  items: _staff.map((s) {
                    final ss = s as Map<String, dynamic>;
                    return DropdownMenuItem<String>(value: ss['id'] as String, child: Text(ss['name'] as String? ?? ''));
                  }).toList(),
                  onChanged: (v) => setS(() => staffId = v),
                ),
                const SizedBox(height: 12),
                // Day of week
                const Text('Day of Week', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: List.generate(7, (i) => ChoiceChip(
                    label: Text(_days[i], style: const TextStyle(fontSize: 12)),
                    selected: dayOfWeek == i,
                    onSelected: (_) => setS(() => dayOfWeek = i),
                  )),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: startCtrl,
                      decoration: const InputDecoration(labelText: 'Start Time *', prefixIcon: Icon(Icons.access_time_outlined), hintText: '09:00'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      onTap: () async {
                        final t = await showTimePicker(context: ctx, initialTime: const TimeOfDay(hour: 9, minute: 0));
                        if (t != null) setS(() => startCtrl.text = '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}');
                      },
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: endCtrl,
                      decoration: const InputDecoration(labelText: 'End Time *', prefixIcon: Icon(Icons.access_time_outlined), hintText: '10:00'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      onTap: () async {
                        final t = await showTimePicker(context: ctx, initialTime: const TimeOfDay(hour: 10, minute: 0));
                        if (t != null) setS(() => endCtrl.text = '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}');
                      },
                      readOnly: true,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: roomCtrl,
                  decoration: const InputDecoration(labelText: 'Room / Location (optional)', prefixIcon: Icon(Icons.room_outlined)),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: saving ? null : () async {
                    if (!formKey.currentState!.validate()) return;
                    setS(() => saving = true);
                    try {
                      await _svc.createSlot({
                        'course_id':   courseId,
                        if (batchId  != null) 'batch_id':  batchId,
                        if (staffId  != null) 'staff_id':  staffId,
                        'day_of_week': dayOfWeek,
                        'start_time':  startCtrl.text.trim(),
                        'end_time':    endCtrl.text.trim(),
                        if (roomCtrl.text.trim().isNotEmpty) 'room': roomCtrl.text.trim(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      setS(() => saving = false);
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  child: saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Create Slot'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final conflictCount = (_conflicts?['count'] as int?) ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        actions: [
          if (conflictCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: Text('$conflictCount conflicts', style: const TextStyle(fontSize: 12)),
                backgroundColor: AppTheme.error.withOpacity(0.12),
                side: BorderSide(color: AppTheme.error.withOpacity(0.3)),
              ),
            ),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: _slots.isEmpty
              ? const Center(child: Text('No schedule slots. Tap + to create one.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _slots.length,
                  itemBuilder: (_, i) {
                    final s = _slots[i] as Map<String, dynamic>;
                    final dow = s['day_of_week'] as int?;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primary.withOpacity(0.1),
                          child: Text(
                            dow != null && dow >= 0 && dow < 7 ? _days[dow] : '—',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary),
                          ),
                        ),
                        title: Text(s['batch_name'] ?? s['course_name'] ?? 'Unassigned'),
                        subtitle: Text('${s['start_time']} – ${s['end_time']}  •  ${s['staff_name'] ?? 'No staff'}'),
                        trailing: s['room'] != null
                          ? Chip(label: Text(s['room'] as String, style: const TextStyle(fontSize: 11))) : null,
                      ),
                    );
                  },
                ),
          ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Slot'),
        onPressed: _showAddSlot,
      ),
    );
  }
}