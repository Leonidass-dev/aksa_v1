import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/health_service.dart';
import '../../constants/app_constants.dart';

/// Dashboard'daki 8'li sağlık metrik grid'i.
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
    final calories = entry?.activeCalories ?? 0;
    final distance = (entry?.distanceM ?? 0) / 1000; // km cinsinden

    // Veri Kaynağı İkonu (Simülasyon: Genelde saatten gelir, adım telefondan gelebilir)
    const watchIcon = Icons.watch_rounded;
    const phoneIcon = Icons.smartphone_rounded;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.3,
      children: [
        MetricTile(
          icon: Icons.directions_walk_rounded,
          color: const Color(0xFF6366F1),
          label: 'Adım',
          value: steps > 0 ? '${steps.toInt()}' : '0',
          sub: '/ ${AppConstants.defaultStepGoal}',
          progress: (steps / AppConstants.defaultStepGoal).clamp(0.0, 1.0),
          isCircular: true,
          sourceIcon: phoneIcon,
        ),
        MetricTile(
          icon: Icons.local_fire_department_rounded,
          color: Colors.orange,
          label: 'Kalori',
          value: calories > 0 ? '${calories.toInt()}' : '0',
          sub: 'kcal',
          progress: (calories / 500).clamp(0.0, 1.0),
          sourceIcon: watchIcon,
        ),
        MetricTile(
          icon: Icons.favorite_rounded,
          color: AppColors.destructive,
          label: 'Nabız',
          value: hr > 0 ? '${hr.toInt()}' : '--',
          sub: hr > 0 ? 'bpm' : 'Veri bekleniyor',
          progress: hr > 0 ? ((hr - 40) / 120).clamp(0.0, 1.0) : 0,
          // Renk Psikolojisi: Yüksek nabız kırmızı, normal yeşil
          progressColor: hr > 100 ? AppColors.destructive : (hr > 0 ? AppColors.secondary : null),
          sourceIcon: watchIcon,
        ),
        MetricTile(
          icon: Icons.location_on_rounded,
          color: Colors.teal,
          label: 'Mesafe',
          value: distance > 0 ? distance.toStringAsFixed(2) : '0.0',
          sub: 'km',
          progress: (distance / 5).clamp(0.0, 1.0),
          sourceIcon: phoneIcon,
        ),
        MetricTile(
          icon: Icons.bloodtype_rounded,
          color: AppColors.primary,
          label: 'Oksijen',
          value: spo2 > 0 ? '%${spo2.toInt()}' : '--',
          sub: spo2 > 0 ? (spo2 >= 95 ? 'Normal' : 'Düşük') : 'Veri bekleniyor',
          progress: (spo2 / 100).clamp(0.0, 1.0),
          progressColor: spo2 >= 95 ? AppColors.secondary : (spo2 > 0 ? AppColors.destructive : null),
          sourceIcon: watchIcon,
        ),
        MetricTile(
          icon: Icons.psychology_rounded,
          color: AppColors.stressYellow,
          label: 'Stres',
          value: stress > 0 ? '${stress.toInt()}' : '--',
          sub: stress > 0 ? (stress < 40 ? 'Düşük' : 'Yüksek') : 'Veri bekleniyor',
          progress: (stress / 100).clamp(0.0, 1.0),
          progressColor: stress > 70 ? AppColors.destructive : (stress > 0 ? AppColors.secondary : null),
          onTap: onStressTap,
          sourceIcon: watchIcon,
        ),
        MetricTile(
          icon: Icons.bedtime_rounded,
          color: AppColors.sleepPurple,
          label: 'Uyku',
          value: sleepH > 0 ? sleepH.toStringAsFixed(1) : '--',
          sub: sleepH > 0 ? '/ ${AppConstants.defaultSleepGoal.toInt()} saat' : 'Kayda başla',
          progress: (sleepH / AppConstants.defaultSleepGoal).clamp(0.0, 1.0),
          sourceIcon: watchIcon,
        ),
        MetricTile(
          icon: Icons.speed_rounded,
          color: AppColors.accent,
          label: 'Tansiyon',
          value: sys > 0 ? '${sys.toInt()}/${dia.toInt()}' : '--',
          sub: sys > 0 ? (sys < 130 ? 'Normal' : 'Yüksek') : 'Kaydet',
          progress: sys > 0 ? ((sys - 80) / 100).clamp(0.0, 1.0) : 0,
          progressColor: sys > 140 ? AppColors.destructive : (sys > 0 ? AppColors.secondary : null),
          onTap: onBPTap,
          sourceIcon: phoneIcon,
        ),
      ],
    );
  }
}

class MetricTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String sub;
  final double progress;
  final Color? progressColor;
  final VoidCallback? onTap;
  final bool isCircular;
  final IconData? sourceIcon;

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
    this.isCircular = false,
    this.sourceIcon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pColor = progressColor ?? color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Veri Kaynağı İkonu (Küçük, sağ üst)
            if (sourceIcon != null)
              Positioned(
                right: 0,
                top: 0,
                child: Icon(sourceIcon, size: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: isCircular
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 2,
                                backgroundColor: color.withValues(alpha: 0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(pColor),
                              ),
                            )
                          : Icon(icon, color: color, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Spacer(),
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: cs.onSurface)),
                Text(sub, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                if (!isCircular) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: color.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(pColor),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
