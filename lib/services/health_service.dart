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

  // Akıllı Sınırlandırma (Cooldown) için değişkenler
  static DateTime? _lastSyncTime;
  static const Duration _syncCooldown = Duration(minutes: 15);

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
  static Future<bool> syncFromDevice({bool force = false}) async {
    final uid = _uid;
    if (uid == null) return false;

    // Cooldown kontrolü: Eğer zorunlu (force) değilse ve 15 dakika geçmemişse atla
    if (!force && _lastSyncTime != null) {
      final diff = DateTime.now().difference(_lastSyncTime!);
      if (diff < _syncCooldown) {
        debugPrint("Sağlık senkronizasyonu cooldown'da. Kalan süre: ${(_syncCooldown - diff).inMinutes} dk");
        return true; 
      }
    }

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
      HealthDataType.DISTANCE_DELTA,
    ];

    final permissions = types.map((e) => HealthDataAccess.READ).toList();

    try {
      // Health Connect SDK Durum Kontrolü (Android 11-13 için önemli)
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

      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final yesterdayNoon = midnight.subtract(const Duration(hours: 12));
      final endTime = now;

      // ── ADIM VERİSİ: Sadece bugünden çek (dünden sızma olmasın) ────
      List<HealthDataPoint> stepsData = await _healthFactory
          .getHealthDataFromTypes(
            startTime: midnight,    // Kesinlikle bugünün gece yarısından itibaren
            endTime: endTime,
            types: [HealthDataType.STEPS],
          );
      stepsData = Health().removeDuplicates(stepsData);

      // ── DİĞER VERİLER: Uyku için dün öğleden itibaren çekme ────────
      // Uyku verisini (dün geceden başlayan) kaçırmamak için yesterdayNoon kullanıyoruz
      // STEPS hariç diğer tipler — adımı zaten yukarıda ayrıca çektik
      final remainingTypes = [
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
        HealthDataType.DISTANCE_DELTA,
      ];

      List<HealthDataPoint> healthData = await _healthFactory
          .getHealthDataFromTypes(
            startTime: yesterdayNoon,
            endTime: endTime,
            types: remainingTypes,
          );
      healthData = Health().removeDuplicates(healthData);

      debugPrint("[HEALTH DIAGNOSTIC] Toplam Ham Veri Sayısı: ${healthData.length + stepsData.length}");
      for (var p in [...stepsData, ...healthData]) {
        String valText = p.value.toString();
        if (p.value is NumericHealthValue) {
          valText = (p.value as NumericHealthValue).numericValue.toString();
        }
        debugPrint("[HEALTH DIAGNOSTIC] Tür: ${p.typeString} | Değer: $valText | Kaynak: ${p.sourceName} | Tarih: ${p.dateFrom}");
      }

      final todayEntry = await getTodayEntry();

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
      double totalSteps = 0;

      int hrCount = 0;
      int restHrCount = 0;
      int spo2Count = 0;
      int sysCount = 0;
      int diaCount = 0;


      // Kümülatif metrikler için kaynak bazlı en büyük değeri al
      final Map<String, double> stepsBySrc = {};
      final Map<String, double> activeCalBySrc = {};
      final Map<String, double> totalCalBySrc = {};
      final Map<String, double> distanceBySrc = {};

      // ── ADIM: Sadece bugünün verisinden kaynak bazlı toplam ────
      for (var point in stepsData) {
        double val = 0;
        if (point.value is NumericHealthValue) {
          val = (point.value as NumericHealthValue).numericValue.toDouble();
        } else {
          val = double.tryParse(point.value.toString()) ?? 0;
        }
        final src = point.sourceName;
        stepsBySrc[src] = (stepsBySrc[src] ?? 0) + val;
      }

      for (var point in healthData) {
        final isSleep = [
          HealthDataType.SLEEP_ASLEEP,
          HealthDataType.SLEEP_DEEP,
          HealthDataType.SLEEP_LIGHT,
          HealthDataType.SLEEP_REM,
          // HealthDataType.SLEEP_AWAKE, // Eklenebilir, ancak switch'te yok
          // HealthDataType.SLEEP_IN_BED,
        ].contains(point.type);

        // Uyku dışındaki verileri sadece MİDNIGHT sonrasındaysa işle
        if (!isSleep && point.dateFrom.isBefore(midnight)) {
          continue;
        }

        double val = 0;
        if (isSleep) {
          // Uyku için duration (dakika) hesaplanmalı
          val = point.dateTo.difference(point.dateFrom).inMinutes.toDouble();
        } else if (point.value is NumericHealthValue) {
          val = (point.value as NumericHealthValue).numericValue.toDouble();
        } else {
          val = double.tryParse(point.value.toString()) ?? 0;
        }

        final src = point.sourceName;

        switch (point.type) {
          // ADIM: Yukarıda ayrıca sadece bugünden çekildi, burada atla
          case HealthDataType.STEPS:
            break;
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

      // Kümülatif metriklerde aykırı kaynakları eleyen strateji:
      // ADIM → Medyan (aykırı kaynağı doğal olarak eler)
      //   Örn: Xiaomi=39016, GoogleFit=2137, Telefon=1523 → medyan=2137 ✓
      // KALORİ/MESAFE → Max (duplikasyonu önler)
      if (stepsBySrc.isNotEmpty) {
        final sortedSteps = stepsBySrc.values.toList()..sort();
        // Alt medyan: tek kaynak→direkt al, çift→küçük ortayı al, tek→ortayı al
        totalSteps = sortedSteps[(sortedSteps.length - 1) ~/ 2];
        debugPrint("Adım kaynakları: $stepsBySrc → Medyan seçildi: $totalSteps");
      }
      if (activeCalBySrc.isNotEmpty) {
        activeCalories = activeCalBySrc.values.reduce((a, b) => a > b ? a : b);
      }
      if (totalCalBySrc.isNotEmpty) {
        totalCalories = totalCalBySrc.values.reduce((a, b) => a > b ? a : b);
      }
      if (distanceBySrc.isNotEmpty) {
        distanceM = distanceBySrc.values.reduce((a, b) => a > b ? a : b);
      }

      // Ortalamalar
      if (hrCount > 0) avgHeartRate /= hrCount;
      if (restHrCount > 0) avgRestingHr /= restHrCount;
      if (spo2Count > 0) avgSpo2 /= spo2Count;
      if (sysCount > 0) avgSystolic /= sysCount;
      if (diaCount > 0) avgDiastolic /= diaCount;

      double sleepHrs = totalSleepMin > 0
          ? totalSleepMin / 60.0
          : (sleepDeepMin + sleepLightMin + sleepRemMin) / 60.0;

      // Cihazdan 0 gelebilir (henüz güncellenmemiştir, vb.).
      // Bu durumda geçmiş datayı sıfırlamamak için sadece > 0 ise güncelle, değilse mevcut veriyi koru.
      final steps = (totalSteps > 0) ? totalSteps : (todayEntry?.steps ?? 0);
      final heartRate = (avgHeartRate > 0) ? avgHeartRate : (todayEntry?.heartRate ?? 0);
      final restingHeartRate = (avgRestingHr > 0) ? avgRestingHr : (todayEntry?.restingHeartRate ?? 0);
      final spo2 = (avgSpo2 > 0) ? avgSpo2 : (todayEntry?.spo2 ?? 0);
      final systolic = (avgSystolic > 0) ? avgSystolic : (todayEntry?.systolic ?? 0);
      final diastolic = (avgDiastolic > 0) ? avgDiastolic : (todayEntry?.diastolic ?? 0);
      final finalSleepHours = (sleepHrs > 0) ? sleepHrs : (todayEntry?.sleepHours ?? 0);

      final newEntry = HealthEntry(
        date: now,
        weight: todayEntry?.weight ?? 0,
        steps: steps,
        heartRate: heartRate,
        restingHeartRate: restingHeartRate,
        spo2: spo2,
        systolic: systolic,
        diastolic: diastolic,
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
      debugPrint("Toplam Adım (medyan kaynak): $totalSteps");
      debugPrint("Yakılan Kalori (max source): $activeCalories");
      debugPrint("Ortalama Nabız: $avgHeartRate");
      debugPrint("Uyku Dakikası: $totalSleepMin");
      debugPrint("Mesafe: ${distanceM.toStringAsFixed(0)}m");
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

      final stepsPoints = stepsData
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

      // Başarılı senkronizasyon zamanını kaydet
      _lastSyncTime = DateTime.now();

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
