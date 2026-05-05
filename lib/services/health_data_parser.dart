import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import '../models/health_entry.dart';

/// Health Connect'ten çekilen ham veri noktalarının ayrıştırma ve
/// kümeleme işlemlerini yürüten yardımcı sınıf.
///
/// `HealthService.syncFromDevice()` metodunun SRP uyumu için
/// veri işleme sorumluluğu bu sınıfa devredilmiştir.
class HealthDataParser {
  HealthDataParser._();

  /// Health Connect ham veri noktalarından bugünün kaynak bazlı
  /// metriklerini hesaplar.
  static ParsedHealthData parse({
    required List<HealthDataPoint> stepsData,
    required List<HealthDataPoint> healthData,
    required DateTime midnight,
    required HealthEntry? todayEntry,
  }) {
    // Anlık metrikler için kaynak bazlı saklama
    final Map<String, (double, DateTime)> hrBySrc = {};
    final Map<String, (double, DateTime)> rhrBySrc = {};
    final Map<String, (double, DateTime)> spo2BySrc = {};
    final Map<String, (double, DateTime)> sysBySrc = {};
    final Map<String, (double, DateTime)> diaBySrc = {};
    
    double totalSleepMin = 0, sleepDeepMin = 0, sleepLightMin = 0, sleepRemMin = 0, sleepAwakeMin = 0;

    // Kümülatif metrikler için kaynak bazlı toplam
    final Map<String, double> stepsBySrc = {};
    final Map<String, double> activeCalBySrc = {};
    final Map<String, double> totalCalBySrc = {};
    final Map<String, double> distanceBySrc = {};

    // ── ADIM: Kaynak bazlı toplam ────
    for (var point in stepsData) {
      final val = _numericValue(point);
      final src = point.sourceName;
      stepsBySrc[src] = (stepsBySrc[src] ?? 0) + val;
    }

    // ── DİĞER METRİKLER ────
    for (var point in healthData) {
      final isSleep = _sleepTypes.contains(point.type);
      final isCumulative = [
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.TOTAL_CALORIES_BURNED,
        HealthDataType.DISTANCE_DELTA,
      ].contains(point.type);

      // Kümülatif veriler (Adım, Kalori, Mesafe) sadece bugün (midnight sonrası) için toplanır.
      // Anlık veriler (Nabız, Tansiyon) ise 36 saatlik penceredeki "en son" değer olarak alınır.
      if (isCumulative && point.dateFrom.isBefore(midnight)) continue;

      final val = isSleep
          ? point.dateTo.difference(point.dateFrom).inMinutes.toDouble()
          : _numericValue(point);
      final src = point.sourceName;
      final time = point.dateFrom;

      switch (point.type) {
        case HealthDataType.STEPS:
          break; // Yukarıda ayrıca işlendi
        case HealthDataType.ACTIVE_ENERGY_BURNED:
          activeCalBySrc[src] = (activeCalBySrc[src] ?? 0) + val;
          break;
        case HealthDataType.TOTAL_CALORIES_BURNED:
          totalCalBySrc[src] = (totalCalBySrc[src] ?? 0) + val;
          break;
        case HealthDataType.DISTANCE_DELTA:
          distanceBySrc[src] = (distanceBySrc[src] ?? 0) + val;
          break;
        case HealthDataType.HEART_RATE:
          if (hrBySrc[src] == null || time.isAfter(hrBySrc[src]!.$2)) {
            hrBySrc[src] = (val, time);
          }
          break;
        case HealthDataType.RESTING_HEART_RATE:
          if (rhrBySrc[src] == null || time.isAfter(rhrBySrc[src]!.$2)) {
            rhrBySrc[src] = (val, time);
          }
          break;
        case HealthDataType.BLOOD_OXYGEN:
          if (spo2BySrc[src] == null || time.isAfter(spo2BySrc[src]!.$2)) {
            spo2BySrc[src] = (val, time);
          }
          break;
        case HealthDataType.BLOOD_PRESSURE_SYSTOLIC:
          if (sysBySrc[src] == null || time.isAfter(sysBySrc[src]!.$2)) {
            sysBySrc[src] = (val, time);
          }
          break;
        case HealthDataType.BLOOD_PRESSURE_DIASTOLIC:
          if (diaBySrc[src] == null || time.isAfter(diaBySrc[src]!.$2)) {
            diaBySrc[src] = (val, time);
          }
          break;
        case HealthDataType.SLEEP_ASLEEP:
          totalSleepMin += val;
          break;
        case HealthDataType.SLEEP_SESSION:
          // Session genelde toplam süreyi kapsar, eğer ASLEEP gelmezse yedek olarak kullanılabilir.
          // Burada sadece en büyük session süresini baz alacağız (genelde bir tane olur).
          if (val > totalSleepMin) totalSleepMin = val;
          break;
        case HealthDataType.SLEEP_DEEP:
          sleepDeepMin += val;
          break;
        case HealthDataType.SLEEP_LIGHT:
          sleepLightMin += val;
          break;
        case HealthDataType.SLEEP_REM:
          sleepRemMin += val;
          break;
        case HealthDataType.SLEEP_AWAKE:
          sleepAwakeMin += val;
          break;
        default:
          break;
      }
    }

    // ── Kaynak kümeleme: Giyilebilir cihaz öncelikli çözümleme ────
    final totalSteps = _resolveSourceValue(stepsBySrc);
    final activeCalories = _resolveSourceValue(activeCalBySrc, useMax: true);
    final totalCalories = _resolveSourceValue(totalCalBySrc, useMax: true);
    final distanceM = _resolveSourceValue(distanceBySrc, useMax: true);

    // Anlık metrikler için giyilebilir öncelikli son değer seçimi
    final latestHeartRate = _resolveLatestValue(hrBySrc);
    final latestRestingHr = _resolveLatestValue(rhrBySrc);
    final latestSpo2 = _resolveLatestValue(spo2BySrc);
    final latestSystolic = _resolveLatestValue(sysBySrc);
    final latestDiastolic = _resolveLatestValue(diaBySrc);

    if (stepsBySrc.isNotEmpty) {
      debugPrint("Adım kaynakları: $stepsBySrc → Seçilen: $totalSteps");
    }

    final sleepHrs = totalSleepMin > 0
        ? totalSleepMin / 60.0
        : (sleepDeepMin + sleepLightMin + sleepRemMin) / 60.0;

    // ── Nabız Seçim Mantığı ──
    double finalHR = latestHeartRate;
    DateTime? finalHRTime = hrBySrc.values.isNotEmpty 
        ? hrBySrc.values.map((v) => v.$2).reduce((a, b) => a.isAfter(b) ? a : b)
        : null;

    if (finalHR <= 0 && todayEntry != null) {
      finalHR = todayEntry.heartRate;
      finalHRTime = todayEntry.heartRateTime;
      debugPrint("ℹ️ [HealthParser] Cihazdan yeni nabız gelmedi, eski veri korunuyor: $finalHR (Zaman: $finalHRTime)");
    } else if (finalHR > 0) {
      debugPrint("✅ [HealthParser] Cihazdan taze nabız alındı: $finalHR (Zaman: $finalHRTime)");
    }

    return ParsedHealthData(
      steps: totalSteps > 0 ? totalSteps : (todayEntry?.steps ?? 0),
      heartRate: finalHR,
      heartRateTime: finalHRTime,
      restingHeartRate: latestRestingHr > 0 ? latestRestingHr : (todayEntry?.restingHeartRate ?? 0),
      spo2: latestSpo2 > 0 ? latestSpo2 : (todayEntry?.spo2 ?? 0),
      stressLevel: todayEntry?.stressLevel ?? 0,
      systolic: latestSystolic > 0 ? latestSystolic : (todayEntry?.systolic ?? 0),
      diastolic: latestDiastolic > 0 ? latestDiastolic : (todayEntry?.diastolic ?? 0),
      sleepHours: sleepHrs > 0 ? sleepHrs : (todayEntry?.sleepHours ?? 0),
      sleepDeepMin: sleepDeepMin,
      sleepLightMin: sleepLightMin,
      sleepRemMin: sleepRemMin,
      sleepAwakeMin: sleepAwakeMin > 0 ? sleepAwakeMin : (todayEntry?.sleepAwakeMin ?? 0),
      activeCalories: activeCalories,
      totalCalories: totalCalories,
      distanceM: distanceM,
    );
  }

