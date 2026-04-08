import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/user_profile_service.dart';
import '../../widgets/common_widgets.dart';

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
                const AppLogo(),
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
                AppTextField(
                  label: 'Ad Soyad',
                  controller: _nameController,
                  hintText: 'Adınızı ve soyadınızı girin',
                  prefixIcon: Icons.person_outline,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ad soyad zorunludur';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

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
                  hintText: 'Şifre oluşturun',
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
                AppButton(
                  text: 'Hesap Oluştur',
                  isLoading: _loading,
                  onPressed: _register,
                ),
                const SizedBox(height: 24),

                // Divider
                const AppDivider(text: 'veya şununla kayıt ol'),
                const SizedBox(height: 24),

                // Google
                AppButton(
                  text: 'Google ile Kayıt Ol',
                  isOutlined: true,
                  icon: googleIcon(),
                  isLoading: _loading,
                  onPressed: _signInWithGoogle,
                ),
                const SizedBox(height: 12),

                // Apple
                AppButton(
                  text: 'Apple ile Kayıt Ol',
                  isOutlined: true,
                  icon: const Icon(Icons.apple, color: Colors.black, size: 22),
                  isLoading: _loading,
                  onPressed: _signInWithApple,
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

  Widget googleIcon() {
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