import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:health/health.dart';

/// Firestore sağlık verisi okuma / yazma servisi (M1 — Veri Toplama Katmanı).
/// Redmi Watch 4 → Mi Fitness → Health Connect → Bu Servis → Firestore + Backend
class HealthService {
  static final _db = FirebaseFirestore.instance;
  static final Health _healthFactory = Health();

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

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
  }

  // ── Sensörlerden (Health Connect) Otomatik Veri Çekme ─────────
  // Redmi Watch 4'ün tüm sensör verilerini Mi Fitness → Health Connect
  // üzerinden çeker.
  static Future<bool> syncFromDevice() async {
    final uid = _uid;
    if (uid == null) return false;

    // Redmi Watch 4'ün Health Connect üzerinden paylaştığı tüm veri tipleri
    final types = [
      // ── Aktivite ──────────────────────────────────────────────
      HealthDataType.STEPS,                      // Günlük adım
      HealthDataType.ACTIVE_ENERGY_BURNED,       // Aktif yakılan kalori
      HealthDataType.TOTAL_CALORIES_BURNED,      // Toplam kalori
      HealthDataType.DISTANCE_WALKING_RUNNING,   // Yürüme/koşma mesafesi

      // ── Kardiyovasküler (PPG 4-kanal sensör) ──────────────────
      HealthDataType.HEART_RATE,                 // Ortalama nabız
      HealthDataType.RESTING_HEART_RATE,         // Dinlenik nabız

      // ── SpO2 ──────────────────────────────────────────────────
      HealthDataType.BLOOD_OXYGEN,               // Kan oksijen saturasyonu

      // ── Tansiyon ──────────────────────────────────────────────
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC,    // Sistolik
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC,   // Diastolik

      // ── Uyku (detaylı) ────────────────────────────────────────
      HealthDataType.SLEEP_ASLEEP,               // Toplam uyku süresi
      HealthDataType.SLEEP_DEEP,                 // Derin uyku
      HealthDataType.SLEEP_LIGHT,                // Hafif uyku
      HealthDataType.SLEEP_REM,                  // REM uyku
    ];

    final permissions = types.map((e) => HealthDataAccess.READ).toList();

    try {
      // 1. İzin iste
      bool authorized = await _healthFactory.requestAuthorization(types, permissions: permissions);
      if (!authorized) return false;

      // 2. Son 24 saat için sorgu yap
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      // Verileri çek
      List<HealthDataPoint> healthData = await _healthFactory.getHealthDataFromTypes(
        startTime: yesterday,
        endTime: now,
        types: types,
      );

      healthData = Health().removeDuplicates(healthData);

      // Varsa önceki günün verisini al ki üzerine yazmayalım
      final todayEntry = await getTodayEntry();

      // ── Veri toplama değişkenleri ────────────────────────────
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
        final val = double.tryParse(point.value.toString()) ?? 0;

        switch (point.type) {
          // Aktivite
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

          // Kardiyovasküler
          case HealthDataType.HEART_RATE:
            avgHeartRate += val;
            hrCount++;
            break;
          case HealthDataType.RESTING_HEART_RATE:
            avgRestingHr += val;
            restHrCount++;
            break;

          // SpO2
          case HealthDataType.BLOOD_OXYGEN:
            avgSpo2 += val;
            spo2Count++;
            break;

          // Tansiyon
          case HealthDataType.BLOOD_PRESSURE_SYSTOLIC:
            avgSystolic += val;
            sysCount++;
            break;
          case HealthDataType.BLOOD_PRESSURE_DIASTOLIC:
            avgDiastolic += val;
            diaCount++;
            break;

          // Uyku
          case HealthDataType.SLEEP_ASLEEP:
            totalSleepMin += val; // genelde dakika gelir
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

      // Ortalama hesapla
      if (hrCount > 0) avgHeartRate /= hrCount;
      if (restHrCount > 0) avgRestingHr /= restHrCount;
      if (spo2Count > 0) avgSpo2 /= spo2Count;
      if (sysCount > 0) avgSystolic /= sysCount;
      if (diaCount > 0) avgDiastolic /= diaCount;

      // Toplam uyku saati hesapla
      double sleepHours = totalSleepMin > 0
          ? totalSleepMin / 60.0
          : (sleepDeepMin + sleepLightMin + sleepRemMin) / 60.0;

      // Yeni entry oluştur (sensör verisi yoksa eskisi kalsın)
      final newEntry = HealthEntry(
        date: now,
        weight: todayEntry?.weight ?? 0,
        steps: totalSteps > 0 ? totalSteps : (todayEntry?.steps ?? 0),
        heartRate: avgHeartRate > 0 ? avgHeartRate : (todayEntry?.heartRate ?? 0),
        restingHeartRate: avgRestingHr > 0 ? avgRestingHr : (todayEntry?.restingHeartRate ?? 0),
        spo2: avgSpo2 > 0 ? avgSpo2 : (todayEntry?.spo2 ?? 0),
        systolic: avgSystolic > 0 ? avgSystolic : (todayEntry?.systolic ?? 0),
        diastolic: avgDiastolic > 0 ? avgDiastolic : (todayEntry?.diastolic ?? 0),
        sleepHours: sleepHours > 0 ? sleepHours : (todayEntry?.sleepHours ?? 0),
        sleepDeepMin: sleepDeepMin > 0 ? sleepDeepMin : (todayEntry?.sleepDeepMin ?? 0),
        sleepLightMin: sleepLightMin > 0 ? sleepLightMin : (todayEntry?.sleepLightMin ?? 0),
        sleepRemMin: sleepRemMin > 0 ? sleepRemMin : (todayEntry?.sleepRemMin ?? 0),
        sleepAwakeMin: todayEntry?.sleepAwakeMin ?? 0,
        activeCalories: activeCalories > 0 ? activeCalories : (todayEntry?.activeCalories ?? 0),
        totalCalories: totalCalories > 0 ? totalCalories : (todayEntry?.totalCalories ?? 0),
        distanceM: distanceM > 0 ? distanceM : (todayEntry?.distanceM ?? 0),
        stressLevel: todayEntry?.stressLevel ?? 0, // Health Connect'ten stres verisi gelmez, manuel girilir
        source: 'health_connect',
      );

      // 3. Bulunan sensör verisini Firestore'a bas
      await saveHealthEntry(newEntry);
      return true;

    } catch (e) {
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

    return snapshot.docs
        .map((d) => HealthEntry.fromJson(d.data()))
        .toList();
  }

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

// ── Veri Modeli — Redmi Watch 4 tüm sensör alanları ───────────────

class HealthEntry {
  final DateTime date;

  // Aktivite
  final double steps;           // Günlük adım
  final double activeCalories;  // Aktif yakılan kalori (kcal)
  final double totalCalories;   // Toplam yakılan kalori (kcal)
  final double distanceM;       // Yürüme/koşma mesafesi (metre)

  // Kardiyovasküler
  final double heartRate;       // Ortalama nabız (bpm)
  final double restingHeartRate;// Dinlenik nabız (bpm)
  final double spo2;            // Kan oksijeni (%)

  // Tansiyon
  final double systolic;        // Sistolik (mmHg)
  final double diastolic;       // Diastolik (mmHg)

  // Uyku (detaylı)
  final double sleepHours;      // Toplam uyku (saat)
  final double sleepDeepMin;    // Derin uyku (dk)
  final double sleepLightMin;   // Hafif uyku (dk)
  final double sleepRemMin;     // REM uyku (dk)
  final double sleepAwakeMin;   // Uyanıklık (dk)

  // Stres & Vücut
  final double stressLevel;     // Stres seviyesi (0-100)
  final double weight;          // Kilo (kg)

  // Meta
  final String source;          // "manual" | "health_connect"

  const HealthEntry({
    required this.date,
    this.steps = 0,
    this.activeCalories = 0,
    this.totalCalories = 0,
    this.distanceM = 0,
    this.heartRate = 0,
    this.restingHeartRate = 0,
    this.spo2 = 0,
    this.systolic = 0,
    this.diastolic = 0,
    this.sleepHours = 0,
    this.sleepDeepMin = 0,
    this.sleepLightMin = 0,
    this.sleepRemMin = 0,
    this.sleepAwakeMin = 0,
    this.stressLevel = 0,
    this.weight = 0,
    this.source = 'manual',
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        // Aktivite
        'steps': steps,
        'active_calories': activeCalories,
        'total_calories': totalCalories,
        'distance_m': distanceM,
        // Kardiyovasküler
        'heart_rate': heartRate,
        'resting_heart_rate': restingHeartRate,
        'spo2': spo2,
        // Tansiyon
        'systolic': systolic,
        'diastolic': diastolic,
        // Uyku
        'sleep_hours': sleepHours,
        'sleep_deep_min': sleepDeepMin,
        'sleep_light_min': sleepLightMin,
        'sleep_rem_min': sleepRemMin,
        'sleep_awake_min': sleepAwakeMin,
        // Stres & Vücut
        'stress_level': stressLevel,
        'weight': weight,
        // Meta
        'source': source,
        'updated_at': FieldValue.serverTimestamp(),
      };

  factory HealthEntry.fromJson(Map<String, dynamic> json) => HealthEntry(
        date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
        // Aktivite
        steps: (json['steps'] ?? 0).toDouble(),
        activeCalories: (json['active_calories'] ?? 0).toDouble(),
        totalCalories: (json['total_calories'] ?? 0).toDouble(),
        distanceM: (json['distance_m'] ?? 0).toDouble(),
        // Kardiyovasküler
        heartRate: (json['heart_rate'] ?? 0).toDouble(),
        restingHeartRate: (json['resting_heart_rate'] ?? 0).toDouble(),
        spo2: (json['spo2'] ?? 0).toDouble(),
        // Tansiyon
        systolic: (json['systolic'] ?? 0).toDouble(),
        diastolic: (json['diastolic'] ?? 0).toDouble(),
        // Uyku
        sleepHours: (json['sleep_hours'] ?? 0).toDouble(),
        sleepDeepMin: (json['sleep_deep_min'] ?? 0).toDouble(),
        sleepLightMin: (json['sleep_light_min'] ?? 0).toDouble(),
        sleepRemMin: (json['sleep_rem_min'] ?? 0).toDouble(),
        sleepAwakeMin: (json['sleep_awake_min'] ?? 0).toDouble(),
        // Stres & Vücut
        stressLevel: (json['stress_level'] ?? 0).toDouble(),
        weight: (json['weight'] ?? 0).toDouble(),
        // Meta
        source: json['source'] ?? 'manual',
      );
}
