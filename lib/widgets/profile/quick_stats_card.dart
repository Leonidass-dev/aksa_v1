import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Profil ekranının 3'lü istatistik özet kartı (skor, gün, veri noktası).
class QuickStatsCard extends StatelessWidget {
  final String healthScore;
  final String activeDays;
  final String dataPoints;

  const QuickStatsCard({
    super.key,
    required this.healthScore,
    required this.activeDays,
    required this.dataPoints,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _quickStat(cs, healthScore, 'Sağlık\nSkoru', AppColors.secondary),
          Container(width: 1, height: 40, color: cs.outlineVariant),
          _quickStat(cs, activeDays, 'Aktif\nGün', AppColors.primary),
          Container(width: 1, height: 40, color: cs.outlineVariant),
          _quickStat(cs, dataPoints, 'Veri\nNoktası', AppColors.accent),
        ],
      ),
    );
  }

  Widget _quickStat(ColorScheme cs, String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant, height: 1.3),
        ),
      ],
    );
  }
}
