import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../common_widgets.dart';

class DeviceStatusCard extends StatelessWidget {
  final String deviceName;
  final DateTime? lastSync;
  final bool isConnected;

  const DeviceStatusCard({
    super.key,
    this.deviceName = 'Redmi Watch 4',
    this.lastSync,
    this.isConnected = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final syncText = lastSync != null 
        ? '${lastSync!.hour.toString().padLeft(2, '0')}:${lastSync!.minute.toString().padLeft(2, '0')}'
        : '--:--';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              deviceName.contains('Watch') ? Icons.watch_rounded : Icons.smartphone_rounded,
              color: AppColors.secondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isConnected ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isConnected ? 'Bağlı' : 'Bağlantı Kesildi',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Son Senkronizasyon',
                style: TextStyle(fontSize: 10, color: AppColors.mutedForeground),
              ),
              const SizedBox(height: 2),
              Text(
                syncText,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