  // ── Private helpers ────

  static const _sleepTypes = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_AWAKE,
  ];

  static double _numericValue(HealthDataPoint point) {
    if (point.value is NumericHealthValue) {
      return (point.value as NumericHealthValue).numericValue.toDouble();
    }
    return double.tryParse(point.value.toString()) ?? 0;
  }

  /// Kaynaklar arasından en güncel değeri seçer, giyilebilir cihazlara öncelik verir.
  static double _resolveLatestValue(Map<String, (double, DateTime)> bySource) {
    if (bySource.isEmpty) return 0;

    const wearableKeywords = [
      'xiaomi', 'wearable', 'mi.fitness', 'zepp', 'garmin', 
      'fitbit', 'samsung.health', 'polar', 'suunto', 'huawei', 'watch'
    ];

    // Giyilebilir cihaz kaynaklarını ayıkla
    final wearableEntries = bySource.entries.where((e) {
      final src = e.key.toLowerCase();
      return wearableKeywords.any((k) => src.contains(k));
    }).toList();

    if (wearableEntries.isNotEmpty) {
      // Giyilebilir cihazlar içinden en güncel olanı seç
      wearableEntries.sort((a, b) => b.value.$2.compareTo(a.value.$2));
      return wearableEntries.first.value.$1;
    }

    // Giyilebilir cihaz yoksa tüm kaynaklar içinden en güncelini al
    final allEntries = bySource.entries.toList();
    allEntries.sort((a, b) => b.value.$2.compareTo(a.value.$2));
    return allEntries.first.value.$1;
  }

  /// Kaynak değerleri arasından en güvenilir olanı seçer.
  /// Giyilebilir cihaz kaynaklarına (Xiaomi, Garmin vb.) öncelik verir.
  static double _resolveSourceValue(Map<String, double> bySource, {bool useMax = false}) {
    if (bySource.isEmpty) return 0;

    // Giyilebilir cihaz anahtar kelimeleri
    const wearableKeywords = [
      'xiaomi', 'wearable', 'mi.fitness', 'zepp', 'garmin', 
      'fitbit', 'samsung.health', 'polar', 'suunto', 'huawei', 'watch'
    ];

    final wearableSources = bySource.entries.where((e) {
      final src = e.key.toLowerCase();
      return wearableKeywords.any((k) => src.contains(k));
    }).toList();

    // Eğer giyilebilir cihaz verisi varsa, öncelikle onu kullan
    if (wearableSources.isNotEmpty) {
      if (useMax) {
        return wearableSources.map((e) => e.value).reduce((a, b) => a > b ? a : b);
      } else {
        // Wearable kaynakların medyanını al (birden fazla saat bağlıysa)
        final values = wearableSources.map((e) => e.value).toList()..sort();
        return values[(values.length - 1) ~/ 2];
      }
    }

    // Giyilebilir cihaz yoksa standart medyan/maksimum mantığına dön
    if (useMax) {
      return bySource.values.reduce((a, b) => a > b ? a : b);
    } else {
      final values = bySource.values.toList()..sort();
      return values[(values.length - 1) ~/ 2];
    }
  }
}

/// `HealthDataParser.parse()` sonucu — tüm sensör verileri.
class ParsedHealthData {
  final double steps, heartRate, restingHeartRate, spo2, stressLevel;
  final DateTime? heartRateTime;
  final double systolic, diastolic, sleepHours;
  final double sleepDeepMin, sleepLightMin, sleepRemMin, sleepAwakeMin;
  final double activeCalories, totalCalories, distanceM;

  const ParsedHealthData({
    required this.steps, required this.heartRate, required this.restingHeartRate,
    this.heartRateTime,
    required this.spo2, required this.stressLevel, required this.systolic, required this.diastolic,
    required this.sleepHours, required this.sleepDeepMin, required this.sleepLightMin,
    required this.sleepRemMin, required this.sleepAwakeMin,
    required this.activeCalories, required this.totalCalories,
    required this.distanceM,
  });
}
