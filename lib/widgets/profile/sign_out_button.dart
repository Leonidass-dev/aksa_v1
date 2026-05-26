import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

/// Çıkış yap butonu + onay dialog.
class SignOutButton extends StatelessWidget {
  const SignOutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
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
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => _handleDeleteAccount(context),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          child: const Text(
            'Hesabımı ve Verilerimi Sil',
            style: TextStyle(fontSize: 13, decoration: TextDecoration.underline),
          ),
        ),
      ],
    );
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.destructive),
            SizedBox(width: 8),
            Text('Hesabı Sil?'),
          ],
        ),
        content: const Text(
          'Hesabınızı sildiğinizde sağlık geçmişiniz, analizleriniz ve kişisel verileriniz kalıcı olarak silinecektir. Bu işlem geri alınamaz.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kalıcı Olarak Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // API call to delete account would normally happen here
      // For now we just sign out as the placeholder logic
      await AuthService.signOut();
      if (context.mounted) context.go('/login');
    }
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
