import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/user_profile_service.dart';

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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
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
      await _checkProfileAndRedirect();
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
      await _checkProfileAndRedirect();
    } else {
      _showError(result.errorMessage!);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _loading = true);
    final result = await AuthService.signInWithApple();
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.isSuccess) {
      await _checkProfileAndRedirect();
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
                _buildLogo(),
                const SizedBox(height: 36),
                const Text('Tekrar Hoş Geldiniz',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: AppColors.foreground)),
                const SizedBox(height: 8),
                const Text('Sağlık yolculuğunuza devam edin',
                    style: TextStyle(
                        fontSize: 15, color: AppColors.mutedForeground)),
                const SizedBox(height: 32),

                // Email
                const Text('E-posta Adresi',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.foreground)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'E-posta zorunludur';
                    if (!v.contains('@')) return 'Geçerli bir e-posta girin';
                    return null;
                  },
                  decoration: const InputDecoration(
                    hintText: 'ornek@email.com',
                    prefixIcon: Icon(Icons.mail_outline,
                        color: AppColors.mutedForeground),
                  ),
                ),
                const SizedBox(height: 16),

                // Şifre
                const Text('Şifre',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.foreground)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Şifre zorunludur';
                    if (v.length < 6)
                      return 'Şifre en az 6 karakter olmalı';
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Şifrenizi girin',
                    prefixIcon: const Icon(Icons.lock_outline,
                        color: AppColors.mutedForeground),
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
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.go('/forgot-password'),
                    child: const Text('Şifremi Unuttum',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(height: 8),

                // Giriş Butonu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _signInWithEmail,
                    child: _loading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text('Giriş Yap'),
                  ),
                ),
                const SizedBox(height: 24),

                // Divider
                _buildDivider('veya şununla devam et'),
                const SizedBox(height: 24),

                // Google
                _buildSocialButton(
                  onTap: _loading ? null : _signInWithGoogle,
                  icon: _googleIcon(),
                  label: 'Google ile Giriş Yap',
                ),
                const SizedBox(height: 12),

                // Apple
                _buildSocialButton(
                  onTap: _loading ? null : _signInWithApple,
                  icon: const Icon(Icons.apple,
                      color: Colors.black, size: 22),
                  label: 'Apple ile Giriş Yap',
                ),
                const SizedBox(height: 24),

                // Kayıt ol
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Hesabınız yok mu? ',
                        style:
                        TextStyle(color: AppColors.mutedForeground)),
                    GestureDetector(
                      onTap: () => context.go('/register'),
                      child: const Text('Kayıt Ol',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
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

  Widget _buildLogo() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.monitor_heart_outlined,
              color: Colors.white, size: 28),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AKSA',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground)),
            Text('Akıllı Kişisel Sağlık Asistanı',
                style: TextStyle(
                    fontSize: 11, color: AppColors.mutedForeground)),
          ],
        ),
      ],
    );
  }

  Widget _buildDivider(String text) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(text,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.mutedForeground)),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }

  Widget _buildSocialButton({
    required VoidCallback? onTap,
    required Widget icon,
    required String label,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(
                    color: AppColors.foreground,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _googleIcon() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: Text('G',
            style: TextStyle(
                color: Color(0xFF4285F4),
                fontWeight: FontWeight.bold,
                fontSize: 14)),
      ),
    );
  }
}