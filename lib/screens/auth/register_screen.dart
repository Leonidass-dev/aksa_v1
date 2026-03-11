import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/user_profile_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _showPassword = false;
  bool _agreedToTerms = false;
  bool _loading = false;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
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

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      _showError('Devam etmek için koşulları kabul etmelisiniz.');
      return;
    }

    setState(() => _loading = true);

    final result = await AuthService.registerWithEmail(
      name: _nameController.text,
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
                // Logo
                Row(
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
                                fontSize: 11,
                                color: AppColors.mutedForeground)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                const Text('Hesap Oluşturun',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: AppColors.foreground)),
                const SizedBox(height: 8),
                const Text('AKSA ile sağlık yolculuğunuza başlayın',
                    style: TextStyle(
                        fontSize: 15, color: AppColors.mutedForeground)),
                const SizedBox(height: 32),

                // Ad Soyad
                const Text('Ad Soyad',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.foreground)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Ad soyad zorunludur';
                    return null;
                  },
                  decoration: const InputDecoration(
                    hintText: 'Adınızı ve soyadınızı girin',
                    prefixIcon: Icon(Icons.person_outline,
                        color: AppColors.mutedForeground),
                  ),
                ),
                const SizedBox(height: 16),

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
                    hintText: 'Şifre oluşturun',
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
                const SizedBox(height: 6),
                const Text('En az 6 karakter olmalıdır',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.mutedForeground)),
                const SizedBox(height: 16),

                // Koşullar
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agreedToTerms,
                      onChanged: (v) =>
                          setState(() => _agreedToTerms = v ?? false),
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.mutedForeground),
                            children: [
                              TextSpan(text: 'Kabul ediyorum: '),
                              TextSpan(
                                text: 'Kullanım Koşulları',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500),
                              ),
                              TextSpan(text: ' ve '),
                              TextSpan(
                                text: 'Gizlilik Politikası',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Kayıt Butonu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    child: _loading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text('Hesap Oluştur'),
                  ),
                ),
                const SizedBox(height: 24),

                // Divider
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('veya şununla kayıt ol',
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.mutedForeground)),
                    ),
                    const Expanded(child: Divider(color: AppColors.border)),
                  ],
                ),
                const SizedBox(height: 24),

                // Google
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _loading ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
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
                        ),
                        const SizedBox(width: 12),
                        const Text('Google ile Kayıt Ol',
                            style: TextStyle(
                                color: AppColors.foreground,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Apple
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _loading ? null : _signInWithApple,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.apple, color: Colors.black, size: 22),
                        SizedBox(width: 12),
                        Text('Apple ile Kayıt Ol',
                            style: TextStyle(
                                color: AppColors.foreground,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Giriş yap linki
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Zaten hesabınız var mı? ',
                        style:
                        TextStyle(color: AppColors.mutedForeground)),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: const Text('Giriş Yapın',
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
}