import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

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

    final result =
    await AuthService.sendPasswordReset(_emailController.text);

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
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  child: const Icon(Icons.mark_email_read_outlined,
                      size: 64, color: AppColors.secondary),
                ),
                const SizedBox(height: 24),
                const Text('E-postanızı Kontrol Edin',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.foreground),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(
                  '$_sentEmail adresine �Yifre sıfırlama ba�Ylantısı gönderildi.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Spam klasörünü de kontrol etmeyi unutmayın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Giri�Y Ekranına Dön'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _sent = false),
                  child: const Text('Tekrar Gönder',
                      style: TextStyle(color: AppColors.primary)),
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
                  icon: const Icon(Icons.arrow_back,
                      color: AppColors.mutedForeground, size: 20),
                  label: const Text('Geri',
                      style:
                      TextStyle(color: AppColors.mutedForeground)),
                ),
                const SizedBox(height: 24),

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
                        Text('Akıllı Ki�Yisel Sa�Ylık Asistanı',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.mutedForeground)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                const Text('Şifremi Unuttum',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: AppColors.foreground)),
                const SizedBox(height: 8),
                const Text(
                    'E-posta adresinizi girin, sıfırlama ba�Ylantısı gönderelim.',
                    style: TextStyle(
                        fontSize: 15, color: AppColors.mutedForeground)),
                const SizedBox(height: 32),

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
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _sendReset,
                    child: _loading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                        : const Text('Sıfırlama Ba�Ylantısı Gönder'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
