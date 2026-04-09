import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import '../models/health_entry.dart';
import '../services/api_service.dart';

// Re-export so existing `import 'health_service.dart'` importers still see HealthEntry.
export '../models/health_entry.dart';

/// Firestore sağlık verisi okuma / yazma servisi (M1 — Veri Toplama Katmanı).
/// Redmi Watch 4 → Mi Fitness → Health Connect → Bu Servis → Firestore + Backend
class HealthService {
  static final _db = FirebaseFirestore.instance;
  static final Health _healthFactory = Health();

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static String _dateKey(DateTime date) =>
      "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  // ── Bugünün verisini kaydet ───────────────────────────────────
  static Future<void> saveHealthEntry(HealthEntry entry) async {
    final uid = _uid;
    if (uid == null) return;

    final dateKey = _dateKey(entry.date);
    await _db
        .collection('users')
        .doc(uid)
        .collection('health_entries')
        .doc(dateKey)
        .set(entry.toJson(), SetOptions(merge: true));

    // Backend (PostgreSQL) Senkronizasyonu
    try {
      await ApiService.syncHealthToBackend(entry);
    } catch (e) {
      debugPrint("Backend sync hatası: $e");
    }
  }

  // ── Sensörlerden (Health Connect) Otomatik Veri Çekme ─────────
  static Future<bool> syncFromDevice() async {
    final uid = _uid;
    if (uid == null) return false;

    final types = [
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.TOTAL_CALORIES_BURNED,
      HealthDataType.HEART_RATE,
      HealthDataType.RESTING_HEART_RATE,
      HealthDataType.BLOOD_OXYGEN,
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_REM,
    ];

    final permissions = types.map((e) => HealthDataAccess.READ).toList();

    try {
      // Health Connect SDK Durum Kontrolü (Android 11-13 için önemli)
      // Not: sdkAvailable kontrolü ana kontrolümüz.
      final sdkStatus = await Health().getHealthConnectSdkStatus();
      if (sdkStatus != HealthConnectSdkStatus.sdkAvailable) {
        debugPrint("Health Connect SDK uygun değil: $sdkStatus");
        return false;
      }

      bool authorized = await _healthFactory.requestAuthorization(
        types,
        permissions: permissions,
      );
      if (!authorized) {
        debugPrint("Health Connect izini reddedildi.");
        return false;
      }

      // Artık sadece 'Bugün' (00:00'dan bugüne) olan verileri çekiyoruz.
      final now = DateTime.now();
      final startTime = DateTime(now.year, now.month, now.day);
      final endTime = now;

      List<HealthDataPoint> healthData = await _healthFactory
          .getHealthDataFromTypes(
            startTime: startTime,
            endTime: endTime,
            types: types,
          );

      healthData = Health().removeDuplicates(healthData);

      final todayEntry = await getTodayEntry();

      double totalSteps = 0;
      double avgHeartRate = 0;
      double avgRestingHr = 0;
      double avgSpo2 = 0;
      double avgSystolic = 0;
      double avgDiastolic = 0;
      double totalSleepMin = 0;
      double sleepDeepMin = 0;
      double sleepLightMin = 0;
      double sleepRemMin = 0;
      double activeCalories = 0;
      double totalCalories = 0;
      double distanceM = 0;

      int hrCount = 0;
      int restHrCount = 0;
      int spo2Count = 0;
      int sysCount = 0;
      int diaCount = 0;

      for (var point in healthData) {
        // 'health' ^13.3.1 paketinde değerler NumericHealthValue veya benzeri objeler olarak döner.
        double val = 0;
        if (point.value is NumericHealthValue) {
          val = (point.value as NumericHealthValue).numericValue.toDouble();
        } else {
          val = double.tryParse(point.value.toString()) ?? 0;
        }

        switch (point.type) {
          case HealthDataType.STEPS:
            totalSteps += val;
            break;
          case HealthDataType.ACTIVE_ENERGY_BURNED:
            activeCalories += val;
            break;
          case HealthDataType.TOTAL_CALORIES_BURNED:
            totalCalories += val;
            break;
          case HealthDataType.DISTANCE_WALKING_RUNNING:
            distanceM += val;
            break;
          case HealthDataType.HEART_RATE:
            avgHeartRate += val;
            hrCount++;
            break;
          case HealthDataType.RESTING_HEART_RATE:
            avgRestingHr += val;
            restHrCount++;
            break;
          case HealthDataType.BLOOD_OXYGEN:
            avgSpo2 += val;
            spo2Count++;
            break;
          case HealthDataType.BLOOD_PRESSURE_SYSTOLIC:
            avgSystolic += val;
            sysCount++;
            break;
          case HealthDataType.BLOOD_PRESSURE_DIASTOLIC:
            avgDiastolic += val;
            diaCount++;
            break;
          case HealthDataType.SLEEP_ASLEEP:
            totalSleepMin += val;
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
          default:
            break;
        }
      }

      if (hrCount > 0) avgHeartRate /= hrCount;
      if (restHrCount > 0) avgRestingHr /= restHrCount;
      if (spo2Count > 0) avgSpo2 /= spo2Count;
      if (sysCount > 0) avgSystolic /= sysCount;
      if (diaCount > 0) avgDiastolic /= diaCount;

      double sleepHrs = totalSleepMin > 0
          ? totalSleepMin / 60.0
          : (sleepDeepMin + sleepLightMin + sleepRemMin) / 60.0;

      // Cihaz verileri (steps, heartRate, sleepHours) manuel verilerden (manualSteps vb) üstündür.
      // KRİTİK: Eğer saat gece yarısı (00:00 - 02:00) ise ve cihazdan 0 veri geliyorsa, 
      // manuel veriyi SILME (çünkü kullanıcı daha yürümeye başlamamış ama bugün manuel veri girmiş olabilir).
      final isEarlyMorning = DateTime.now().hour < 2;
      
      final steps = (totalSteps > 0 || !isEarlyMorning) ? totalSteps : (todayEntry?.steps ?? 0);
      final heartRate = (avgHeartRate > 0 || !isEarlyMorning) ? avgHeartRate : (todayEntry?.heartRate ?? 0);
      final finalSleepHours = (sleepHrs > 0 || !isEarlyMorning) ? sleepHrs : (todayEntry?.sleepHours ?? 0);

      final newEntry = HealthEntry(
        date: now,
        weight: todayEntry?.weight ?? 0,
        steps: steps,
        heartRate: heartRate,
        restingHeartRate: avgRestingHr,
        spo2: avgSpo2,
        systolic: avgSystolic,
        diastolic: avgDiastolic,
        sleepHours: finalSleepHours,
        sleepDeepMin: sleepDeepMin,
        sleepLightMin: sleepLightMin,
        sleepRemMin: sleepRemMin,
        sleepAwakeMin: todayEntry?.sleepAwakeMin ?? 0,
        activeCalories: activeCalories,
        totalCalories: totalCalories,
        distanceM: distanceM,
        stressLevel: todayEntry?.stressLevel ?? 0,
        waterMl: todayEntry?.waterMl ?? 0, // Önceki manuel girişi koru
        mood: todayEntry?.mood ?? 'neutral', // Önceki manuel girişi koru
        source: 'health_connect',
      );

      await saveHealthEntry(newEntry);
      
      debugPrint("--- SAĞLIK SENKRONİZASYONU ÖZETİ ---");
      debugPrint("İşlenen Veri Noktası: ${healthData.length}");
      debugPrint("Toplam Adım: $totalSteps");
      debugPrint("Yakılan Kalori: $activeCalories");
      debugPrint("Ortalama Nabız: $avgHeartRate");
      debugPrint("Uyku Dakikası: $totalSleepMin");
      debugPrint("-----------------------------------");
      
      // ── Tez Modül 2: Ham Verileri Pipeline'a Gönder ──────────────
      final hrPoints = healthData
          .where((p) => p.type == HealthDataType.HEART_RATE)
          .map((p) => {
                'timestamp': p.dateFrom.toIso8601String(),
                'value': (p.value is NumericHealthValue)
                    ? (p.value as NumericHealthValue).numericValue.toDouble()
                    : (double.tryParse(p.value.toString()) ?? 0),
              })
          .toList();

      final stepsPoints = healthData
          .where((p) => p.type == HealthDataType.STEPS)
          .map((p) => {
                'timestamp': p.dateFrom.toIso8601String(),
                'value': (p.value is NumericHealthValue)
                    ? (p.value as NumericHealthValue).numericValue.toDouble()
                    : (double.tryParse(p.value.toString()) ?? 0),
              })
          .toList();

      if (hrPoints.isNotEmpty || stepsPoints.isNotEmpty) {
        ApiService.preprocessRawData(
          heartRateData: hrPoints,
          stepsData: stepsPoints,
        ).then((success) {
          if (success) debugPrint("Pipeline Veri İşleme Başarılı.");
        });
      }

      return true;
    } catch (e) {
      debugPrint("Sağlık verisi eşitleme hatası: $e");
      return false;
    }
  }

