import 'package:firebase_auth/firebase_auth.dart' show User;
import '../auth_service.dart' show AuthResult;

abstract class IAuthService {
  Stream<User?> get userStream;
  User? get currentUser;

  Future<AuthResult> registerWithEmail({
    required String name,
    required String email,
    required String password,
  });

  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AuthResult> signInWithGoogle();
  Future<AuthResult> signInWithApple();
  Future<AuthResult> sendPasswordReset(String email);
  Future<void> signOut();
  Future<AuthResult> deleteAccount();
  Future<bool> hardDeleteAccount();
  Future<bool> restoreAccount();
}
