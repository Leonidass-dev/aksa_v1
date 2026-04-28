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
    return AppCard(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).cardColor,
            Theme.of(context).cardColor.withValues(alpha: 0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Genel Sağlık Durumu',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (risk?.level.color ?? AppColors.primary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  risk?.level.label ?? 'Hesaplanıyor...',
                  style: TextStyle(
                    color: risk?.level.color ?? AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: CircularProgressIndicator(
                  value: (risk?.score ?? 0) / 100,
                  strokeWidth: 16,
                  backgroundColor: Colors.grey.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    risk?.level.color ?? AppColors.primary,
                  ),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    risk != null ? '${risk.score.toInt()}' : '--',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                    ),
                  ),
                  const Text(
                    'Risk Skoru',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            factorSummary,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
          ),
        ],
      ),
    );
  }
}
