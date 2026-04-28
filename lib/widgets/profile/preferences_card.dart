import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_notifier.dart';
import '../../widgets/common_widgets.dart';

/// Tercihler kartı — bildirim, dark mode ve gizlilik ayarları.
class PreferencesCard extends StatelessWidget {
  final bool notifications;
  final ValueChanged<bool> onNotificationChanged;
  final VoidCallback onPrivacyTap;

  const PreferencesCard({
    super.key,
    required this.notifications,
    required this.onNotificationChanged,
    required this.onPrivacyTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = themeNotifier.value == ThemeMode.dark;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tercihler', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 16),
          _toggleRow(context, Icons.notifications_outlined, AppColors.primary,
              'Bildirimler', 'Anlık bildirimler ve uyarılar', notifications, onNotificationChanged),
          Divider(color: cs.outlineVariant, height: 24),
          _toggleRow(context, Icons.dark_mode_outlined, AppColors.accent,
              'Karanlık Mod', 'Karanlık temaya geç', isDark,
              (v) => themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light),
          Divider(color: cs.outlineVariant, height: 24),
          _buildPrivacyRow(context),
        ],
      ),
    );
  }

  Widget _toggleRow(BuildContext context, IconData icon, Color color,
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: cs.onSurface)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.primary),
      ],
    );
  }

  Widget _buildPrivacyRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onPrivacyTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shield_outlined, color: AppColors.secondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gizlilik ve Güvenlik', style: TextStyle(fontWeight: FontWeight.w500, color: cs.onSurface)),
                Text('Veri koruma ayarları', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
        ],
      ),
    );
  }
}
