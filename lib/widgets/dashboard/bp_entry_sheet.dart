import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/health_service.dart';

/// Tansiyon ölçümü giriş bottom sheet'i.
class BPEntrySheet extends StatelessWidget {
  final HealthEntry? todayEntry;
  final VoidCallback onSaved;

  const BPEntrySheet({
    super.key,
    required this.todayEntry,
    required this.onSaved,
  });

  void show(BuildContext context) {
    final entry = todayEntry;
    double sys = entry?.systolic ?? 120;
    double dia = entry?.diastolic ?? 80;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final cs = Theme.of(ctx).colorScheme;
          String category;
          Color catColor;
          if (sys < 120 && dia < 80) {
            category = 'Normal';
            catColor = AppColors.secondary;
          } else if (sys < 140 || dia < 90) {
            category = 'Yüksek';
            catColor = AppColors.accent;
          } else {
            category = 'Hipertansiyon';
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
                      'Tansiyon Ölçümü',
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
                const SizedBox(height: 24),
                _buildSliderRow(ctx, 'Sistolik (büyük)', sys, 80, 200, AppColors.destructive,
                    (v) => setLocal(() => sys = v.roundToDouble())),
                const SizedBox(height: 8),
                _buildSliderRow(ctx, 'Diastolik (küçük)', dia, 40, 130, AppColors.accent,
                    (v) => setLocal(() => dia = v.roundToDouble())),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final existing = await HealthService.getTodayEntry();
                      final updated = (existing ?? HealthEntry(date: DateTime.now())).copyWith(
                        systolic: sys,
                        diastolic: dia,
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
            Text('${value.toInt()} mmHg',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
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
