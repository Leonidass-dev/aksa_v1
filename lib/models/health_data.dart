import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HealthSnapshot {
  final String userId;
  final DateTime windowEnd;

  // M2 çıktısı — pencere bazlı özellikler
  final double hrMean;
  final double hrStd;
  final double hrMin;
  final double hrMax;
  final int stepSum;
  final int activeMinutes;
  final double sleepHours;
  final double sleepEfficiency; // 0.0–1.0
  final double? spo2Mean;
  final double? stressScore; // 0–100

  const HealthSnapshot({
    required this.userId,
    required this.windowEnd,
    required this.hrMean,
    required this.hrStd,
    required this.hrMin,
    required this.hrMax,
    required this.stepSum,
    required this.activeMinutes,
    required this.sleepHours,
    required this.sleepEfficiency,
    this.spo2Mean,
    this.stressScore,
  });
}

class RiskResult {
  final double score; // 0–100
  final RiskLevel level; // düşük/orta/yüksek
  final List<RiskFactor> topFactors; // SHAP benzeri katkılar
  final DateTime windowEnd;
  final String modelVersion;

  const RiskResult({
    required this.score,
    required this.level,
    required this.topFactors,
    required this.windowEnd,
    required this.modelVersion,
  });
}

enum RiskLevel { low, medium, high }

extension RiskLevelExtension on RiskLevel {
  /// API'den gelen string'i RiskLevel'a çevirir.
  /// Daha önce dashboard ve risk_score ekranlarında duplike edilmişti.
  static RiskLevel fromString(String level) {
    switch (level) {
      case 'high':
        return RiskLevel.high;
      case 'medium':
        return RiskLevel.medium;
      default:
        return RiskLevel.low;
    }
  }

  String get label {
    switch (this) {
      case RiskLevel.low:
        return 'Düşük Risk';
      case RiskLevel.medium:
        return 'Orta Risk';
      case RiskLevel.high:
        return 'Yüksek Risk';
    }
  }

  String get labelEn {
    switch (this) {
      case RiskLevel.low:
        return 'Low Risk';
      case RiskLevel.medium:
        return 'Medium Risk';
      case RiskLevel.high:
        return 'High Risk';
    }
  }

  /// Risk seviyesine karşılık gelen renk.
  Color get color {
    switch (this) {
      case RiskLevel.low:
        return AppColors.secondary;
      case RiskLevel.medium:
        return AppColors.accent;
      case RiskLevel.high:
        return AppColors.destructive;
    }
  }

  /// Risk seviyesine karşılık gelen ikon.
  IconData get icon {
    switch (this) {
      case RiskLevel.low:
        return Icons.check_circle_outline;
      case RiskLevel.medium:
        return Icons.warning_amber_outlined;
      case RiskLevel.high:
        return Icons.error_outline;
    }
  }
}

class RiskFactor {
  final String name;
  final double contribution; // + arttırıyor, - azaltıyor
  final String description;

  const RiskFactor({
    required this.name,
    required this.contribution,
    required this.description,
  });
}
