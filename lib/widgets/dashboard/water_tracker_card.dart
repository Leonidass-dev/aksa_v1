import 'package:flutter/material.dart';
import '../../widgets/common_widgets.dart';
import '../water_wave_widget.dart';

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

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Sol: Dalga Animasyonlu Daire
          WaterWaveWidget(currentMl: currentMl, targetMl: targetMl),
          const SizedBox(width: 24),
          // Sağ: Bilgiler ve Butonlar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Su Tüketimi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Hedef: ${targetMl.toInt()} ml',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quickAddAmounts.map((amount) {
                    return InkWell(
                      onTap: () => onAddWater(amount.toDouble()),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _waterColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _waterColor.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add, size: 14, color: _waterColor),
                            const SizedBox(width: 4),
                            Text(
                              '${amount}ml',
                              style: const TextStyle(
                                color: _waterColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
