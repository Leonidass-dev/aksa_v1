import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../theme/app_theme.dart';

class MacroNutrientsRing extends StatelessWidget {
  final double protein;
  final double carbs;
  final double fat;
  final double totalCalories;
  final double targetCalories;

  const MacroNutrientsRing({
    super.key,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.totalCalories,
    this.targetCalories = 2000,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = (totalCalories / targetCalories).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Sol: Katmanlı Halka
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _RingLayer(progress: 1.0, color: cs.outlineVariant.withValues(alpha: 0.1), strokeWidth: 12),
                _RingLayer(progress: progress, color: AppColors.primary, strokeWidth: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${totalCalories.toInt()}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1),
                    ),
                    Text(
                      'kcal',
                      style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Sağ: Makro Detayları
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMacroItem('Karbonhidrat', carbs, 'g', Colors.orange, 0.6),
                const SizedBox(height: 12),
                _buildMacroItem('Protein', protein, 'g', Colors.redAccent, 0.4),
                const SizedBox(height: 12),
                _buildMacroItem('Yağ', fat, 'g', Colors.amber, 0.3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroItem(String label, double value, String unit, Color color, double pct) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
            Text('${value.toInt()}$unit', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 4,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _RingLayer extends StatelessWidget {
  final double progress;
  final Color color;
  final double strokeWidth;

  const _RingLayer({required this.progress, required this.color, required this.strokeWidth});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutBack,
      builder: (context, value, _) => CustomPaint(
        painter: _RingPainter(progress: value, color: color, strokeWidth: strokeWidth),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _RingPainter({required this.progress, required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
