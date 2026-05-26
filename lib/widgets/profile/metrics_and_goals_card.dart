import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class GoalItem {
  final String label, value;
  final double progress;
  final Color color;
  const GoalItem(this.label, this.value, this.progress, this.color);
}

class MetricsAndGoalsCard extends StatelessWidget {
  final double bmi;
  final String bmiCategory;
  final Color bmiColor;
  final double height;
  final double weight;
  final int age;
  final String gender;
  final List<GoalItem> goals;
  final VoidCallback onEditMetrics;
  final VoidCallback onEditGoals;
  final VoidCallback onWeightTap;
  final VoidCallback onHeightTap;

  const MetricsAndGoalsCard({
    super.key,
    required this.bmi,
    required this.bmiCategory,
    required this.bmiColor,
    required this.height,
    required this.weight,
    required this.age,
    required this.gender,
    required this.goals,
    required this.onEditMetrics,
    required this.onEditGoals,
    required this.onWeightTap,
    required this.onHeightTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // METRICS SECTION
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Vücut Metrikleri', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
            ],
          ),
          const SizedBox(height: 16),
          _buildBMICard(cs),
          const SizedBox(height: 14),
          Row(
            children: [
              _bodyMetricChip(cs, Icons.height, 'Boy', '${height.toInt()} cm', onTap: onHeightTap),
              const SizedBox(width: 8),
              _bodyMetricChip(cs, Icons.monitor_weight_outlined, 'Kilo', '${weight.toStringAsFixed(1)} kg', onTap: onWeightTap),
              const SizedBox(width: 8),
              _bodyMetricChip(cs, Icons.cake_outlined, 'Yaş', '$age', onTap: onEditMetrics),
              const SizedBox(width: 8),
              _bodyMetricChip(cs, Icons.wc, 'Cinsiyet', gender == 'M' ? 'Erkek' : 'Kadın', onTap: onEditMetrics),
            ],
          ),
          
          const SizedBox(height: 24),
          Divider(color: cs.outlineVariant.withValues(alpha: 0.5), height: 1),
          const SizedBox(height: 24),

          // GOALS SECTION
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sağlık Hedefleri', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
              GestureDetector(
                onTap: onEditGoals,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Düzenle',
                    style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...goals.map((g) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(g.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface)),
                      Text(g.value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: g.color)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: g.progress),
                            duration: const Duration(milliseconds: 1000),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) => LinearProgressIndicator(
                              value: value,
                              minHeight: 6,
                              backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
                              valueColor: AlwaysStoppedAnimation<Color>(g.color),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(g.progress * 100).toInt()}%',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: g.color),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildBMICard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bmiColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bmiColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bmiColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.monitor_weight_outlined, color: bmiColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vücut Kitle İndeksi (BMI)', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      bmi > 0 ? bmi.toStringAsFixed(1) : '--',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: bmiColor),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: bmiColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(bmiCategory, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: bmiColor)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bodyMetricChip(ColorScheme cs, IconData icon, String label, String value, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: onTap != null ? Border.all(color: AppColors.primary.withValues(alpha: 0.2)) : null,
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: onTap != null ? AppColors.primary : cs.onSurfaceVariant),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(label, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
