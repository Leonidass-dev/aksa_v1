import 'package:flutter_test/flutter_test.dart';
import 'package:aksa_v1/services/risk_engine.dart';
import 'package:aksa_v1/models/health_data.dart';

void main() {
  group('RiskEngine — Kalibrasyon', () {
    test('Sağlıklı veriler düşük risk üretmeli', () {
      final snap = RiskEngine.demoSnapshot(
        hrMean: 72,
        hrStd: 8,
        stepSum: 10000,
        activeMinutes: 45,
        sleepHours: 7.5,
        sleepEfficiency: 0.88,
        spo2Mean: 97,
        stressScore: 25,
      );
      final result = RiskEngine.compute(snap);

      expect(result.score, lessThanOrEqualTo(33),
          reason: 'Sağlıklı veriler ile skor 0-33 aralığında olmalı');
      expect(result.level, equals(RiskLevel.low));
    });

    test('Riskli veriler yüksek risk üretmeli', () {
      final snap = RiskEngine.demoSnapshot(
        hrMean: 120,
        hrStd: 25,
        stepSum: 1000,
        activeMinutes: 5,
        sleepHours: 3.5,
        sleepEfficiency: 0.60,
        spo2Mean: 88,
        stressScore: 85,
      );
      final result = RiskEngine.compute(snap);

      expect(result.score, greaterThan(66),
          reason: 'Riskli veriler ile skor 67+ olmalı');
      expect(result.level, equals(RiskLevel.high));
    });

    test('Orta veriler orta risk üretmeli', () {
      // Hedef rawProb ~0.50-0.55 → Sigmoid ≈ 50 skor
      // HR>100 → +0.18, steps<3000 → +0.15, activeMin<20 → +0.08,
      // sleep<6.5 → +0.12, stres>50 → +0.05 = ~0.58 → clamp → Sigmoid ≈ 52
      final snap = RiskEngine.demoSnapshot(
        hrMean: 105,         // Normal aralık dışı → +0.18
        hrStd: 10,           // Normal
        stepSum: 2500,       // Çok düşük → +0.15
        activeMinutes: 15,   // Yetersiz (<20) → +0.08
        sleepHours: 6.0,     // Yetersiz → +0.12
        sleepEfficiency: 0.80, // Normal
        spo2Mean: 97,        // Normal → -0.05
        stressScore: 60,     // Orta stres (>50) → +0.05
      );
      final result = RiskEngine.compute(snap);

      expect(result.score, greaterThan(33),
          reason: 'Orta riskli verilerle skor 34+ olmalı (skor: ${result.score})');
      expect(result.score, lessThanOrEqualTo(66),
          reason: 'Orta riskli verilerle skor 66 altında olmalı (skor: ${result.score})');
      expect(result.level, equals(RiskLevel.medium));
    });

    test('Risk skoru 0-100 aralığında olmalı', () {
      // Çok kötü veriler
      final worstSnap = RiskEngine.demoSnapshot(
        hrMean: 150,
        hrStd: 40,
        stepSum: 0,
        activeMinutes: 0,
        sleepHours: 2,
        sleepEfficiency: 0.3,
        spo2Mean: 80,
        stressScore: 100,
      );
      final worstResult = RiskEngine.compute(worstSnap);
      expect(worstResult.score, greaterThanOrEqualTo(0));
      expect(worstResult.score, lessThanOrEqualTo(100));

      // Çok iyi veriler
      final bestSnap = RiskEngine.demoSnapshot(
        hrMean: 65,
        hrStd: 5,
        stepSum: 15000,
        activeMinutes: 60,
        sleepHours: 8,
        sleepEfficiency: 0.95,
        spo2Mean: 99,
        stressScore: 10,
      );
      final bestResult = RiskEngine.compute(bestSnap);
      expect(bestResult.score, greaterThanOrEqualTo(0));
      expect(bestResult.score, lessThanOrEqualTo(100));
    });
  });

  group('RiskEngine — Faktör Analizi', () {
    test('Top faktörler katkı büyüklüğüne göre sıralanmalı', () {
      final snap = RiskEngine.demoSnapshot(
        hrMean: 110,
        hrStd: 22,
        stepSum: 2000,
        activeMinutes: 10,
        sleepHours: 4,
        sleepEfficiency: 0.65,
        spo2Mean: 93,
        stressScore: 75,
      );
      final result = RiskEngine.compute(snap);

      expect(result.topFactors, isNotEmpty);
      expect(result.topFactors.length, lessThanOrEqualTo(5));

      // Katkılar azalan sırada olmalı
      for (int i = 0; i < result.topFactors.length - 1; i++) {
        expect(
          result.topFactors[i].contribution.abs(),
          greaterThanOrEqualTo(result.topFactors[i + 1].contribution.abs()),
        );
      }
    });

    test('SpO2 null ise SpO2 faktörü eklenmemeli', () {
      final snap = RiskEngine.demoSnapshot(spo2Mean: null);
      final result = RiskEngine.compute(snap);

      final spo2Factors = result.topFactors
          .where((f) => f.name == 'Oksijen Saturasyonu')
          .toList();
      expect(spo2Factors, isEmpty);
    });
  });

  group('RiskEngine — Eşik Tutarlılığı', () {
    test('Skor 33 ise level low olmalı', () {
      // Kalibrasyon sonucu tam 33'e düşen skor → low
      final snap = RiskEngine.demoSnapshot();
      final result = RiskEngine.compute(snap);

      if (result.score <= 33) {
        expect(result.level, equals(RiskLevel.low));
      } else if (result.score <= 66) {
        expect(result.level, equals(RiskLevel.medium));
      } else {
        expect(result.level, equals(RiskLevel.high));
      }
    });

    test('modelVersion rule-based-v1.0 olmalı', () {
      final snap = RiskEngine.demoSnapshot();
      final result = RiskEngine.compute(snap);
      expect(result.modelVersion, equals('rule-based-v1.0'));
    });
  });
}
