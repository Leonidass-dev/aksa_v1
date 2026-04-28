import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';

/// Sağlık hedefleri düzenleme bottom sheet'i.
class HealthGoalsSheet extends StatefulWidget {
  final String uid;
  const HealthGoalsSheet({super.key, required this.uid});

  @override
  State<HealthGoalsSheet> createState() => _HealthGoalsSheetState();
}

class _HealthGoalsSheetState extends State<HealthGoalsSheet> {
  double _targetWeight = 68;
  double _targetSteps = 10000;
  double _targetSleep = 8;
  bool _saving = false;
  bool _loadingGoals = true;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(widget.uid)
          .collection('settings').doc('health_goals').get();
      if (doc.exists) {
        final d = doc.data()!;
        setState(() {
          _targetWeight = (d['targetWeight'] as num?)?.toDouble() ?? 68;
          _targetSteps = (d['targetSteps'] as num?)?.toDouble() ?? 10000;
          _targetSleep = (d['targetSleep'] as num?)?.toDouble() ?? 8;
        });
      }
    } catch (_) {}
    setState(() => _loadingGoals = false);
  }

  Future<void> _saveGoals() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users').doc(widget.uid)
          .collection('settings').doc('health_goals')
          .set({
        'targetWeight': _targetWeight,
        'targetSteps': _targetSteps,
        'targetSleep': _targetSleep,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kaydedilemedi, tekrar deneyin.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: _loadingGoals
          ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Sağlık Hedefleri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
                const SizedBox(height: 24),
                _goalSlider(cs, 'Hedef Kilo', '${_targetWeight.toInt()} kg', _targetWeight, 40, 150,
                    (v) => setState(() => _targetWeight = v), AppColors.primary),
                const SizedBox(height: 16),
                _goalSlider(cs, 'Günlük Adım', '${(_targetSteps / 1000).toStringAsFixed(1)}k', _targetSteps, 2000, 20000,
                    (v) => setState(() => _targetSteps = v), AppColors.secondary),
                const SizedBox(height: 16),
                _goalSlider(cs, 'Uyku Süresi', '${_targetSleep.toStringAsFixed(1)} saat', _targetSleep, 5, 12,
                    (v) => setState(() => _targetSleep = v), AppColors.accent),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _saveGoals,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Kaydet', style: TextStyle(fontSize: 15)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _goalSlider(ColorScheme cs, String label, String valueText, double value,
      double min, double max, ValueChanged<double> onChanged, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: cs.onSurface)),
            Text(valueText, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
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
}
