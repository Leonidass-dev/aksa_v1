import 'package:aksa_v1/utils/app_logger.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'interfaces/i_auth_service.dart';
import 'api_service.dart';

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
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn().timeout(const Duration(minutes: 2));
      if (googleUser == null) {
        return AuthResult.error('Google girişi iptal edildi veya bir hata oluştu.');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null && accessToken == null) {
        return AuthResult.error('Google kimlik doğrulama verileri alınamadı.');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      
      if (user == null) {
        return AuthResult.error('Firebase oturumu açılamadı.');
      }

      return AuthResult.success(user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_firebaseErrorMessage(e.code));
    } catch (e) {
      AppLogger.debug("Google Sign-In Error: $e");
      return AuthResult.error('Google girişi şu an yapılamıyor. Lütfen tekrar deneyin.');
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
        webAuthenticationOptions: WebAuthenticationOptions(
          // NOT: Bu değerlerin Apple Developer Portal'dan alınması gerekir.
          // Android'de Apple Login'in çalışması için bu yapılandırma şarttır.
          clientId: 'com.aksa.health.service', 
          redirectUri: Uri.parse(
            'https://aksa-health.firebaseapp.com/__/auth/handler',
          ),
        ),
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
      return AuthResult.error('Apple girişi şu an kullanılamıyor. Lütfen Google veya e-posta ile giriş yapın.');
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_firebaseErrorMessage(e.code));
    } catch (e) {
      AppLogger.debug("Apple Login Error: $e");
      return AuthResult.error('Cihazınızda Apple ile giriş desteklenmiyor olabilir. Lütfen başka bir yöntem deneyin.');
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

  // ── Hesabı Sil (Soft Delete - 30 Gün Bekleme) ──────────────────────────
  @override
  Future<AuthResult> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return AuthResult.error('Kullanıcı bulunamadı.');

      // Firestore'a silinme tarihini yaz (Şu an + 30 gün)
      final deletionDate = DateTime.now().add(const Duration(days: 30));
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'deletion_scheduled_at': deletionDate.toIso8601String()},
        SetOptions(merge: true),
      );

      // Oturumu kapat
      await signOut();

      return AuthResult.successMessage('Hesabınız silinmek üzere işaretlendi ve 30 gün sonra kalıcı olarak silinecek.');
    } catch (e) {
      return AuthResult.error('İşlem başarısız: ${e.toString()}');
    }
  }

  @override
  Future<bool> hardDeleteAccount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // 1. Backend'den kalıcı olarak sil
      final backendSuccess = await ApiService.deleteUserFromBackend();
      if (!backendSuccess) {
        AppLogger.debug("Backend deletion failed, but proceeding to delete Firebase auth");
      }

      // 2. Firestore verilerini sil
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();

      // 3. Firebase Auth hesabını sil
      await user.delete();

      // 4. Çıkış yap
      await signOut();
      return true;
    } catch (e) {
      AppLogger.debug('Hard delete error: $e');
      return false;
    }
  }

  // ── Silme İptali (Restore) ───────────────────────────────────────────────
  @override
  Future<bool> restoreAccount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'deletion_scheduled_at': FieldValue.delete(),
      });
      return true;
    } catch (e) {
      AppLogger.debug('Restore account error: $e');
      return false;
    }
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
  static Future<AuthResult> deleteAccount() => _instance.deleteAccount();
  static Future<bool> hardDeleteAccount() => _instance.hardDeleteAccount();
  static Future<bool> restoreAccount() => _instance.restoreAccount();
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
