import '../models/health_data.dart';

/// Tez Modül 3 — Risk Skoru Üretimi
///
/// Gerçek sistemde XGBoost (tablosal) + GRU (zaman serisi) füzyon modeli
/// kullanılacaktır. Bu prototip aynı hesaplama mantığını kural tabanlı
/// olarak uygular; model entegrasyonunda aynı [RiskResult] arayüzü korunur.
class RiskEngine {
  static const String _modelVersion = 'rule-based-v1.0';

  /// Tezdeki iki aşamalı risk üretimi:
  /// 1. Ham olasılık hesapla (0.0–1.0)
  /// 2. Platt scaling benzeri kalibrasyon → 0–100 skora çevir
  static RiskResult compute(HealthSnapshot snap) {
    final factors = <RiskFactor>[];
    double rawProbability = 0.0;

    // ── Kalp Atışı Bileşeni ──────────────────────────────────────────
    double hrContrib = 0.0;

    if (snap.hrMean < 50 || snap.hrMean > 100) {
      hrContrib += 0.18;
      factors.add(
        RiskFactor(
          name: 'Kalp Atış Hızı',
          contribution: 18.0,
          description:
              'Ortalama nabız normal aralık dışında '
              '(${snap.hrMean.toInt()} bpm)',
        ),
      );
    } else if (snap.hrMean > 85) {
      hrContrib += 0.08;
      factors.add(
        RiskFactor(
          name: 'Kalp Atış Hızı',
          contribution: 8.0,
          description:
              'Ortalama nabız yüksek normale yakın '
              '(${snap.hrMean.toInt()} bpm)',
        ),
      );
    } else {
      factors.add(
        RiskFactor(
          name: 'Kalp Atış Hızı',
          contribution: -5.0,
          description: 'Nabız optimal aralıkta (${snap.hrMean.toInt()} bpm)',
        ),
      );
    }

    // HR değişkenliği — yüksek std anomali işareti
    if (snap.hrStd > 20) {
      hrContrib += 0.10;
      factors.add(
        RiskFactor(
          name: 'Nabız Değişkenliği',
          contribution: 10.0,
          description:
              'Yüksek nabız değişkenliği (std: '
              '${snap.hrStd.toStringAsFixed(1)})',
        ),
      );
    }
    rawProbability += hrContrib;

    // ── Aktivite Bileşeni ─────────────────────────────────────────────
    double actContrib = 0.0;

    if (snap.stepSum < 3000) {
      actContrib += 0.15;
      factors.add(
        RiskFactor(
          name: 'Günlük Adım',
          contribution: 15.0,
          description: 'Adım sayısı çok düşük (${snap.stepSum} adım)',
        ),
      );
    } else if (snap.stepSum < 6000) {
      actContrib += 0.07;
      factors.add(
        RiskFactor(
          name: 'Günlük Adım',
          contribution: 7.0,
          description: 'Adım sayısı hedefin altında (${snap.stepSum} adım)',
        ),
      );
    } else if (snap.stepSum >= 10000) {
      actContrib -= 0.08;
      factors.add(
        RiskFactor(
          name: 'Günlük Adım',
          contribution: -8.0,
          description: 'Günlük hedef aşıldı (${snap.stepSum} adım) 🎯',
        ),
      );
    } else {
      factors.add(
        RiskFactor(
          name: 'Günlük Adım',
          contribution: -3.0,
          description: 'Adım sayısı iyi düzeyde (${snap.stepSum} adım)',
        ),
      );
    }

    if (snap.activeMinutes < 20) {
      actContrib += 0.08;
      factors.add(
        RiskFactor(
          name: 'Aktif Süre',
          contribution: 8.0,
          description: 'Aktif süre yetersiz (${snap.activeMinutes} dk)',
        ),
      );
    }
    rawProbability += actContrib;

    // ── Uyku Bileşeni ─────────────────────────────────────────────────
    double sleepContrib = 0.0;

    if (snap.sleepHours < 5.0) {
      sleepContrib += 0.20;
      factors.add(
        RiskFactor(
          name: 'Uyku Süresi',
          contribution: 20.0,
          description:
              'Ciddi uyku eksikliği '
              '(${snap.sleepHours.toStringAsFixed(1)} saat)',
        ),
      );
    } else if (snap.sleepHours < 6.5) {
      sleepContrib += 0.12;
      factors.add(
        RiskFactor(
          name: 'Uyku Süresi',
          contribution: 12.0,
          description:
              'Uyku süresi yetersiz '
              '(${snap.sleepHours.toStringAsFixed(1)} saat)',
        ),
      );
    } else if (snap.sleepHours >= 7.0 && snap.sleepHours <= 9.0) {
      sleepContrib -= 0.08;
      factors.add(
        RiskFactor(
          name: 'Uyku Süresi',
          contribution: -8.0,
          description:
              'Uyku süresi optimal '
              '(${snap.sleepHours.toStringAsFixed(1)} saat)',
        ),
      );
    } else {
      factors.add(
        RiskFactor(
          name: 'Uyku Süresi',
          contribution: 3.0,
          description:
              'Uyku süresi biraz uzun '
              '(${snap.sleepHours.toStringAsFixed(1)} saat)',
        ),
      );
    }

    if (snap.sleepEfficiency < 0.75) {
      sleepContrib += 0.10;
      factors.add(
        RiskFactor(
          name: 'Uyku Kalitesi',
          contribution: 10.0,
          description:
              'Uyku verimliliği düşük '
              '(%${(snap.sleepEfficiency * 100).toInt()})',
        ),
      );
    }
    rawProbability += sleepContrib;

    // ── SpO2 Bileşeni ─────────────────────────────────────────────────
    if (snap.spo2Mean != null) {
      if (snap.spo2Mean! < 92) {
        rawProbability += 0.25;
        factors.add(
          RiskFactor(
            name: 'Oksijen Saturasyonu',
            contribution: 25.0,
            description:
                'SpO2 kritik düşük '
                '(%${snap.spo2Mean!.toInt()})',
          ),
        );
      } else if (snap.spo2Mean! < 95) {
        rawProbability += 0.12;
        factors.add(
          RiskFactor(
            name: 'Oksijen Saturasyonu',
            contribution: 12.0,
            description:
                'SpO2 normale yakın alt sınırda '
                '(%${snap.spo2Mean!.toInt()})',
          ),
        );
      } else {
        rawProbability -= 0.05;
        factors.add(
          RiskFactor(
            name: 'Oksijen Saturasyonu',
            contribution: -5.0,
            description: 'SpO2 normal (%${snap.spo2Mean!.toInt()})',
          ),
        );
      }
    }

    // ── Stres Bileşeni ────────────────────────────────────────────────
    if (snap.stressScore != null) {
      if (snap.stressScore! > 70) {
        rawProbability += 0.12;
        factors.add(
          RiskFactor(
            name: 'Stres Seviyesi',
            contribution: 12.0,
            description:
                'Yüksek stres skoru '
                '(${snap.stressScore!.toInt()}/100)',
          ),
        );
      } else if (snap.stressScore! > 50) {
        rawProbability += 0.05;
        factors.add(
          RiskFactor(
            name: 'Stres Seviyesi',
            contribution: 5.0,
            description:
                'Orta düzey stres '
                '(${snap.stressScore!.toInt()}/100)',
          ),
        );
      }
    }

    // ── Platt Scaling benzeri kalibrasyon ─────────────────────────────
    // Ham olasılığı 0–100 skora çevir (tez Modül 3, adım 2)
    // Sınırlama: ham prob negatif olabilir (iyi sağlık durumu)
    final clampedProb = rawProbability.clamp(0.0, 1.0);
    // Sigmoid benzeri yumuşatma → [0, 100]
    final calibratedScore = _calibrate(clampedProb);

    // ── Risk seviyesi eşikleme (tez: 0–33 düşük, 34–66 orta, 67–100 yüksek)
    final RiskLevel level;
    if (calibratedScore <= 33) {
      level = RiskLevel.low;
    } else if (calibratedScore <= 66) {
      level = RiskLevel.medium;
    } else {
      level = RiskLevel.high;
    }

    // ── Top-5 faktör seçimi (SHAP benzeri sıralama — katkı büyüklüğüne göre)
    final sortedFactors = List<RiskFactor>.from(factors)
      ..sort((a, b) => b.contribution.abs().compareTo(a.contribution.abs()));
    final top5 = sortedFactors.take(5).toList();

    return RiskResult(
      score: calibratedScore,
      level: level,
      topFactors: top5,
      windowEnd: snap.windowEnd,
      modelVersion: _modelVersion,
    );
  }

