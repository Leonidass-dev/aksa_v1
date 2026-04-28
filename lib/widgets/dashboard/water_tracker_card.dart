import 'package:flutter/material.dart';
import '../../widgets/common_widgets.dart';

/// Su tüketimi takip kartı — ilerleme çubuğu ve hızlı ekleme butonları.
class WaterTrackerCard extends StatelessWidget {
  final double currentMl;
  final double targetMl;
  final Future<void> Function(double amount) onAddWater;

  static const _waterColor = Color(0xFF3B82F6);
  static const _quickAddAmounts = [200, 330, 500];

  const WaterTrackerCard({
    super.key,
    required this.currentMl,
    required this.targetMl,
    required this.onAddWater,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = (currentMl / targetMl).clamp(0.0, 1.0);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _waterColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.water_drop_rounded, color: _waterColor, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Su Takibi',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
              Text(
                '${currentMl.toInt()} / ${targetMl.toInt()} ml',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _waterColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 10,
                  backgroundColor: _waterColor.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(_waterColor),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Text(
                    '${(pct * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      color: pct > 0.4 ? Colors.white : _waterColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Quick add buttons
          Row(
            children: _quickAddAmounts.map((amount) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: amount == _quickAddAmounts.last ? 0 : 8),
                  child: InkWell(
                    onTap: () => onAddWater(amount.toDouble()),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _waterColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _waterColor.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.add_rounded, color: _waterColor, size: 16),
                          const SizedBox(height: 2),
                          Text(
                            '${amount}ml',
                            style: TextStyle(
                              color: _waterColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
