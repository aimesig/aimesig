// lib/features/courses/presentation/screens/courses_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../courses_service.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});
  @override State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final _svc = CoursesService();
  List<dynamic> _courses = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try { _courses = await _svc.getCourses(); } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _showAddCourse() async {
    final formKey   = GlobalKey<FormState>();
    final name      = TextEditingController();
    final desc      = TextEditingController();
    final fee       = TextEditingController();
    final duration  = TextEditingController();
    String? category;
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Expanded(child: Text('New Course', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Course Name *', prefixIcon: Icon(Icons.school_outlined)),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: desc,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.notes_outlined)),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: fee,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Fee (₹) *', prefixIcon: Icon(Icons.currency_rupee)),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: duration,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Duration (months)', prefixIcon: Icon(Icons.timer_outlined)),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  hint: const Text('Category'),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined), labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'academic',   child: Text('Academic')),
                    DropdownMenuItem(value: 'sports',     child: Text('Sports')),
                    DropdownMenuItem(value: 'arts',       child: Text('Arts & Music')),
                    DropdownMenuItem(value: 'language',   child: Text('Language')),
                    DropdownMenuItem(value: 'technology', child: Text('Technology')),
                    DropdownMenuItem(value: 'other',      child: Text('Other')),
                  ],
                  onChanged: (v) => setSheetState(() => category = v),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: saving ? null : () async {
                    if (!formKey.currentState!.validate()) return;
                    setSheetState(() => saving = true);
                    try {
                      await _svc.createCourse({
                        'name':        name.text.trim(),
                        'description': desc.text.trim().isEmpty ? null : desc.text.trim(),
                        'fee':         double.tryParse(fee.text.trim()) ?? 0,
                        if (duration.text.trim().isNotEmpty)
                          'duration_months': int.tryParse(duration.text.trim()),
                        if (category != null) 'category': category,
                      });
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      setSheetState(() => saving = false);
                      if (ctx.mounted)
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Error: $e')));
                    }
                  },
                  child: saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Create Course'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    // Refresh list after closing sheet
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Courses (${_courses.length})')),
    body: _loading ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(
          onRefresh: _load,
          child: _courses.isEmpty
            ? const Center(child: Text('No courses yet. Tap + to add one.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _courses.length,
                itemBuilder: (_, i) {
                  final c = _courses[i] as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.school_outlined)),
                      title: Text(c['name'] as String? ?? ''),
                      subtitle: Text('${c['batch_count'] ?? 0} batches • ₹${c['fee'] ?? 0}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/courses/${c['id']}'),
                    ),
                  );
                },
              ),
        ),
    floatingActionButton: FloatingActionButton.extended(
      icon: const Icon(Icons.add),
      label: const Text('New Course'),
      onPressed: _showAddCourse,
    ),
  );
}