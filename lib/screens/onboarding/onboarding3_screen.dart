import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

class Onboarding3Screen extends StatelessWidget {
  const Onboarding3Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
                    colors: [AppColors.secondary, AppColors.secondaryDark],
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(Icons.shield_outlined,
                    size: 120, color: Colors.white),
              ),
              const SizedBox(height: 32),
              const Text(
                'Your Data is Secure',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'We prioritize your privacy with end-to-end encryption and secure data storage',
                style: TextStyle(fontSize: 16, color: AppColors.mutedForeground),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _featureCard(
                icon: Icons.lock_outline,
                color: AppColors.secondary,
                title: 'Encrypted Storage',
                subtitle: 'All your health data is encrypted and stored securely',
              ),
              const SizedBox(height: 12),
              _featureCard(
                icon: Icons.visibility_outlined,
                color: AppColors.primary,
                title: 'Privacy First',
                subtitle: 'You control who sees your information',
              ),
              const SizedBox(height: 12),
              _featureCard(
                icon: Icons.verified_user_outlined,
                color: AppColors.accent,
                title: 'HIPAA Compliant',
                subtitle: 'Meeting healthcare industry standards',
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [_dot(), _dot(), _dot(active: true), _dot()],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/onboarding-4'),
                  child: const Text('Continue'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Skip',
                    style: TextStyle(color: AppColors.mutedForeground)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.mutedForeground)),
              ],
            ),
          ),
        ],
      ),
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
