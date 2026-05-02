import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/health_service.dart';

/// Stres seviyesi giriş bottom sheet'i.
class StressEntrySheet extends StatelessWidget {
  final HealthEntry? todayEntry;
  final VoidCallback onSaved;

  const StressEntrySheet({
    super.key,
    required this.todayEntry,
    required this.onSaved,
  });

  void show(BuildContext context) {
    final entry = todayEntry;
    double stress = (entry?.stressLevel ?? 0) > 0 ? entry!.stressLevel : 50;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final cs = Theme.of(ctx).colorScheme;
          String category;
          Color catColor;
          
          if (stress < 40) {
            category = 'Düşük';
            catColor = AppColors.secondary;
          } else if (stress < 70) {
            category = 'Orta';
            catColor = AppColors.stressYellow;
          } else {
            category = 'Yüksek';
            catColor = AppColors.destructive;
          }

          return Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Stres Seviyesi',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: catColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Saatindeki stres puanını buraya girebilirsin.',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                _buildSliderRow(ctx, 'Puan (0-100)', stress, 0, 100, AppColors.stressYellow,
                    (v) => setLocal(() => stress = v.roundToDouble())),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final existing = await HealthService.getTodayEntry();
                      final updated = (existing ?? HealthEntry(date: DateTime.now())).copyWith(
                        stressLevel: stress,
                        source: 'manual',
                      );
                      await HealthService.saveHealthEntry(updated);
                      if (ctx.mounted) Navigator.pop(ctx);
                      onSaved();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Kaydet', style: TextStyle(fontSize: 15)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSliderRow(BuildContext context, String label, double value,
      double min, double max, Color color, ValueChanged<double> onChanged) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            Text('${value.toInt()}',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            thumbColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.2),
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
