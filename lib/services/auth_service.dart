import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'interfaces/i_auth_service.dart';

class AuthServiceImpl implements IAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Mevcut kullanıcı stream'i
  @override
  Stream<User?> get userStream => _auth.authStateChanges();

  // Mevcut kullanıcı
  @override
  User? get currentUser => _auth.currentUser;

  // ── Email + Şifre: Kayıt ────────────────────────────────────────────────
  @override
  Future<AuthResult> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // Kullanıcı adını güncelle
      await credential.user?.updateDisplayName(name.trim());
      await credential.user?.reload();
      return AuthResult.success(credential.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_firebaseErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Beklenmeyen bir hata oluştu.');
    }
  }

  // ── Email + Şifre: Giriş ────────────────────────────────────────────────
  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthResult.success(credential.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_firebaseErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Beklenmeyen bir hata oluştu.');
    }
  }

  // ── Google ile Giriş ────────────────────────────────────────────────────
  @override
  Future<AuthResult> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.error('Google girişi iptal edildi.');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      return AuthResult.success(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_firebaseErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Google girişi başarısız: ${e.toString()}');
    }
  }

  // ── Apple ile Giriş ─────────────────────────────────────────────────────
  @override
  Future<AuthResult> signInWithApple() async {
    try {
      // Nonce üret (güvenlik için gerekli)
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider(
        'apple.com',
      ).credential(idToken: appleCredential.identityToken, rawNonce: rawNonce);

      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // Apple sadece ilk girişte isim verir — güncelle
      final fullName = [
        appleCredential.givenName,
        appleCredential.familyName,
      ].where((s) => s != null && s.isNotEmpty).join(' ');

      if (fullName.isNotEmpty &&
          (userCredential.user?.displayName == null ||
              userCredential.user!.displayName!.isEmpty)) {
        await userCredential.user?.updateDisplayName(fullName);
      }

      return AuthResult.success(userCredential.user!);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AuthResult.error('Apple girişi iptal edildi.');
      }
      return AuthResult.error('Apple girişi başarısız: ${e.message}');
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_firebaseErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Apple girişi başarısız: ${e.toString()}');
    }
  }

  // ── Şifre Sıfırlama ─────────────────────────────────────────────────────
  @override
  Future<AuthResult> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.successMessage(
        '$email adresine sıfırlama bağlantısı gönderildi.',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_firebaseErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('E-posta gönderilemedi.');
    }
  }

  // ── Çıkış ───────────────────────────────────────────────────────────────
  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── Nonce Yardımcıları (Apple için) ─────────────────────────────────────
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ── Firebase Hata Mesajları ──────────────────────────────────────────────
  String _firebaseErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanımda.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'weak-password':
        return 'Şifre en az 6 karakter olmalıdır.';
      case 'user-not-found':
        return 'Bu e-posta adresiyle kayıtlı kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'Şifre hatalı.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen bekleyin.';
      case 'network-request-failed':
        return 'Ağ bağlantısı hatası. İnternet bağlantınızı kontrol edin.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış.';
      case 'operation-not-allowed':
        return 'Bu giriş yöntemi şu an kullanılabilir değil.';
      default:
        return 'Bir hata oluştu ($code). Lütfen tekrar deneyin.';
    }
  }
}

/// Test edilebilir Statik Facade yapısı.
class AuthService {
  static IAuthService _instance = AuthServiceImpl();

  @visibleForTesting
  static set instance(IAuthService mock) => _instance = mock;

  static Stream<User?> get userStream => _instance.userStream;
  static User? get currentUser => _instance.currentUser;

  static Future<AuthResult> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) => _instance.registerWithEmail(name: name, email: email, password: password);

  static Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) => _instance.signInWithEmail(email: email, password: password);

  static Future<AuthResult> signInWithGoogle() => _instance.signInWithGoogle();
  static Future<AuthResult> signInWithApple() => _instance.signInWithApple();
  static Future<AuthResult> sendPasswordReset(String email) => _instance.sendPasswordReset(email);
  static Future<void> signOut() => _instance.signOut();
}

// ── Sonuç Modeli ─────────────────────────────────────────────────────────────
class AuthResult {
  final bool isSuccess;
  final User? user;
  final String? errorMessage;
  final String? successMessage;

  const AuthResult._({
    required this.isSuccess,
    this.user,
    this.errorMessage,
    this.successMessage,
  });

  factory AuthResult.success(User user) =>
      AuthResult._(isSuccess: true, user: user);

  factory AuthResult.successMessage(String message) =>
      AuthResult._(isSuccess: true, successMessage: message);

  factory AuthResult.error(String message) =>
      AuthResult._(isSuccess: false, errorMessage: message);
}