  /// Ham olasılığı 0–100 skora kalibre eder.
  /// Düşük prob → yüksek skor (sağlıklı = yüksek skor mantığı)
  static double _calibrate(double prob) {
    // prob=0.0 → score=100, prob=1.0 → score=0
    // Lineer ters çevirme + yumuşatma
    final inverted = 1.0 - prob;
    // Sigmoid ile 0.2–0.8 aralığına sıkıştır, sonra 0–100'e ölçekle
    final sigmoid = 1.0 / (1.0 + _exp(-10 * (inverted - 0.5)));
    return (sigmoid * 100).clamp(0.0, 100.0);
  }

  static double _exp(double x) {
    // Dart'ta math import olmadan basit exp yaklaşımı
    // Gerçek sistemde dart:math kullan
    if (x > 20) return 485165195.4;
    if (x < -20) return 0.0000000021;
    double result = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 20; i++) {
      term *= x / i;
      result += term;
    }
    return result;
  }

  /// Demo snapshot — DataEntry ekranından gelen verilerle oluşturulur
  static HealthSnapshot demoSnapshot({
    double hrMean = 72,
    double hrStd = 8,
    double hrMin = 58,
    double hrMax = 95,
    int stepSum = 8432,
    int activeMinutes = 45,
    double sleepHours = 7.5,
    double sleepEfficiency = 0.88,
    double? spo2Mean = 97.0,
    double? stressScore = 35.0,
  }) {
    return HealthSnapshot(
      userId: 'demo-user-001',
      windowEnd: DateTime.now(),
      hrMean: hrMean,
      hrStd: hrStd,
      hrMin: hrMin,
      hrMax: hrMax,
      stepSum: stepSum,
      activeMinutes: activeMinutes,
      sleepHours: sleepHours,
      sleepEfficiency: sleepEfficiency,
      spo2Mean: spo2Mean,
      stressScore: stressScore,
    );
  }
}
