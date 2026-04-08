import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WaterWaveWidget extends StatefulWidget {
  final double currentMl;
  final double targetMl;

  const WaterWaveWidget({
    super.key,
    required this.currentMl,
    required this.targetMl,
  });

  @override
  State<WaterWaveWidget> createState() => _WaterWaveWidgetState();
}

class _WaterWaveWidgetState extends State<WaterWaveWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double fillPercentage =
        (widget.currentMl / widget.targetMl).clamp(0.0, 1.0);

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.05),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1), width: 2),
      ),
      child: ClipOval(
        child: Stack(
          children: [
            // Wave animation
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(120, 120),
                  painter: _WavePainter(
                    animationValue: _controller.value,
                    fillPercentage: fillPercentage,
                  ),
                );
              },
            ),
            // Text info
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.currentMl.toInt()}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: fillPercentage > 0.5 ? Colors.white : AppColors.primary,
                    ),
                  ),
                  Text(
                    'ml',
                    style: TextStyle(
                      fontSize: 12,
                      color: fillPercentage > 0.5 ? Colors.white70 : AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double animationValue;
  final double fillPercentage;

  _WavePainter({required this.animationValue, required this.fillPercentage});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryLight.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    final path = Path();
    final yBase = size.height * (1 - fillPercentage);
    
    // Wave parameters
    const double waveHeight = 6.0;
    const double waveFrequency = 1.5;

    path.moveTo(0, size.height);
    path.lineTo(0, yBase);

    for (double x = 0; x <= size.width; x++) {
      final double y = yBase +
          sin((x / size.width * 2 * pi * waveFrequency) + (animationValue * 2 * pi)) *
              waveHeight;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
    
    // Draw a second wave with slight offset and color
    final paint2 = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
      
    final path2 = Path();
    path2.moveTo(0, size.height);
    path2.lineTo(0, yBase);

    for (double x = 0; x <= size.width; x++) {
      final double y = yBase +
          cos((x / size.width * 2 * pi * waveFrequency) - (animationValue * 2 * pi)) *
              waveHeight;
      path2.lineTo(x, y);
    }
    path2.lineTo(size.width, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
