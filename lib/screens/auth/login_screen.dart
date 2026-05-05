import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/user_profile_service.dart';
import '../../widgets/common_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _showPassword = false;
  bool _loading = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.destructive,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _checkDeletionStatusAndRedirect() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()!.containsKey('deletion_scheduled_at')) {
        final dateStr = doc.data()!['deletion_scheduled_at'] as String;
        final deletionDate = DateTime.parse(dateStr);

        if (DateTime.now().isAfter(deletionDate)) {
          // 30 days have passed. Hard delete now.
          await AuthService.hardDeleteAccount();
          if (mounted) {
            _showError('Hesabınız 30 günlük süre dolduğu için kalıcı olarak silinmiştir.');
          }
          return;
        } else {
          // Within 30 days. Ask to restore.
          if (!mounted) return;
          final restore = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Hesabınız Silinmek Üzere'),
              content: Text(
                  'Hesabınızı silme talebiniz bulunuyor. Eğer devam etmezseniz ${deletionDate.day}/${deletionDate.month}/${deletionDate.year} tarihinde hesabınız kalıcı olarak silinecek.\n\nHesabınızı kurtarmak ve giriş yapmak ister misiniz?'),
              actions: [
                TextButton(
                  onPressed: () {
                    AuthService.instance.signOut();
                    Navigator.pop(ctx, false);
                  },
                  child: const Text('Hayır, Çıkış Yap', style: TextStyle(color: AppColors.mutedForeground)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Evet, Hesabımı Kurtar'),
                ),
              ],
            ),
          );

          if (restore == true) {
            await AuthService.restoreAccount();
            // Continue to normal login flow
            await _checkProfileAndRedirect();
          }
          return;
        }
      }
    } catch (e) {
      debugPrint("Check deletion error: $e");
    }

    // Normal login flow
    await _checkProfileAndRedirect();
  }

  Future<void> _checkProfileAndRedirect() async {
    final exists = await UserProfileService.profileExists();
    if (!mounted) return;
    if (exists) {
      context.go('/app/dashboard');
    } else {
      context.go('/profile-setup');
    }
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final result = await AuthService.signInWithEmail(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.isSuccess) {
      await _checkDeletionStatusAndRedirect();
    } else {
      _showError(result.errorMessage!);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    final result = await AuthService.signInWithGoogle();
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.isSuccess) {
      await _checkDeletionStatusAndRedirect();
    } else {
      _showError(result.errorMessage!);
    }
  }

  Future<void> _signInWithApple() async {
    // Android üzerinde Apple Sign-in bazen kafa karıştırıcı olabiliyor
    if (Theme.of(context).platform == TargetPlatform.android) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.apple, color: AppColors.foreground),
              SizedBox(width: 10),
              Text('Apple ID uyarısı'),
            ],
          ),
          content: const Text(
            'Android cihazlarda Google ile giriş yapmanız daha hızlı ve güvenli bir deneyim sunar. Apple hesabınızı kullanmaya devam etmek istiyor musunuz?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç', style: TextStyle(color: AppColors.mutedForeground)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _performAppleSignIn();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.foreground,
                minimumSize: const Size(100, 40),
              ),
              child: const Text('Devam Et'),
            ),
          ],
        ),
      );
      return;
    }
    _performAppleSignIn();
  }

  Future<void> _performAppleSignIn() async {
    setState(() => _loading = true);
    final result = await AuthService.signInWithApple();
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.isSuccess) {
      await _checkDeletionStatusAndRedirect();
    } else {
      _showError(result.errorMessage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppLogo(),
                const SizedBox(height: 36),
                const Text(
                  'Tekrar Hoş Geldiniz',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sağlık yolculuğunuza devam edin',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 32),

                // Email
                AppTextField(
                  label: 'E-posta Adresi',
                  controller: _emailController,
                  hintText: 'ornek@email.com',
                  prefixIcon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'E-posta zorunludur';
                    if (!v.contains('@')) return 'Geçerli bir e-posta girin';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Şifre
                AppTextField(
                  label: 'Şifre',
                  controller: _passwordController,
                  hintText: 'Şifrenizi girin',
                  prefixIcon: Icons.lock_outline,
                  obscureText: !_showPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.mutedForeground,
                    ),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Şifre zorunludur';
                    if (v.length < 6) return 'Şifre en az 6 karakter olmalı';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.go('/forgot-password'),
                    child: const Text(
                      'Şifremi Unuttum',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Giriş Butonu
                AppButton(
                  text: 'Giriş Yap',
                  isLoading: _loading,
                  onPressed: _signInWithEmail,
                ),
                const SizedBox(height: 24),

                // Divider
                const AppDivider(text: 'veya şununla devam et'),
                const SizedBox(height: 24),

                // Google
                AppButton(
                  text: 'Google ile Giriş Yap',
                  isOutlined: true,
                  icon: _googleIcon(),
                  isLoading: _loading,
                  onPressed: _signInWithGoogle,
                ),
                const SizedBox(height: 12),

                // Apple
                AppButton(
                  text: 'Apple ile Giriş Yap',
                  isOutlined: true,
                  icon: const Icon(Icons.apple, color: Colors.black, size: 22),
                  isLoading: _loading,
                  onPressed: _signInWithApple,
                ),
                const SizedBox(height: 24),

                // Kayıt ol
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Hesabınız yok mu? ',
                      style: TextStyle(color: AppColors.mutedForeground),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/register'),
                      child: const Text(
                        'Kayıt Ol',
                        style: TextStyle(
                          color: AppColors.primary,
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
      ),
    );
  }

  // Removed _buildLogo, _buildDivider, _buildSocialButton

  Widget _googleIcon() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            color: Color(0xFF4285F4),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
