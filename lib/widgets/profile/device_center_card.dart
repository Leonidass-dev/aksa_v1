import 'package:flutter/material.dart';
import 'package:health/health.dart';
import '../../theme/app_theme.dart';
import '../common_widgets.dart';
import '../../services/health_service.dart';
import '../../services/health_data_parser.dart';

class DeviceCenterCard extends StatelessWidget {
  final ParsedHealthData? data;
  final DateTime? lastSyncTime;

  const DeviceCenterCard({
    super.key,
    this.data,
    this.lastSyncTime,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    // Ana kaynağı belirle
    String primaryBrand = "Bilinmeyen Cihaz";
    String brandIcon = "📱";
    
    if (data != null && data!.allSources.isNotEmpty) {
      final sources = data!.allSources.map((s) => s.toLowerCase()).toList();
      if (sources.any((s) => s.contains('xiaomi') || s.contains('mi.fitness') || s.contains('redmi'))) {
        primaryBrand = "Xiaomi / Redmi Watch";
        brandIcon = "⌚";
      } else if (sources.any((s) => s.contains('huawei'))) {
        primaryBrand = "Huawei Health";
        brandIcon = "⌚";
      } else if (sources.any((s) => s.contains('samsung'))) {
        primaryBrand = "Samsung Health";
        brandIcon = "⌚";
      } else if (sources.any((s) => s.contains('garmin'))) {
        primaryBrand = "Garmin Connect";
        brandIcon = "⌚";
      } else if (sources.any((s) => s.contains('fitness'))) {
        primaryBrand = "Google Fit";
      }
    }

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(brandIcon, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primaryBrand,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      lastSyncTime != null 
                        ? 'Son Senkronizasyon: ${_formatTime(lastSyncTime!)}' 
                        : 'Henüz senkronize edilmedi',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 12),
                    SizedBox(width: 4),
                    Text('Bağlı', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Text(
            'Sensör Durumları',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _sensorStatus(context, 'Adım', _hasType(HealthDataType.STEPS)),
              _sensorStatus(context, 'Nabız', _hasType(HealthDataType.HEART_RATE) || _hasType(HealthDataType.RESTING_HEART_RATE)),
              _sensorStatus(context, 'Uyku', _hasType(HealthDataType.SLEEP_ASLEEP) || _hasType(HealthDataType.SLEEP_SESSION)),
              _sensorStatus(context, 'Oksijen', _hasType(HealthDataType.BLOOD_OXYGEN)),
              _sensorStatus(context, 'Kalori', _hasType(HealthDataType.ACTIVE_ENERGY_BURNED)),
            ],
          ),
        ],
      ),
    );
  }

  bool _hasType(HealthDataType type) {
    if (data == null) return false;
    return data!.typeSources.containsKey(type);
  }

  Widget _sensorStatus(BuildContext context, String label, bool active) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? cs.primaryContainer.withValues(alpha: 0.3) : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? cs.primary.withValues(alpha: 0.2) : cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.sensors : Icons.sensors_off,
            size: 12,
            color: active ? cs.primary : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
