// lib/features/admissions/presentation/screens/admissions_screen.dart
import 'package:flutter/material.dart';
import '../../admissions_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/courses/courses_service.dart';

class AdmissionsScreen extends StatefulWidget {
  const AdmissionsScreen({super.key});
  @override State<AdmissionsScreen> createState() => _AdmissionsScreenState();
}

class _AdmissionsScreenState extends State<AdmissionsScreen> {
  final _svc    = AdmissionsService();
  final _crsvc  = CoursesService();
  List<dynamic> _leads    = [];
  List<dynamic> _pipeline = [];
  List<dynamic> _courses  = [];
  bool _loading = true;
  String? _stage;

  static const _stages = ['new','contacted','demo','negotiation','converted','lost'];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Future.wait<dynamic>([
        _svc.getLeads(stage: _stage),
        _svc.getPipeline(),
        _crsvc.getCourses(),
      ]);
      setState(() {
        _leads    = res[0] as List<dynamic>;
        _pipeline = res[1] as List<dynamic>;
        _courses  = res[2] as List<dynamic>;
        _loading  = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  Color _stageColor(String stage) => switch (stage) {
    'new'         => AppTheme.primary,
    'contacted'   => AppTheme.secondary,
    'demo'        => AppTheme.warning,
    'negotiation' => const Color(0xFF8B5CF6),
    'converted'   => AppTheme.success,
    'lost'        => Colors.grey,
    _             => Colors.blueGrey,
  };

  Future<void> _showNewLead() async {
    final formKey   = GlobalKey<FormState>();
    final nameCtrl  = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String? courseId;
    String  stage   = 'new';
    String? source;
    bool    saving  = false;

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
                  const Expanded(child: Text('New Lead', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone *', prefixIcon: Icon(Icons.phone_outlined)),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: courseId,
                  hint: const Text('Interested In (course)'),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.school_outlined), labelText: 'Course'),
                  items: _courses.map((c) {
                    final cc = c as Map<String, dynamic>;
                    return DropdownMenuItem<String>(value: cc['id'] as String, child: Text(cc['name'] as String? ?? ''));
                  }).toList(),
                  onChanged: (v) => setS(() => courseId = v),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: stage,
                      decoration: const InputDecoration(labelText: 'Stage'),
                      items: _stages.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setS(() => stage = v ?? 'new'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: source,
                      hint: const Text('Source'),
                      decoration: const InputDecoration(labelText: 'Source'),
                      items: const [
                        DropdownMenuItem(value: 'walk_in',   child: Text('Walk-in')),
                        DropdownMenuItem(value: 'referral',  child: Text('Referral')),
                        DropdownMenuItem(value: 'social',    child: Text('Social Media')),
                        DropdownMenuItem(value: 'website',   child: Text('Website')),
                        DropdownMenuItem(value: 'other',     child: Text('Other')),
                      ],
                      onChanged: (v) => setS(() => source = v),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: saving ? null : () async {
                    if (!formKey.currentState!.validate()) return;
                    setS(() => saving = true);
                    try {
                      await _svc.createLead({
                        'name':  nameCtrl.text.trim(),
                        'phone': phoneCtrl.text.trim(),
                        if (emailCtrl.text.trim().isNotEmpty) 'email': emailCtrl.text.trim(),
                        if (courseId != null) 'course_id': courseId,
                        'stage': stage,
                        if (source != null) 'source': source,
                      });
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      setS(() => saving = false);
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  child: saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Add Lead'),
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Admissions Pipeline')),
    body: _loading ? const Center(child: CircularProgressIndicator())
      : Column(children: [
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              children: _stages.map((s) {
                final pipeEntry = _pipeline.firstWhere(
                  (p) => (p as Map)['stage'] == s,
                  orElse: () => {'stage': s, 'count': 0},
                ) as Map;
                final count = int.tryParse(pipeEntry['count'].toString()) ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: _stage == s,
                    label: Text('$s ($count)'),
                    onSelected: (sel) { setState(() => _stage = sel ? s : null); _load(); },
                    selectedColor: _stageColor(s).withOpacity(0.2),
                    checkmarkColor: _stageColor(s),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _leads.isEmpty
                ? const Center(child: Text('No leads found'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _leads.length,
                    itemBuilder: (_, i) {
                      final l = _leads[i] as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _stageColor(l['stage'] ?? 'new').withOpacity(0.15),
                            child: Icon(Icons.person_outline, color: _stageColor(l['stage'] ?? 'new')),
                          ),
                          title: Text(l['name'] as String? ?? ''),
                          subtitle: Text('${l['phone'] ?? ''} • ${l['course_name'] ?? 'No course'}'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _stageColor(l['stage'] ?? 'new').withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(l['stage'] ?? '',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                color: _stageColor(l['stage'] ?? 'new'))),
                          ),
                          onTap: () => _showEditLead(l),
                        ),
                      );
                    },
                  ),
            ),
          ),
        ]),
    floatingActionButton: FloatingActionButton.extended(
      icon: const Icon(Icons.person_add_outlined),
      label: const Text('New Lead'),
      onPressed: _showNewLead,
    ),
  );

  Future<void> _showEditLead(Map<String, dynamic> lead) async {
    String stage = lead['stage'] ?? 'new';
    bool saving  = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(lead['name'] as String? ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 16),
            const Text('Update Stage', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _stages.map((s) => ChoiceChip(
                label: Text(s),
                selected: stage == s,
                selectedColor: _stageColor(s).withOpacity(0.2),
                onSelected: (_) => setS(() => stage = s),
              )).toList(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: saving ? null : () async {
                setS(() => saving = true);
                try {
                  await _svc.updateLead(lead['id'] as String, {'stage': stage});
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  setS(() => saving = false);
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Update Lead'),
            ),
            if (stage != 'converted') ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Convert to Member'),
                onPressed: saving ? null : () async {
                  setS(() => saving = true);
                  try {
                    await _svc.convertLead(lead['id'] as String);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Lead converted to member!')));
                    }
                  } catch (e) {
                    setS(() => saving = false);
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
              ),
            ],
          ]),
        ),
      ),
    );
    _load();
  }
}