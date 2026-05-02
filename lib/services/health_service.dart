import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import '../models/health_entry.dart';
import '../services/api_service.dart';
import '../services/health_data_parser.dart';

import 'interfaces/i_health_service.dart';

// Re-export so existing `import 'health_service.dart'` importers still see HealthEntry.
export '../models/health_entry.dart';

/// Firestore sağlık verisi okuma / yazma servisi (M1 — Veri Toplama Katmanı).
/// Redmi Watch 4 → Mi Fitness → Health Connect → Bu Servis → Firestore + Backend
class HealthServiceImpl implements IHealthService {
  final _db = FirebaseFirestore.instance;
  final Health _healthFactory = Health();

  // Akıllı Sınırlandırma (Cooldown) için değişkenler
  DateTime? _lastSyncTime;
  final Duration _syncCooldown = const Duration(minutes: 1);

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  String _dateKey(DateTime date) =>

      "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  // ── Bugünün verisini kaydet ───────────────────────────────────
  @override
  Future<void> saveHealthEntry(HealthEntry entry) async {
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
  @override
  Future<bool> syncFromDevice({bool force = false}) async {
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
          ).timeout(const Duration(seconds: 10));
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
        HealthDataType.SLEEP_REM,
        HealthDataType.DISTANCE_DELTA,
      ];

      List<HealthDataPoint> healthData = await _healthFactory
          .getHealthDataFromTypes(
            startTime: yesterdayNoon,
            endTime: endTime,
            types: remainingTypes,
          ).timeout(const Duration(seconds: 10));
      healthData = Health().removeDuplicates(healthData);

      debugPrint("\n🚀 [AKSA HEALTH] SENKRONİZASYON BAŞLADI");
      debugPrint("📊 Toplam Ham Veri: ${healthData.length + stepsData.length} nokta");
      
      for (var p in [...stepsData, ...healthData]) {
        String valText = p.value.toString();
        if (p.value is NumericHealthValue) {
          valText = (p.value as NumericHealthValue).numericValue.toStringAsFixed(1);
        }
        
        String emoji = "🔹";
        if (p.typeString.contains("STEPS")) emoji = "👣";
        else if (p.typeString.contains("HEART")) emoji = "❤️";
        else if (p.typeString.contains("OXYGEN")) emoji = "🩸";
        else if (p.typeString.contains("ENERGY")) emoji = "🔥";
        else if (p.typeString.contains("SLEEP")) emoji = "🌙";
        else if (p.typeString.contains("PRESSURE")) emoji = "⚖️";

        String source = p.sourceName;
        if (source.contains("xiaomi")) source = "⌚ XIAOMI";
        else if (source.contains("fitness")) source = "📱 G-FIT";
        else if (source.contains("android")) source = "🤖 SYSTEM";

        debugPrint("$emoji [${p.typeString.padRight(15)}] | Değer: ${valText.padRight(6)} | Kaynak: $source");
      }

      final todayEntry = await getTodayEntry();

      final parsedData = HealthDataParser.parse(
        stepsData: stepsData,
        healthData: healthData,
        midnight: midnight,
        todayEntry: todayEntry,
      );

      final newEntry = HealthEntry(
        date: now,
        weight: todayEntry?.weight ?? 0,
        steps: parsedData.steps,
        heartRate: parsedData.heartRate,
        restingHeartRate: parsedData.restingHeartRate,
        spo2: parsedData.spo2,
        stressLevel: todayEntry?.stressLevel ?? 0,
        systolic: parsedData.systolic,
        diastolic: parsedData.diastolic,
        sleepHours: parsedData.sleepHours,
        sleepDeepMin: parsedData.sleepDeepMin,
        sleepLightMin: parsedData.sleepLightMin,
        sleepRemMin: parsedData.sleepRemMin,
        sleepAwakeMin: todayEntry?.sleepAwakeMin ?? 0,
        activeCalories: parsedData.activeCalories,
        totalCalories: parsedData.totalCalories,
        distanceM: parsedData.distanceM,
        waterMl: todayEntry?.waterMl ?? 0,
        mood: todayEntry?.mood ?? 'neutral',
        source: 'health_connect',
      );

      await saveHealthEntry(newEntry);
      
      debugPrint("\n╔════════ SAĞLIK ÖZETİ ════════╗");
      debugPrint("║ 👣 Adım    : ${parsedData.steps.toInt().toString().padRight(16)} ║");
      debugPrint("║ ❤️ Nabız   : ${parsedData.heartRate.toInt().toString().padRight(16)} ║");
      debugPrint("║ 🩸 Oksijen : %${parsedData.spo2.toInt().toString().padRight(15)} ║");
      debugPrint("║ 🔥 Kalori  : ${parsedData.activeCalories.toInt().toString().padRight(16)} ║");
      debugPrint("║ 📏 Mesafe  : ${parsedData.distanceM.toInt().toString()}m".padRight(31) + "║");
      debugPrint("╚══════════════════════════════╝\n");
      
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
        final success = await ApiService.preprocessRawData(
          heartRateData: hrPoints,
          stepsData: stepsPoints,
        );
        if (success) debugPrint("Pipeline Veri İşleme Başarılı.");
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
  @override
  Future<HealthEntry?> getTodayEntry() async {
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
  @override
  Future<List<HealthEntry>> getLastNDays(int n) async {
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
  @override
  Future<void> updateWater(double ml) async {
    final today = await getTodayEntry();
    final entry = today ?? HealthEntry(date: DateTime.now());
    final updated = entry.copyWith(
      waterMl: entry.waterMl + ml,
    );
    await saveHealthEntry(updated);
  }

  // ── Mod Verisini Güncelle ───────────────────────────────────
  @override
  Future<void> updateMood(String mood) async {
    final today = await getTodayEntry();
    final entry = today ?? HealthEntry(date: DateTime.now());
    final updated = entry.copyWith(mood: mood);
    await saveHealthEntry(updated);
  }

  // ── Su Hedefi Hesapla (Kilo * 35ml) ──────────────────────────
  @override
  double calculateWaterTarget(double weight, double activeCalories) {
    if (weight <= 0) return 2000; // Varsayılan hedef
    double base = (weight * 35);
    // Yakılan her 100 aktif kalori için +100ml su ekle (Dinamik hedef)
    double extra = (activeCalories / 100) * 100;
    return (base + extra).roundToDouble();
  }
}

/// Test edilebilir Statik Facade yapısı.
class HealthService {
  static IHealthService _instance = HealthServiceImpl();

  @visibleForTesting
  static set instance(IHealthService mock) => _instance = mock;

  static Future<void> saveHealthEntry(HealthEntry entry) => _instance.saveHealthEntry(entry);
  static Future<bool> syncFromDevice({bool force = false}) => _instance.syncFromDevice(force: force);
  static Future<HealthEntry?> getTodayEntry() => _instance.getTodayEntry();
  static Future<List<HealthEntry>> getLastNDays(int n) => _instance.getLastNDays(n);
  static Future<void> updateWater(double ml) => _instance.updateWater(ml);
  static Future<void> updateMood(String mood) => _instance.updateMood(mood);
  static double calculateWaterTarget(double weight, double activeCalories) => _instance.calculateWaterTarget(weight, activeCalories);
}
