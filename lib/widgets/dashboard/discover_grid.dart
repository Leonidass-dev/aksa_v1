import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

/// "Hızlı Keşfet" kısayol kartları — yatay kaydırmalı grid.
class DiscoverGrid extends StatelessWidget {
  const DiscoverGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const shortcuts = [
      _Shortcut(Icons.analytics_rounded, 'Raporlar', 'Haftalık analiz', Color(0xFF8B5CF6), '/app/reports'),
      _Shortcut(Icons.shield_rounded, 'Risk Detayı', 'Skor detayları', AppColors.primary, '/app/risk-score'),
      _Shortcut(Icons.notifications_active_rounded, 'Uyarılar', 'Sağlık alerts', AppColors.accent, '/app/alerts'),
    ];

    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shortcuts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final s = shortcuts[i];
          return GestureDetector(
            onTap: () => context.go(s.path),
            child: Container(
              width: 130,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: s.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: s.color.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(s.icon, color: s.color, size: 22),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface)),
                      Text(s.sub, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Shortcut {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final String path;
  const _Shortcut(this.icon, this.label, this.sub, this.color, this.path);
}
