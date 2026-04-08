import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:health/health.dart';
import '../models/health_entry.dart';

// Re-export so existing `import 'health_service.dart'` importers still see HealthEntry.
export '../models/health_entry.dart';

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
  static Future<bool> syncFromDevice() async {
    final uid = _uid;
    if (uid == null) return false;

    final types = [
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.TOTAL_CALORIES_BURNED,
      HealthDataType.DISTANCE_WALKING_RUNNING,
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
      bool authorized = await _healthFactory.requestAuthorization(
        types,
        permissions: permissions,
      );
      if (!authorized) return false;

      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      List<HealthDataPoint> healthData = await _healthFactory
          .getHealthDataFromTypes(
            startTime: yesterday,
            endTime: now,
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
        final val = double.tryParse(point.value.toString()) ?? 0;

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

      double sleepHours = totalSleepMin > 0
          ? totalSleepMin / 60.0
          : (sleepDeepMin + sleepLightMin + sleepRemMin) / 60.0;

      final newEntry = HealthEntry(
        date: now,
        weight: todayEntry?.weight ?? 0,
        steps: totalSteps > 0 ? totalSteps : (todayEntry?.steps ?? 0),
        heartRate: avgHeartRate > 0
            ? avgHeartRate
            : (todayEntry?.heartRate ?? 0),
        restingHeartRate: avgRestingHr > 0
            ? avgRestingHr
            : (todayEntry?.restingHeartRate ?? 0),
        spo2: avgSpo2 > 0 ? avgSpo2 : (todayEntry?.spo2 ?? 0),
        systolic: avgSystolic > 0 ? avgSystolic : (todayEntry?.systolic ?? 0),
        diastolic: avgDiastolic > 0
            ? avgDiastolic
            : (todayEntry?.diastolic ?? 0),
        sleepHours: sleepHours > 0 ? sleepHours : (todayEntry?.sleepHours ?? 0),
        sleepDeepMin: sleepDeepMin > 0
            ? sleepDeepMin
            : (todayEntry?.sleepDeepMin ?? 0),
        sleepLightMin: sleepLightMin > 0
            ? sleepLightMin
            : (todayEntry?.sleepLightMin ?? 0),
        sleepRemMin: sleepRemMin > 0
            ? sleepRemMin
            : (todayEntry?.sleepRemMin ?? 0),
        sleepAwakeMin: todayEntry?.sleepAwakeMin ?? 0,
        activeCalories: activeCalories > 0
            ? activeCalories
            : (todayEntry?.activeCalories ?? 0),
        totalCalories: totalCalories > 0
            ? totalCalories
            : (todayEntry?.totalCalories ?? 0),
        distanceM: distanceM > 0 ? distanceM : (todayEntry?.distanceM ?? 0),
        stressLevel: todayEntry?.stressLevel ?? 0,
        source: 'health_connect',
      );

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

    return snapshot.docs.map((d) => HealthEntry.fromJson(d.data())).toList();
  }

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
