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

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'date': date.toIso8601String(),
      'mood': mood,
      'source': source,
      'updated_at': FieldValue.serverTimestamp(),
    };

    // Sadece anlamlı (> 0) değerleri yaz, böylece merge:true ile
    // mevcut Health Connect verileri sıfırlanmaz
    if (steps > 0) map['steps'] = steps;
    if (activeCalories > 0) map['active_calories'] = activeCalories;
    if (totalCalories > 0) map['total_calories'] = totalCalories;
    if (distanceM > 0) map['distance_m'] = distanceM;
    if (heartRate > 0) map['heart_rate'] = heartRate;
    if (restingHeartRate > 0) map['resting_heart_rate'] = restingHeartRate;
    if (spo2 > 0) map['spo2'] = spo2;
    if (systolic > 0) map['systolic'] = systolic;
    if (diastolic > 0) map['diastolic'] = diastolic;
    if (sleepHours > 0) map['sleep_hours'] = sleepHours;
    if (sleepDeepMin > 0) map['sleep_deep_min'] = sleepDeepMin;
    if (sleepLightMin > 0) map['sleep_light_min'] = sleepLightMin;
    if (sleepRemMin > 0) map['sleep_rem_min'] = sleepRemMin;
    if (sleepAwakeMin > 0) map['sleep_awake_min'] = sleepAwakeMin;
    if (stressLevel > 0) map['stress_level'] = stressLevel;
    if (weight > 0) map['weight'] = weight;
    if (waterMl > 0) map['water_ml'] = waterMl;

    return map;
  }

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

  HealthEntry copyWith({
    DateTime? date,
    double? steps,
    double? activeCalories,
    double? totalCalories,
    double? distanceM,
    double? heartRate,
    double? restingHeartRate,
    double? spo2,
    double? systolic,
    double? diastolic,
    double? sleepHours,
    double? sleepDeepMin,
    double? sleepLightMin,
    double? sleepRemMin,
    double? sleepAwakeMin,
    double? stressLevel,
    double? weight,
    double? waterMl,
    String? mood,
    String? source,
  }) {
    return HealthEntry(
      date: date ?? this.date,
      steps: steps ?? this.steps,
      activeCalories: activeCalories ?? this.activeCalories,
      totalCalories: totalCalories ?? this.totalCalories,
      distanceM: distanceM ?? this.distanceM,
      heartRate: heartRate ?? this.heartRate,
      restingHeartRate: restingHeartRate ?? this.restingHeartRate,
      spo2: spo2 ?? this.spo2,
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      sleepHours: sleepHours ?? this.sleepHours,
      sleepDeepMin: sleepDeepMin ?? this.sleepDeepMin,
      sleepLightMin: sleepLightMin ?? this.sleepLightMin,
      sleepRemMin: sleepRemMin ?? this.sleepRemMin,
      sleepAwakeMin: sleepAwakeMin ?? this.sleepAwakeMin,
      stressLevel: stressLevel ?? this.stressLevel,
      weight: weight ?? this.weight,
      waterMl: waterMl ?? this.waterMl,
      mood: mood ?? this.mood,
      source: source ?? this.source,
    );
  }
}
