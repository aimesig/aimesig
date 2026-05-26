import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<void> sendOtp({
    required String phone,
    required Function(String) codeSent,
  }) async {
    await auth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (credential) {},
      verificationFailed: (e) {
        print(e.message);
      },
      codeSent: (verificationId, resendToken) {
        codeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (verificationId) {},
    );
  }
}