import 'package:flutter/material.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/app_line_chart.dart';
import '../../theme/app_theme.dart';

/// Haftalık risk trendi çizgi grafiği kartı.
class WeeklyTrendCard extends StatelessWidget {
  final List<double> weeklyData;

  static const _days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  const WeeklyTrendCard({super.key, required this.weeklyData});

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
              Text(
                'Haftalık Risk Trendi',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: cs.onSurface,
                ),
              ),
              Row(
                children: _days.map((day) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      day,
                      style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: CustomPaint(
              size: const Size(double.infinity, 80),
              painter: AppLineChartPainter(data: weeklyData, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
