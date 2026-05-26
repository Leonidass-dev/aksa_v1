import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/common_widgets.dart';
import '../water_wave_widget.dart';

/// Su tüketimi takip kartı — ilerleme çubuğu ve hızlı ekleme butonları.
/// Geri Al (Undo) mekanizması ile yanlış eklemeleri önler.
class WaterTrackerCard extends StatelessWidget {
  final double currentMl;
  final double targetMl;
  final Future<void> Function(double amount) onAddWater;

  static const _waterColor = Color(0xFF3B82F6);
  static const _quickAddAmounts = [200, 330, 500];
  static const _minusAmount = -200;

  const WaterTrackerCard({
    super.key,
    required this.currentMl,
    required this.targetMl,
    required this.onAddWater,
  });

  void _addWithUndo(BuildContext context, double amount) async {
    // 1. Hemen ekle (iyimser güncelleme)
    HapticFeedback.lightImpact();
    await onAddWater(amount);
    
    if (!context.mounted) return;
    
    // 2. SnackBar ile Geri Al seçeneği sun
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('💧 ${amount.toInt()} ml su eklendi.'),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'GERİ AL',
          textColor: Colors.amber,
          onPressed: () async {
            // Negatif miktar göndererek geri al
            await onAddWater(-amount);
          },
        ),
      ),
    );
  }

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
                      onTap: () => _addWithUndo(context, amount.toDouble()),
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
                  }).toList()
                    ..add(
                      InkWell(
                        onTap: () => _addWithUndo(context, _minusAmount.toDouble()),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.remove, size: 14, color: Colors.red),
                              const SizedBox(width: 4),
                              const Text(
                                '200ml',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