  // ── Bugünün verisini oku ──────────────────────────────────────
  static Future<HealthEntry?> getTodayEntry() async {
    final uid = _uid;
    if (uid == null) return null;

    final dateKey = _dateKey(DateTime.now());
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('health_entries')
        .doc(dateKey)
        .get();

    if (!doc.exists || doc.data() == null) return null;
    return HealthEntry.fromJson(doc.data()!);
  }

  // ── Son N günün verilerini oku ────────────────────────────────
  static Future<List<HealthEntry>> getLastNDays(int n) async {
    final uid = _uid;
    if (uid == null) return [];

    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('health_entries')
        .orderBy('date', descending: true)
        .limit(n)
        .get();

    return snapshot.docs.map((d) => HealthEntry.fromJson(d.data())).toList();
  }

  // ── Su Verisini Güncelle ─────────────────────────────────────
  static Future<void> updateWater(double ml) async {
    final today = await getTodayEntry();
    final entry = today ?? HealthEntry(date: DateTime.now());
    final updated = entry.copyWith(
      waterMl: entry.waterMl + ml,
    );
    await saveHealthEntry(updated);
  }

  // ── Mod Verisini Güncelle ───────────────────────────────────
  static Future<void> updateMood(String mood) async {
    final today = await getTodayEntry();
    final entry = today ?? HealthEntry(date: DateTime.now());
    final updated = entry.copyWith(mood: mood);
    await saveHealthEntry(updated);
  }

  // ── Su Hedefi Hesapla (Kilo * 35ml) ──────────────────────────
  static double calculateWaterTarget(double weight) {
    if (weight <= 0) return 2000; // Varsayılan hedef
    return (weight * 35).roundToDouble();
  }
}
