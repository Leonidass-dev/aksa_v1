import '../models/health_entry.dart';

/// Günlük sağlık verisinin risk/anomali için yeterliliği.
class HealthDataQuality {
  HealthDataQuality._();

  static const Duration heartRateMaxAge = Duration(hours: 8);

  static bool hasFreshHeartRate(HealthEntry? entry) {
    if (entry == null || entry.heartRate <= 0) return false;
    final t = entry.heartRateTime;
    if (t == null) return true;
    return DateTime.now().difference(t.toLocal()) <= heartRateMaxAge;
  }

  static bool hasActionableVitals(HealthEntry? entry) {
    if (entry == null) return false;
    final hasHr = entry.heartRate > 0 || entry.restingHeartRate > 0;
    final hasSteps = entry.steps > 0;
    final hasSleep = entry.sleepHours > 0;
    final hasBp = entry.systolic > 0 || entry.diastolic > 0;
    final hasSpo2 = entry.spo2 > 0;
    return hasHr || hasSteps || hasSleep || hasBp || hasSpo2;
  }

  /// Risk API çağrısı için nabız: yalnızca taze ölçüm gönderilir.
  static double heartRateForRisk(HealthEntry entry) {
    if (!hasFreshHeartRate(entry)) return 0;
    return entry.heartRate;
  }

  static double restingHeartRateForRisk(HealthEntry entry) {
    if (entry.restingHeartRate > 0) return entry.restingHeartRate;
    return heartRateForRisk(entry);
  }

  static bool isInsufficientRiskResult(String? modelVersion) =>
      modelVersion == 'insufficient-data';

}
