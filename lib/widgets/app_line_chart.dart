import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Dashboard ve Reports'taki tekrar eden CustomPainter'ı birleştirir.
///
/// Kullanım:
/// ```dart
/// CustomPaint(
///   size: Size(double.infinity, 80),
///   painter: AppLineChartPainter(
///     data: [10, 20, 30],
///     color: AppColors.primary,
///   ),
/// )
/// ```
class AppLineChartPainter extends CustomPainter {
  final List<double> data;
  final List<double>? data2; // Opsiyonel ikinci seri (ör: diastolik)
  final Color color;
  final Color? color2;
  final double strokeWidth;
  final double dotRadius;

  const AppLineChartPainter({
    required this.data,
    this.data2,
    required this.color,
    this.color2,
    this.strokeWidth = 3,
    this.dotRadius = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawSeries(canvas, size, data, color);
    if (data2 != null) {
      _drawSeries(canvas, size, data2!, color2 ?? AppColors.secondary);
    }
  }

  void _drawSeries(Canvas canvas, Size size, List<double> d, Color c) {
    if (d.isEmpty) return;

    // Tek veri noktası — sadece merkeze nokta çiz
    if (d.length < 2) {
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        dotRadius,
        Paint()..color = c,
      );
      return;
    }

    final minV = d.reduce((a, b) => a < b ? a : b);
    final maxV = d.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV == 0) ? 1.0 : maxV - minV;

    final linePaint = Paint()
      ..color = c
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = c
      ..style = PaintingStyle.fill;

    final path = Path();
    final stepX = size.width / (d.length - 1);

    for (int i = 0; i < d.length; i++) {
      final x = i * stepX;
      final norm = (d[i] - minV) / range;
      final y = size.height - (norm * size.height * 0.8) - size.height * 0.1;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final px = (i - 1) * stepX;
        final pn = (d[i - 1] - minV) / range;
        final py = size.height - (pn * size.height * 0.8) - size.height * 0.1;
        final cpX = (px + x) / 2;
        path.cubicTo(cpX, py, cpX, y, x, y);
      }
      canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(AppLineChartPainter oldDelegate) =>
      data != oldDelegate.data ||
      data2 != oldDelegate.data2 ||
      color != oldDelegate.color;
}
