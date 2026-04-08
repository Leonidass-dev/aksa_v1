import 'package:cloud_firestore/cloud_firestore.dart';

/// Redmi Watch 4 tüm sensör alanlarını barındıran sağlık veri modeli.
///
/// Bu model Firestore'daki `health_entries` koleksiyonunun tek bir günlük
/// kaydına karşılık gelir. Hem manuel giriş hem Health Connect verisi için
/// ortak yapıdır.
class HealthEntry {
  final DateTime date;

  // Aktivite
  final double steps;
  final double activeCalories;
  final double totalCalories;
  final double distanceM;

  // Kardiyovasküler
  final double heartRate;
  final double restingHeartRate;
  final double spo2;

  // Tansiyon
  final double systolic;
  final double diastolic;

  // Uyku (detaylı)
  final double sleepHours;
  final double sleepDeepMin;
  final double sleepLightMin;
  final double sleepRemMin;
  final double sleepAwakeMin;

  // Stres & Vücut
  final double stressLevel;
  final double weight;

  // Yeni Özellikler
  final double waterMl;
  final String mood;

  // Meta
  final String source; // "manual" | "health_connect"

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
    this.waterMl = 0,
    this.mood = 'neutral',
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
    // Yeni Özellikler
    'water_ml': waterMl,
    'mood': mood,
    // Meta
    'source': source,
    'updated_at': FieldValue.serverTimestamp(),
  };

  factory HealthEntry.fromJson(Map<String, dynamic> json) => HealthEntry(
    date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
    steps: (json['steps'] ?? 0).toDouble(),
    activeCalories: (json['active_calories'] ?? 0).toDouble(),
    totalCalories: (json['total_calories'] ?? 0).toDouble(),
    distanceM: (json['distance_m'] ?? 0).toDouble(),
    heartRate: (json['heart_rate'] ?? 0).toDouble(),
    restingHeartRate: (json['resting_heart_rate'] ?? 0).toDouble(),
    spo2: (json['spo2'] ?? 0).toDouble(),
    systolic: (json['systolic'] ?? 0).toDouble(),
    diastolic: (json['diastolic'] ?? 0).toDouble(),
    sleepHours: (json['sleep_hours'] ?? 0).toDouble(),
    sleepDeepMin: (json['sleep_deep_min'] ?? 0).toDouble(),
    sleepLightMin: (json['sleep_light_min'] ?? 0).toDouble(),
    sleepRemMin: (json['sleep_rem_min'] ?? 0).toDouble(),
    sleepAwakeMin: (json['sleep_awake_min'] ?? 0).toDouble(),
    stressLevel: (json['stress_level'] ?? 0).toDouble(),
    weight: (json['weight'] ?? 0).toDouble(),
    waterMl: (json['water_ml'] ?? 0).toDouble(),
    mood: json['mood'] ?? 'neutral',
    source: json['source'] ?? 'manual',
  );
}
