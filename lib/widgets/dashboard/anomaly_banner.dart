import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

/// Anomali tespit edildiğinde gösterilen uyarı banner'ı.
class AnomalyBanner extends StatelessWidget {
  final AnomalyApiResult anomalyResult;
  final VoidCallback onViewDetails;
  final VoidCallback onDismiss;

  const AnomalyBanner({
    super.key,
    required this.anomalyResult,
    required this.onViewDetails,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.destructive.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.destructive.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.destructive, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sağlık Uyarısı!',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.destructive),
                ),
                Text(
                  anomalyResult.anomalies.first.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.destructive.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onViewDetails,
            child: const Text('İncele', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: Icon(Icons.close, size: 18, color: AppColors.destructive.withValues(alpha: 0.6)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}
