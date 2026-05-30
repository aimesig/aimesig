import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.status == AuthStatus.loading;
    final otpSent = authState.status == AuthStatus.otpSent;

    ref.listen<AuthState>(authControllerProvider, (_, next) {
      if (next.status == AuthStatus.success) {
        context.go('/home');
      }
      if (next.status == AuthStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red.shade700,
          ),
        );
        ref.read(authControllerProvider.notifier).resetError();
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const Text(
                'Welcome 👋',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                otpSent
                    ? 'Enter the OTP sent to ${authState.phoneNumber}'
                    : 'Enter your phone number to continue',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 40),

              if (!otpSent) ...[
                _label('Phone Number'),
                _textField(
                  controller: _phoneController,
                  hint: '+91 98765 43210',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 28),
                _primaryButton(
                  label: 'Send OTP',
                  loading: isLoading,
                  onPressed: () => ref
                      .read(authControllerProvider.notifier)
                      .sendOtp(_phoneController.text.trim()),
                ),
              ],

              if (otpSent) ...[
                _label('One-Time Password'),
                _otpField(),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            _otpController.clear();
                            ref
                                .read(authControllerProvider.notifier)
                                .resendOtp();
                          },
                    child: const Text('Resend OTP'),
                  ),
                ),
                const SizedBox(height: 16),
                _primaryButton(
                  label: 'Verify & Sign In',
                  loading: isLoading,
                  onPressed: () => ref
                      .read(authControllerProvider.notifier)
                      .verifyOtp(_otpController.text.trim()),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () {
                      _phoneController.clear();
                      _otpController.clear();
                      ref.read(authControllerProvider.notifier).resetError();
                    },
                    child: const Text('Change number'),
                  ),
                ),
              ],

              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/register'),
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  InputDecoration _decoration({required String hint, required IconData icon}) =>
      InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) =>
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: _decoration(hint: hint, icon: icon),
      );

  // 6 individual OTP boxes
  Widget _otpField() => TextField(
        controller: _otpController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, letterSpacing: 12, fontWeight: FontWeight.bold),
        decoration: _decoration(hint: '• • • • • •', icon: Icons.sms_outlined)
            .copyWith(counterText: ''),
      );

  Widget _primaryButton({
    required String label,
    required bool loading,
    required VoidCallback onPressed,
  }) =>
      SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: loading ? null : onPressed,
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(label, style: const TextStyle(fontSize: 16)),
        ),
      );
}