import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/bmi_utils.dart';
import '../../services/user_profile_service.dart';

/// Hızlı boy güncelleme bottom sheet'i.
class HeightUpdateSheet extends StatelessWidget {
  final double currentHeight;
  final double userWeight;
  final int userAge;
  final ValueChanged<double> onSaved;

  const HeightUpdateSheet({
    super.key,
    required this.currentHeight,
    required this.userWeight,
    required this.userAge,
    required this.onSaved,
  });

  void show(BuildContext context) {
    double newHeight = currentHeight;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final cs = Theme.of(ctx).colorScheme;
          final newBmi = BmiUtils.calculate(newHeight, userWeight);
          final bmiCat = BmiUtils.category(newBmi, userAge);
          final bmiCol = BmiUtils.color(newBmi, userAge);

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
                Text('Boy Güncelle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
                const SizedBox(height: 20),
                Text(
                  '${newHeight.toInt()} cm',
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
                    value: newHeight, min: 100, max: 250,
                    onChanged: (v) => setLocal(() => newHeight = double.parse(v.toStringAsFixed(1))),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _heightBtn(ctx, '-5', () => setLocal(() => newHeight = (newHeight - 5).clamp(100, 250))),
                    const SizedBox(width: 8),
                    _heightBtn(ctx, '-1', () => setLocal(() => newHeight = (newHeight - 1).clamp(100, 250))),
                    const SizedBox(width: 8),
                    _heightBtn(ctx, '+1', () => setLocal(() => newHeight = (newHeight + 1).clamp(100, 250))),
                    const SizedBox(width: 8),
                    _heightBtn(ctx, '+5', () => setLocal(() => newHeight = (newHeight + 5).clamp(100, 250))),
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
                          age: profile.age, height: newHeight, weight: profile.weight,
                          gender: profile.gender, photoUrl: profile.photoUrl, bio: profile.bio,
                        );
                        await UserProfileService.saveProfile(updated);
                      }
                      
                      if (ctx.mounted) Navigator.pop(ctx);
                      onSaved(newHeight);
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

  Widget _heightBtn(BuildContext context, String label, VoidCallback onTap) {
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
