import '../health_service.dart' show HealthEntry;

abstract class IHealthService {
  Future<void> saveHealthEntry(HealthEntry entry);
  Future<bool> syncFromDevice({bool force = false});
  Future<HealthEntry?> getTodayEntry();
  Future<List<HealthEntry>> getLastNDays(int n);
  Future<void> updateWater(double ml);
  Future<void> updateMood(String mood);
  double calculateWaterTarget(double weight);
}
