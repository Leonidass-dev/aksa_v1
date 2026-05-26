import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Onboarding4Screen extends StatefulWidget {
  final PageController? controller;
  const Onboarding4Screen({super.key, this.controller});

  @override
  State<Onboarding4Screen> createState() => _Onboarding4ScreenState();
}

class _Onboarding4ScreenState extends State<Onboarding4Screen> {
  bool _acceptedKVKK = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(48),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.accent, AppColors.primary],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        size: 120,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      "Hazır mısınız?",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.foreground,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Hesabınızı oluşturalım ve yapay zeka destekli içgörülerle sağlığınızı takip etmeye başlayın",
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.mutedForeground,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Sırada Ne Var?",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _step(1, 'Hesabınızı oluşturun', AppColors.primary),
                          const SizedBox(height: 12),
                          _step(
                            2,
                            'Sağlık verilerinizi girin',
                            AppColors.secondary,
                          ),
                          const SizedBox(height: 12),
                          _step(
                            3,
                            'Kişiselleştirilmiş içgörüler alın',
                            AppColors.accent,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [_dot(), _dot(), _dot(), _dot(active: true)],
                    ),
                    const SizedBox(height: 16),
                    // KVKK Checkbox
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _acceptedKVKK,
                            onChanged: (val) {
                              setState(() => _acceptedKVKK = val ?? false);
                            },
                            activeColor: AppColors.primary,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10.0),
                              child: const Text(
                                'KVKK ve Açık Rıza Metnini okudum ve onaylıyorum. Sağlık verilerimin anonimleştirilerek güvenli veritabanında işlenmesini ve analiz edilmesini kabul ediyorum.',
                                style: TextStyle(fontSize: 11, color: AppColors.mutedForeground, height: 1.4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _acceptedKVKK ? () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('onboarding_completed', true);
                          if (context.mounted) {
                            context.go('/register');
                          }
                        } : null,
                        child: const Text('Hesap Oluştur'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _acceptedKVKK ? () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('onboarding_completed', true);
                          if (context.mounted) {
                            context.go('/login');
                          }
                        } : null,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: const Text(
                          'Zaten Bir Hesabım Var',
                          style: TextStyle(color: AppColors.foreground),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(int number, String text, Color color) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(color: AppColors.foreground, fontSize: 15),
        ),
      ],
    );
  }

  Widget _dot({bool active = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: active ? 24 : 8,
      height: 4,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.muted,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
