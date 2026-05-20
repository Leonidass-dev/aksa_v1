import 'package:flutter/material.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/app_line_chart.dart';
import '../../theme/app_theme.dart';

/// Haftalık risk trendi çizgi grafiği kartı.
class WeeklyTrendCard extends StatelessWidget {
  final List<double> weeklyData;

  const WeeklyTrendCard({super.key, required this.weeklyData});

  List<String> _getDynamicDays() {
    final now = DateTime.now();
    const trDays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final List<String> result = [];
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      result.add(trDays[date.weekday - 1]);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dynamicDays = _getDynamicDays();
    
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Haftalık Risk Trendi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: dynamicDays.map((day) {
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
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 80,
                child: CustomPaint(
                  size: const Size(double.infinity, 80),
                  painter: AppLineChartPainter(
                    data: weeklyData,
                    color: weeklyData.every((v) => v == 0) 
                        ? cs.outlineVariant.withValues(alpha: 0.3)
                        : AppColors.primary,
                  ),
                ),
              ),
              if (weeklyData.every((v) => v == 0))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.query_stats_rounded, size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        'Analiz için yeterli veri toplanıyor...',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
