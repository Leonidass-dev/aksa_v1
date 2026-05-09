import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/health_data.dart';
import '../../widgets/common_widgets.dart';

/// Dashboard'daki ana sağlık göstergesi — dairesel risk skoru çemberi ve trend bilgisi.
class HealthGaugeCard extends StatelessWidget {
  final RiskResult? riskResult;
  final String factorSummary;
  final double? scoreTrend; // Pozitif: İyileşme, Negatif: Kötüleşme

  const HealthGaugeCard({
    super.key,
    required this.riskResult,
    required this.factorSummary,
    this.scoreTrend,
  });

  @override
  Widget build(BuildContext context) {
    final risk = riskResult;
    final cs = Theme.of(context).colorScheme;
    final scoreColor = risk?.level.color ?? AppColors.primary;
    
    // Trend hesaplama ve ikon seçimi
    final isImproving = (scoreTrend ?? 0) >= 0;
    final trendText = scoreTrend != null 
        ? "Düne göre %${scoreTrend!.abs().toInt()} ${isImproving ? 'iyileşme' : 'gerileme'}"
        : "Tüm göstergeler dengeli";
    final trendIcon = isImproving ? Icons.trending_up_rounded : Icons.trending_down_rounded;
    final trendColor = isImproving ? AppColors.secondary : AppColors.destructive;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Sol: Büyük Dairesel Gösterge
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: CircularProgressIndicator(
                  value: (risk?.score ?? 0) / 100,
                  strokeWidth: 8,
                  backgroundColor: cs.outlineVariant.withValues(alpha: 0.1),
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
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface,
                      height: 1,
                    ),
                  ),
                  Text(
                    'SKOR',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant, letterSpacing: 1),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 20),
          // Sağ: Detaylar ve Trend
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Sağlık Durumu',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: cs.onSurface),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        risk?.level.label ?? 'Analiz Ediliyor',
                        style: TextStyle(color: scoreColor, fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  factorSummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.3),
                ),
                const Divider(height: 16),
                // Suggestion 6: Trend Satırı
                Row(
                  children: [
                    Icon(trendIcon, size: 14, color: trendColor),
                    const SizedBox(width: 4),
                    Text(
                      trendText,
                      style: TextStyle(
                        fontSize: 11,
                        color: trendColor,
                        fontWeight: FontWeight.w700,
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
