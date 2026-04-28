import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/health_service.dart';
import '../../widgets/common_widgets.dart';
import '../../constants/app_constants.dart';

/// Dashboard'daki 6'lı sağlık metrik grid'i.
class DashboardMetricsGrid extends StatelessWidget {
  final HealthEntry? todayEntry;
  final VoidCallback onBPTap;

  const DashboardMetricsGrid({
    super.key,
    required this.todayEntry,
    required this.onBPTap,
  });

  @override
  Widget build(BuildContext context) {
    final entry = todayEntry;
    final steps = entry?.steps ?? 0;
    final hr = entry?.heartRate ?? 0;
    final sleepH = entry?.sleepHours ?? 0;
    final sys = entry?.systolic ?? 0;
    final dia = entry?.diastolic ?? 0;
    final spo2 = entry?.spo2 ?? 0;
    final stress = entry?.stressLevel ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.35,
      children: [
        MetricTile(
          icon: Icons.directions_walk_rounded,
          color: const Color(0xFF6366F1),
          label: 'Adım',
          value: steps > 0 ? '${steps.toInt()}' : '--',
          sub: '/ ${AppConstants.defaultStepGoal}',
          progress: (steps / AppConstants.defaultStepGoal).clamp(0.0, 1.0),
        ),
        MetricTile(
          icon: Icons.favorite_rounded,
          color: AppColors.destructive,
          label: 'Nabız',
          value: hr > 0 ? '${hr.toInt()}' : '--',
          sub: hr > 0 ? 'bpm' : '',
          progress: hr > 0 ? ((hr - 40) / 160).clamp(0.0, 1.0) : 0,
          progressColor: hr > 100 ? AppColors.destructive : AppColors.secondary,
        ),
        MetricTile(
          icon: Icons.bloodtype_rounded,
          color: AppColors.primary,
          label: 'Oksijen',
          value: spo2 > 0 ? '%${spo2.toInt()}' : '--',
          sub: spo2 > 95 ? 'Normal' : 'Düşük',
          progress: (spo2 / 100).clamp(0.0, 1.0),
        ),
        MetricTile(
          icon: Icons.psychology_rounded,
          color: AppColors.stressYellow,
          label: 'Stres',
          value: stress > 0 ? '${stress.toInt()}' : '--',
          sub: stress < 40 ? 'Düşük' : stress < 70 ? 'Orta' : 'Yüksek',
          progress: (stress / 100).clamp(0.0, 1.0),
          progressColor: stress > 70
              ? AppColors.destructive
              : stress > 40
                  ? AppColors.stressYellow
                  : AppColors.secondary,
        ),
        MetricTile(
          icon: Icons.bedtime_rounded,
          color: AppColors.sleepPurple,
          label: 'Uyku',
          value: sleepH > 0 ? sleepH.toStringAsFixed(1) : '--',
          sub: sleepH > 0 ? '/ ${AppConstants.defaultSleepGoal.toInt()} saat' : '',
          progress: (sleepH / AppConstants.defaultSleepGoal).clamp(0.0, 1.0),
        ),
        MetricTile(
          icon: Icons.speed_rounded,
          color: AppColors.accent,
          label: 'Tansiyon',
          value: sys > 0 ? '${sys.toInt()}/${dia.toInt()}' : '--',
          sub: sys > 0
              ? (sys < 120 ? 'Normal' : sys < 140 ? 'Yüksek' : 'Riskli')
              : '',
          progress: sys > 0 ? ((sys - 80) / 120).clamp(0.0, 1.0) : 0,
          progressColor: sys > 140
              ? AppColors.destructive
              : sys > 130
                  ? AppColors.accent
                  : AppColors.secondary,
          onTap: onBPTap,
        ),
      ],
    );
  }
}

/// Tek bir sağlık metrik tile'ı — grid içinde kullanılır.
class MetricTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String sub;
  final double progress;
  final Color? progressColor;
  final VoidCallback? onTap;

  const MetricTile({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.sub,
    required this.progress,
    this.progressColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pColor = progressColor ?? color;
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(width: 4),
                Text(sub, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(pColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
