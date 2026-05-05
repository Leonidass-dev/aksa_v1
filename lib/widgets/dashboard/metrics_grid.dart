import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/health_service.dart';
import '../../constants/app_constants.dart';

/// Dashboard'daki 6'lı sağlık metrik grid'i.
class DashboardMetricsGrid extends StatelessWidget {
  final HealthEntry? todayEntry;
  final VoidCallback onBPTap;
  final VoidCallback onStressTap;

  const DashboardMetricsGrid({
    super.key,
    required this.todayEntry,
    required this.onBPTap,
    required this.onStressTap,
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

    final hrTime = entry?.heartRateTime;
    final isHRStale = hrTime != null && DateTime.now().difference(hrTime).inMinutes > 20;
    final hrStaleMsg = isHRStale ? '${DateTime.now().difference(hrTime).inMinutes}dk önce' : '';

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
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
          isStale: isHRStale,
          staleMessage: hrStaleMsg,
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
          onTap: onStressTap,
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
  final bool isStale;
  final String staleMessage;

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
    this.isStale = false,
    this.staleMessage = '',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pColor = progressColor ?? color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isStale ? AppColors.stressYellow.withValues(alpha: 0.3) : color.withValues(alpha: 0.1),
            width: isStale ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isStale ? AppColors.stressYellow.withValues(alpha: 0.1) : color.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (isStale)
              Positioned(
                top: -8,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.stressYellow.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history_rounded, size: 12, color: AppColors.stressYellow),
                      const SizedBox(width: 2),
                      Text(
                        staleMessage,
                        style: const TextStyle(fontSize: 9, color: AppColors.stressYellow, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // İkon ve Etiket
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.2),
                            blurRadius: 10,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Değer ve Birim
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Modern Pill Progress
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Container(
                          height: 6,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: cs.outlineVariant.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 1000),
                          height: 6,
                          width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [pColor, pColor.withValues(alpha: 0.6)],
                            ),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: [
                              BoxShadow(
                                color: pColor.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
