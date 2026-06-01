// lib/features/auth/presentation/screens/register_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _orgName   = TextEditingController();
  final _adminName = TextEditingController();
  final _email     = TextEditingController();
  final _password  = TextEditingController();
  final _svc       = AuthService();

  bool _loading = false;
  String? _error;
  String _orgType = 'school';

  @override
  void dispose() {
    _orgName.dispose();
    _adminName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await _svc.register(
        orgName:       _orgName.text.trim(),
        adminName:     _adminName.text.trim(),
        adminEmail:    _email.text.trim(),
        adminPassword: _password.text,
        orgType:       _orgType,
      );
      if (mounted) context.go('/dashboard');
    } catch (e) {
      final msg = e.toString();
      setState(() => _error = msg.contains('409')
          ? 'Email or organisation name already exists.'
          : 'Registration failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Organisation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/auth/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFDC2626)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Org type selector
                  DropdownButtonFormField<String>(
                    value: _orgType,
                    decoration: const InputDecoration(
                      labelText: 'Organisation Type',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'school',  child: Text('School')),
                      DropdownMenuItem(value: 'gym',     child: Text('Gym / Fitness')),
                      DropdownMenuItem(value: 'academy', child: Text('Academy')),
                      DropdownMenuItem(value: 'coaching',child: Text('Coaching Centre')),
                      DropdownMenuItem(value: 'other',   child: Text('Other')),
                    ],
                    onChanged: (v) => setState(() => _orgType = v!),
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _orgName,
                    decoration: const InputDecoration(
                      labelText: 'Organisation Name',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Organisation name is required' : null,
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _adminName,
                    decoration: const InputDecoration(
                      labelText: 'Your Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Admin Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Valid email required' : null,
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      helperText: 'At least 8 characters',
                    ),
                    validator: (v) =>
                        (v == null || v.length < 8) ? 'Minimum 8 characters' : null,
                  ),
                  const SizedBox(height: 28),

                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Create Organisation'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/auth/login'),
                    child: const Text('Already have an account? Sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
