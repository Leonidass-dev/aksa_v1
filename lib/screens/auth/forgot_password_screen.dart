import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _sent = false;
  bool _loading = false;
  String _sentEmail = '';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final result = await AuthService.sendPasswordReset(_emailController.text);

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.isSuccess) {
      setState(() {
        _sent = true;
        _sentEmail = _emailController.text.trim();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage!),
          backgroundColor: AppColors.destructive,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_read_outlined,
                    size: 64,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'E-postanızı Kontrol Edin',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  '$_sentEmail adresine şifre sıfırlama bağlantısı gönderildi.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Spam klasörünü de kontrol etmeyi unutmayın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 32),
                AppButton(
                  text: 'Giriş Ekranına Dön',
                  onPressed: () => context.go('/login'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _sent = false),
                  child: const Text(
                    'Tekrar Gönder',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => context.go('/login'),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: AppColors.mutedForeground,
                    size: 20,
                  ),
                  label: const Text(
                    'Geri',
                    style: TextStyle(color: AppColors.mutedForeground),
                  ),
                ),
                const SizedBox(height: 24),

                const AppLogo(),
                const SizedBox(height: 36),

                const Text(
                  'Şifremi Unuttum',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'E-posta adresinizi girin, sıfırlama bağlantısı gönderelim.',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 32),

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
                const SizedBox(height: 24),

                AppButton(
                  text: 'Sıfırlama Bağlantısı Gönder',
                  isLoading: _loading,
                  onPressed: _sendReset,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
