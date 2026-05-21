import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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

enum RiskLevel { low, medium, high, unknown }

extension RiskLevelExtension on RiskLevel {
  /// API'den gelen string'i RiskLevel'a çevirir.
  static RiskLevel fromString(String level) {
    switch (level.trim().toLowerCase()) {
      case 'high':
      case 'yüksek':
      case 'yuksek':
        return RiskLevel.high;
      case 'medium':
      case 'orta':
        return RiskLevel.medium;
      case 'unknown':
        return RiskLevel.unknown;
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
      case RiskLevel.unknown:
        return 'Hesaplanamadı';
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
      case RiskLevel.unknown:
        return AppColors.mutedForeground;
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
      case RiskLevel.unknown:
        return Icons.help_outline;
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
