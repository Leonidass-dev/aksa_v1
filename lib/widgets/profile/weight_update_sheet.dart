import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/bmi_utils.dart';
import '../../services/health_service.dart';
import '../../services/user_profile_service.dart';

/// Hızlı kilo güncelleme bottom sheet'i.
class WeightUpdateSheet extends StatelessWidget {
  final double currentWeight;
  final double userHeight;
  final ValueChanged<double> onSaved;

  const WeightUpdateSheet({
    super.key,
    required this.currentWeight,
    required this.userHeight,
    required this.onSaved,
  });

  void show(BuildContext context) {
    double newWeight = currentWeight;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final cs = Theme.of(ctx).colorScheme;
          final newBmi = BmiUtils.calculate(userHeight, newWeight);
          final bmiCat = BmiUtils.category(newBmi);
          final bmiCol = BmiUtils.color(newBmi);

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
                    decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Kilo Güncelle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
                const SizedBox(height: 20),
                Text(
                  '${newWeight.toStringAsFixed(1)} kg',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: cs.onSurface),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('BMI: ${newBmi.toStringAsFixed(1)} ', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: bmiCol.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(bmiCat, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: bmiCol)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.primary,
                    thumbColor: AppColors.primary,
                    inactiveTrackColor: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: newWeight, min: 30, max: 200,
                    onChanged: (v) => setLocal(() => newWeight = double.parse(v.toStringAsFixed(1))),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _weightBtn(ctx, '-1', () => setLocal(() => newWeight = (newWeight - 1).clamp(30, 200))),
                    const SizedBox(width: 8),
                    _weightBtn(ctx, '-0.1', () => setLocal(() => newWeight = double.parse((newWeight - 0.1).clamp(30, 200).toStringAsFixed(1)))),
                    const SizedBox(width: 8),
                    _weightBtn(ctx, '+0.1', () => setLocal(() => newWeight = double.parse((newWeight + 0.1).clamp(30, 200).toStringAsFixed(1)))),
                    const SizedBox(width: 8),
                    _weightBtn(ctx, '+1', () => setLocal(() => newWeight = (newWeight + 1).clamp(30, 200))),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final profile = await UserProfileService.getProfile();
                      if (profile != null) {
                        final updated = UserProfile(
                          uid: profile.uid, fullName: profile.fullName, email: profile.email,
                          age: profile.age, height: profile.height, weight: newWeight,
                          gender: profile.gender, photoUrl: profile.photoUrl, bio: profile.bio,
                        );
                        await UserProfileService.saveProfile(updated);
                      }
                      final existing = await HealthService.getTodayEntry();
                      final entry = (existing ?? HealthEntry(date: DateTime.now())).copyWith(
                        weight: newWeight, source: 'manual',
                      );
                      await HealthService.saveHealthEntry(entry);

                      if (ctx.mounted) Navigator.pop(ctx);
                      onSaved(newWeight);
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

  Widget _weightBtn(BuildContext context, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
