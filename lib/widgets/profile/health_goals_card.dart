import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Hedef ilerleme çubukları kartı.
class HealthGoalsCard extends StatelessWidget {
  final List<GoalItem> goals;
  final VoidCallback onEdit;

  const HealthGoalsCard({
    super.key,
    required this.goals,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sağlık Hedefleri', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
              GestureDetector(
                onTap: onEdit,
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
}

/// Hedef ilerleme verisi modeli.
class GoalItem {
  final String label, value;
  final double progress;
  final Color color;
  const GoalItem(this.label, this.value, this.progress, this.color);
}
