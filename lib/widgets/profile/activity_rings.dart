import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class ActivityRings extends StatefulWidget {
  final double stepsProgress; // 0.0 to 1.0
  final double sleepProgress; // 0.0 to 1.0
  final double waterProgress; // 0.0 to 1.0
  final String stepsLabel;
  final String sleepLabel;
  final String waterLabel;

  const ActivityRings({
    super.key,
    required this.stepsProgress,
    required this.sleepProgress,
    required this.waterProgress,
    this.stepsLabel = '',
    this.sleepLabel = '',
    this.waterLabel = '',
  });

  @override
  State<ActivityRings> createState() => _ActivityRingsState();
}

class _ActivityRingsState extends State<ActivityRings>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final progress = _animation.value;
        return AppCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CustomPaint(
                  painter: _RingsPainter(
                    steps: widget.stepsProgress * progress,
                    sleep: widget.sleepProgress * progress,
                    water: widget.waterProgress * progress,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem(context, 'Adım', widget.stepsLabel, AppColors.stepsIndigo, Icons.directions_walk_rounded),
                    const SizedBox(height: 12),
                    _buildLegendItem(context, 'Uyku', widget.sleepLabel, AppColors.sleepPurple, Icons.bedtime_rounded),
                    const SizedBox(height: 12),
                    _buildLegendItem(context, 'Su', widget.waterLabel, AppColors.waterBlue, Icons.water_drop_rounded),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(BuildContext context, String title, String value, Color color, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 13, color: cs.onSurface, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RingsPainter extends CustomPainter {
  final double steps;
  final double sleep;
  final double water;

  _RingsPainter({required this.steps, required this.sleep, required this.water});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = 14.0;
    final spacing = 4.0;

    // Steps Ring (Outer)
    _drawRing(canvas, center, (size.width / 2) - (strokeWidth / 2), steps, AppColors.stepsIndigo, strokeWidth);

    // Sleep Ring (Middle)
    _drawRing(canvas, center, (size.width / 2) - strokeWidth - spacing - (strokeWidth / 2), sleep, AppColors.sleepPurple, strokeWidth);

    // Water Ring (Inner)
    _drawRing(canvas, center, (size.width / 2) - (strokeWidth * 2) - (spacing * 2) - (strokeWidth / 2), water, AppColors.waterBlue, strokeWidth);
  }

  void _drawRing(Canvas canvas, Offset center, double radius, double progress, Color color, double strokeWidth) {
    final backgroundPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);
    if (progress > 0.005) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress.clamp(0.01, 0.999),
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter oldDelegate) {
    return oldDelegate.steps != steps || oldDelegate.sleep != sleep || oldDelegate.water != water;
  }
}
