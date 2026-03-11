import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:health/health.dart';

/// Firestore sağlık verisi okuma / yazma servisi (M1 — Veri Toplama Katmanı).
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

  // ── Sensörlerden (Health Connect) Otomatik Veri Çekme (M1) ───
  static Future<bool> syncFromDevice() async {
    final uid = _uid;
    if (uid == null) return false;

    // İsteyeceğimiz veri tipleri
    final types = [
      HealthDataType.STEPS,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.HEART_RATE,
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
      HealthDataType.BLOOD_OXYGEN,
    ];

    final permissions = types.map((e) => HealthDataAccess.READ).toList();

    try {
      // 1. İzin iste
      bool authorized = await _healthFactory.requestAuthorization(types, permissions: permissions);
      if (!authorized) return false;

      // 2. Son 24 saat için sorgu yap
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      // Verileri çek (Öğrenilmiş verileri temizleyip filtreliyoruz)
      List<HealthDataPoint> healthData = await _healthFactory.getHealthDataFromTypes(
        startTime: yesterday,
        endTime: now,
        types: types,
      );

      healthData = Health().removeDuplicates(healthData);

      double totalSteps = 0;
      double avgSleepHours = 0;
      double avgHeartRate = 0;
      double avgSystolic = 0;
      double avgDiastolic = 0;
      double avgSpo2 = 0;

      int sleepCount = 0;
      int hrCount = 0;
      int sysCount = 0;
      int diaCount = 0;
      int spo2Count = 0;

      for (var point in healthData) {
        if (point.type == HealthDataType.STEPS) {
          totalSteps += double.tryParse(point.value.toString()) ?? 0;
        } else if (point.type == HealthDataType.SLEEP_ASLEEP) {
          final val = double.tryParse(point.value.toString()) ?? 0;
          avgSleepHours += (val / 60); // genelde dakika gelir
          sleepCount++;
        } else if (point.type == HealthDataType.HEART_RATE) {
          avgHeartRate += double.tryParse(point.value.toString()) ?? 0;
          hrCount++;
        } else if (point.type == HealthDataType.BLOOD_PRESSURE_SYSTOLIC) {
          avgSystolic += double.tryParse(point.value.toString()) ?? 0;
          sysCount++;
        } else if (point.type == HealthDataType.BLOOD_PRESSURE_DIASTOLIC) {
          avgDiastolic += double.tryParse(point.value.toString()) ?? 0;
          diaCount++;
        } else if (point.type == HealthDataType.BLOOD_OXYGEN) {
          avgSpo2 += double.tryParse(point.value.toString()) ?? 0;
          spo2Count++;
        }
      }

      // Varsa önceki günün verisini al ki üzerine yazmayalım
      final todayEntry = await getTodayEntry();
      
      // Ortalama hesapları
      if (sleepCount > 0) avgSleepHours /= sleepCount;
      if (hrCount > 0) avgHeartRate /= hrCount;
      if (sysCount > 0) avgSystolic /= sysCount;
      if (diaCount > 0) avgDiastolic /= diaCount;
      if (spo2Count > 0) avgSpo2 /= spo2Count;

      // Eğer Health Connect yeni bir adım getirdiyse eskisiyle değiştir (Yoksa eskisi kalsın)
      final newEntry = HealthEntry(
        date: now,
        weight: todayEntry?.weight ?? 0,
        steps: totalSteps > 0 ? totalSteps : (todayEntry?.steps ?? 0),
        sleepHours: avgSleepHours > 0 ? avgSleepHours : (todayEntry?.sleepHours ?? 0),
        heartRate: avgHeartRate > 0 ? avgHeartRate : (todayEntry?.heartRate ?? 0),
        systolic: avgSystolic > 0 ? avgSystolic : (todayEntry?.systolic ?? 0),
        diastolic: avgDiastolic > 0 ? avgDiastolic : (todayEntry?.diastolic ?? 0),
        spo2: avgSpo2 > 0 ? avgSpo2 : (todayEntry?.spo2 ?? 0),
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

// ── Veri Modeli ───────────────────────────────────────────────────

class HealthEntry {
  final DateTime date;
  final double weight;       // kg
  final double systolic;     // mmHg
  final double diastolic;    // mmHg
  final double sleepHours;   // saat
  final double steps;        // adım
  final double heartRate;    // bpm (isteğe bağlı)
  final double spo2;         // % (isteğe bağlı)
  final String source;       // "manual" | "health_connect"

  const HealthEntry({
    required this.date,
    this.weight = 0,
    this.systolic = 0,
    this.diastolic = 0,
    this.sleepHours = 0,
    this.steps = 0,
    this.heartRate = 0,
    this.spo2 = 0,
    this.source = 'manual',
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'weight': weight,
        'systolic': systolic,
        'diastolic': diastolic,
        'sleep_hours': sleepHours,
        'steps': steps,
        'heart_rate': heartRate,
        'spo2': spo2,
        'source': source,
        'updated_at': FieldValue.serverTimestamp(),
      };

  factory HealthEntry.fromJson(Map<String, dynamic> json) => HealthEntry(
        date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
        weight: (json['weight'] ?? 0).toDouble(),
        systolic: (json['systolic'] ?? 0).toDouble(),
        diastolic: (json['diastolic'] ?? 0).toDouble(),
        sleepHours: (json['sleep_hours'] ?? 0).toDouble(),
        steps: (json['steps'] ?? 0).toDouble(),
        heartRate: (json['heart_rate'] ?? 0).toDouble(),
        spo2: (json['spo2'] ?? 0).toDouble(),
        source: json['source'] ?? 'manual',
      );
}
