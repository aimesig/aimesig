import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  ConfirmationResult? _pendingConfirmation;
  RecaptchaVerifier? _recaptchaVerifier;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onError,
  }) async {
    if (kIsWeb) {
      try {
        // In debug mode, disable app verification so test numbers work
        // without reCAPTCHA. Remove this for production builds.
        if (kDebugMode) {
          await _auth.setSettings(appVerificationDisabledForTesting: true);
        }

        _recaptchaVerifier?.clear();

        final authPlatform = FirebaseAuthPlatform.instanceFor(
          app: Firebase.app(),
          pluginConstants: {},
        );

        _recaptchaVerifier = RecaptchaVerifier(
          auth: authPlatform,
        );

        final confirmationResult = await _auth.signInWithPhoneNumber(
          phoneNumber,
          _recaptchaVerifier,
        );
        _pendingConfirmation = confirmationResult;
        onCodeSent(confirmationResult.verificationId);
      } on FirebaseAuthException catch (e) {
        _recaptchaVerifier?.clear();
        _recaptchaVerifier = null;
        onError(e.message ?? 'Failed to send OTP');
      } catch (e) {
        _recaptchaVerifier?.clear();
        _recaptchaVerifier = null;
        onError(e.toString());
      }
    } else {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    }
  }

  Future<UserCredential> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    if (kIsWeb && _pendingConfirmation != null) {
      return await _pendingConfirmation!.confirm(smsCode);
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    _pendingConfirmation = null;
    _recaptchaVerifier?.clear();
    _recaptchaVerifier = null;
    await _auth.signOut();
  }
}