import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

/// Çıkış yap butonu + onay dialog.
class SignOutButton extends StatelessWidget {
  const SignOutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () => _handleSignOut(context),
        style: TextButton.styleFrom(
          backgroundColor: AppColors.destructive.withValues(alpha: 0.1),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(Icons.logout, color: AppColors.destructive),
        label: const Text(
          'Çıkış Yap',
          style: TextStyle(color: AppColors.destructive, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Hesabınızdan çıkmak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AuthService.signOut();
      if (context.mounted) context.go('/login');
    }
  }
}
