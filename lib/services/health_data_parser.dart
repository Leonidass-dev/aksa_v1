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
    double latestHeartRate = 0, latestRestingHr = 0, latestSpo2 = 0, latestHrv = 0;
    double latestSystolic = 0, latestDiastolic = 0;
    DateTime? hrTime, rhrTime, spo2Time, sysTime, diaTime, hrvTime;
    
    double totalSleepMin = 0, sleepDeepMin = 0, sleepLightMin = 0, sleepRemMin = 0;

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

      // Uyku dışı verileri sadece midnight sonrasında işle
      if (!isSleep && point.dateFrom.isBefore(midnight)) continue;

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
        case HealthDataType.TOTAL_CALORIES_BURNED:
          totalCalBySrc[src] = (totalCalBySrc[src] ?? 0) + val;
        case HealthDataType.DISTANCE_DELTA:
          distanceBySrc[src] = (distanceBySrc[src] ?? 0) + val;
        case HealthDataType.HEART_RATE:
          if (hrTime == null || time.isAfter(hrTime)) {
            latestHeartRate = val; hrTime = time;
          }
        case HealthDataType.RESTING_HEART_RATE:
          if (rhrTime == null || time.isAfter(rhrTime)) {
            latestRestingHr = val; rhrTime = time;
          }
        case HealthDataType.BLOOD_OXYGEN:
          if (spo2Time == null || time.isAfter(spo2Time)) {
            latestSpo2 = val; spo2Time = time;
          }
        case HealthDataType.BLOOD_PRESSURE_SYSTOLIC:
          if (sysTime == null || time.isAfter(sysTime)) {
            latestSystolic = val; sysTime = time;
          }
        case HealthDataType.BLOOD_PRESSURE_DIASTOLIC:
          if (diaTime == null || time.isAfter(diaTime)) {
            latestDiastolic = val; diaTime = time;
          }
        case HealthDataType.HEART_RATE_VARIABILITY_SDNN:
          if (hrvTime == null || time.isAfter(hrvTime)) {
            latestHrv = val; hrvTime = time;
          }
        case HealthDataType.SLEEP_ASLEEP:
          totalSleepMin += val;
        case HealthDataType.SLEEP_DEEP:
          sleepDeepMin += val;
        case HealthDataType.SLEEP_LIGHT:
          sleepLightMin += val;
        case HealthDataType.SLEEP_REM:
          sleepRemMin += val;
        default:
          break;
      }
    }

    // ── Kaynak kümeleme: Giyilebilir cihaz öncelikli çözümleme ────
    final totalSteps = _resolveSourceValue(stepsBySrc);
    final activeCalories = _resolveSourceValue(activeCalBySrc, useMax: true);
    final totalCalories = _resolveSourceValue(totalCalBySrc, useMax: true);
    final distanceM = _resolveSourceValue(distanceBySrc, useMax: true);

    if (stepsBySrc.isNotEmpty) {
      debugPrint("Adım kaynakları: $stepsBySrc → Seçilen: $totalSteps");
    }

    final sleepHrs = totalSleepMin > 0
        ? totalSleepMin / 60.0
        : (sleepDeepMin + sleepLightMin + sleepRemMin) / 60.0;

    // ── Sıfır koruma: Cihazdan 0 gelirse mevcut veriyi koru ────
    return ParsedHealthData(
      steps: totalSteps > 0 ? totalSteps : (todayEntry?.steps ?? 0),
      heartRate: latestHeartRate > 0 ? latestHeartRate : (todayEntry?.heartRate ?? 0),
      restingHeartRate: latestRestingHr > 0 ? latestRestingHr : (todayEntry?.restingHeartRate ?? 0),
      spo2: latestSpo2 > 0 ? latestSpo2 : (todayEntry?.spo2 ?? 0),
      hrv: latestHrv > 0 ? latestHrv : (todayEntry?.stressLevel ?? 0),
      systolic: latestSystolic > 0 ? latestSystolic : (todayEntry?.systolic ?? 0),
      diastolic: latestDiastolic > 0 ? latestDiastolic : (todayEntry?.diastolic ?? 0),
      sleepHours: sleepHrs > 0 ? sleepHrs : (todayEntry?.sleepHours ?? 0),
      sleepDeepMin: sleepDeepMin,
      sleepLightMin: sleepLightMin,
      sleepRemMin: sleepRemMin,
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
  ];

  static double _numericValue(HealthDataPoint point) {
    if (point.value is NumericHealthValue) {
      return (point.value as NumericHealthValue).numericValue.toDouble();
    }
    return double.tryParse(point.value.toString()) ?? 0;
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
  final double steps, heartRate, restingHeartRate, spo2, hrv;
  final double systolic, diastolic, sleepHours;
  final double sleepDeepMin, sleepLightMin, sleepRemMin;
  final double activeCalories, totalCalories, distanceM;

  const ParsedHealthData({
    required this.steps, required this.heartRate, required this.restingHeartRate,
    required this.spo2, required this.hrv, required this.systolic, required this.diastolic,
    required this.sleepHours, required this.sleepDeepMin, required this.sleepLightMin,
    required this.sleepRemMin, required this.activeCalories, required this.totalCalories,
    required this.distanceM,
  });
}
