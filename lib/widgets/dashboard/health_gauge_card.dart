import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/health_data.dart';
import '../../widgets/common_widgets.dart';

/// Dashboard'daki ana sağlık göstergesi — dairesel risk skoru çemberi.
class HealthGaugeCard extends StatelessWidget {
  final RiskResult? riskResult;
  final String factorSummary;

  const HealthGaugeCard({
    super.key,
    required this.riskResult,
    required this.factorSummary,
  });

  @override
  Widget build(BuildContext context) {
    final risk = riskResult;
    final cs = Theme.of(context).colorScheme;
    final scoreColor = risk?.level.color ?? AppColors.primary;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Sol: Küçük Dairesel Gösterge
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: CircularProgressIndicator(
                  value: (risk?.score ?? 0) / 100,
                  strokeWidth: 10,
                  backgroundColor: cs.outlineVariant.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    risk != null ? '${risk.score.toInt()}' : '--',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface,
                      height: 1,
                    ),
                  ),
                  const Text(
                    'Skor',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 20),
          // Sağ: Detaylar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'Sağlık Durumu',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        risk?.level.label ?? '...',
                        style: TextStyle(
                          color: scoreColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  factorSummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                // İnce bir ilerleme göstergesi veya trend simgesi eklenebilir
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: scoreColor),
                    const SizedBox(width: 6),
                    Text(
                      'Yapay Zeka Analizi',
                      style: TextStyle(
                        fontSize: 11,
                        color: scoreColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
