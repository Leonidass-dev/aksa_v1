import 'package:flutter_test/flutter_test.dart';
import 'package:aksa_v1/models/health_entry.dart';

/// HealthEntry model testleri.
///
/// Not: toJson() metodu FieldValue.serverTimestamp() kullandığı için
/// Firebase ortamı gerektiren entegrasyon testlerinde test edilmelidir.
/// Burada Firebase bağımsız olan fromJson, copyWith ve veri bütünlüğü
/// testleri yer alır.
void main() {
  group('HealthEntry — fromJson', () {
    test('Tüm alanlar doğru parse edilmeli', () {
      final json = <String, dynamic>{
        'date': '2026-04-29T10:30:00.000',
        'steps': 8500,
        'active_calories': 350,
        'total_calories': 2100,
        'distance_m': 6500,
        'heart_rate': 72,
        'resting_heart_rate': 60,
        'spo2': 97,
        'systolic': 120,
        'diastolic': 80,
        'sleep_hours': 7.5,
        'sleep_deep_min': 90,
        'sleep_light_min': 180,
        'sleep_rem_min': 60,
        'sleep_awake_min': 15,
        'stress_level': 35,
        'weight': 75,
        'water_ml': 1500,
        'mood': 'happy',
        'source': 'health_connect',
      };

      final entry = HealthEntry.fromJson(json);

      expect(entry.steps, equals(8500));
      expect(entry.heartRate, equals(72));
      expect(entry.restingHeartRate, equals(60));
      expect(entry.spo2, equals(97));
      expect(entry.systolic, equals(120));
      expect(entry.diastolic, equals(80));
      expect(entry.sleepHours, equals(7.5));
      expect(entry.sleepDeepMin, equals(90));
      expect(entry.sleepLightMin, equals(180));
      expect(entry.sleepRemMin, equals(60));
      expect(entry.sleepAwakeMin, equals(15));
      expect(entry.activeCalories, equals(350));
      expect(entry.totalCalories, equals(2100));
      expect(entry.distanceM, equals(6500));
      expect(entry.stressLevel, equals(35));
      expect(entry.weight, equals(75));
      expect(entry.waterMl, equals(1500));
      expect(entry.mood, equals('happy'));
      expect(entry.source, equals('health_connect'));
    });

    test('null/eksik alanlar varsayılan değer almalı', () {
      final json = <String, dynamic>{
        'date': '2026-04-29T00:00:00.000',
        // Diğer alanlar yok
      };

      final entry = HealthEntry.fromJson(json);

      expect(entry.steps, equals(0));
      expect(entry.heartRate, equals(0));
      expect(entry.spo2, equals(0));
      expect(entry.sleepHours, equals(0));
      expect(entry.waterMl, equals(0));
      expect(entry.mood, equals('neutral'));
      expect(entry.source, equals('manual'));
    });

    test('int değerler double olarak parse edilmeli', () {
      final json = <String, dynamic>{
        'date': '2026-04-29T00:00:00.000',
        'steps': 5000,         // int geliyor
        'heart_rate': 72,       // int geliyor
        'sleep_hours': 7,       // int geliyor, double olmalı
      };

      final entry = HealthEntry.fromJson(json);

      expect(entry.steps, isA<double>());
      expect(entry.heartRate, isA<double>());
      expect(entry.sleepHours, isA<double>());
      expect(entry.sleepHours, equals(7.0));
    });

    test('geçersiz tarih DateTime.now() dönmeli', () {
      final json = <String, dynamic>{
        'date': 'invalid-date',
      };

      final entry = HealthEntry.fromJson(json);
      final now = DateTime.now();

      // Geçersiz tarih bugüne düşmeli (aynı gün kontrolü)
      expect(entry.date.year, equals(now.year));
      expect(entry.date.month, equals(now.month));
      expect(entry.date.day, equals(now.day));
    });
  });

  group('HealthEntry — copyWith', () {
    test('sadece belirtilen alanları değiştirmeli', () {
      final original = HealthEntry(
        date: DateTime(2026, 4, 29),
        steps: 5000,
        heartRate: 72,
        weight: 75,
        mood: 'neutral',
        source: 'health_connect',
      );

      final updated = original.copyWith(steps: 10000, weight: 73);

      expect(updated.steps, equals(10000));
      expect(updated.weight, equals(73));
      expect(updated.heartRate, equals(72),
          reason: 'Değiştirilmeyen alan korunmalı');
      expect(updated.date, equals(original.date));
      expect(updated.mood, equals('neutral'));
      expect(updated.source, equals('health_connect'));
    });

    test('source değiştirilebilmeli', () {
      final original = HealthEntry(
        date: DateTime.now(),
        source: 'health_connect',
      );

      final updated = original.copyWith(source: 'manual');

      expect(updated.source, equals('manual'));
    });

    test('tüm alanlar korunmalı', () {
      final original = HealthEntry(
        date: DateTime(2026, 4, 29),
        steps: 8500,
        heartRate: 72,
        restingHeartRate: 60,
        spo2: 97,
        systolic: 120,
        diastolic: 80,
        sleepHours: 7.5,
        sleepDeepMin: 90,
        sleepLightMin: 180,
        sleepRemMin: 60,
        sleepAwakeMin: 15,
        activeCalories: 350,
        totalCalories: 2100,
        distanceM: 6500,
        stressLevel: 35,
        weight: 75,
        waterMl: 1500,
        mood: 'happy',
        source: 'health_connect',
      );

      // Sadece steps değiştir, geri kalan tüm alanlar aynı kalmalı
      final updated = original.copyWith(steps: 9000);

      expect(updated.heartRate, equals(72));
      expect(updated.restingHeartRate, equals(60));
      expect(updated.spo2, equals(97));
      expect(updated.systolic, equals(120));
      expect(updated.diastolic, equals(80));
      expect(updated.sleepHours, equals(7.5));
      expect(updated.sleepDeepMin, equals(90));
      expect(updated.sleepLightMin, equals(180));
      expect(updated.sleepRemMin, equals(60));
      expect(updated.sleepAwakeMin, equals(15));
      expect(updated.activeCalories, equals(350));
      expect(updated.totalCalories, equals(2100));
      expect(updated.distanceM, equals(6500));
      expect(updated.stressLevel, equals(35));
      expect(updated.weight, equals(75));
      expect(updated.waterMl, equals(1500));
      expect(updated.mood, equals('happy'));
      expect(updated.source, equals('health_connect'));
    });
  });

  group('HealthEntry — Varsayılan Değerler', () {
    test('constructor varsayılanları doğru olmalı', () {
      final entry = HealthEntry(date: DateTime.now());

      expect(entry.steps, equals(0));
      expect(entry.activeCalories, equals(0));
      expect(entry.totalCalories, equals(0));
      expect(entry.distanceM, equals(0));
      expect(entry.heartRate, equals(0));
      expect(entry.restingHeartRate, equals(0));
      expect(entry.spo2, equals(0));
      expect(entry.systolic, equals(0));
      expect(entry.diastolic, equals(0));
      expect(entry.sleepHours, equals(0));
      expect(entry.stressLevel, equals(0));
      expect(entry.weight, equals(0));
      expect(entry.waterMl, equals(0));
      expect(entry.mood, equals('neutral'));
      expect(entry.source, equals('manual'));
    });
  });
}
