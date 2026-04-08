/// Uygulama genelinde kullanılan sabit değerler.
/// Yeni bir sabit eklemeniz gerektiğinde buraya ekleyin.
class AppConstants {
  AppConstants._(); // instantiation engelle

  // ── Boyutlar ────────────────────────────────────────────────
  static const double pagePadding = 24.0;
  static const double cardRadius = 20.0;
  static const double headerRadius = 32.0;
  static const double buttonRadius = 16.0;
  static const double iconContainerRadius = 14.0;
  static const double bottomNavHeight = 64.0;
  static const double bottomSafeSpace = 80.0; // FAB ile çakışma payı

  // ── Hedefler ────────────────────────────────────────────────
  static const int defaultStepGoal = 10000;
  static const int defaultCalorieGoal = 2000;
  static const double defaultSleepGoal = 8.0; // saat

  // ── Süreler ─────────────────────────────────────────────────
  static const Duration apiTimeout = Duration(seconds: 10);
  static const Duration longApiTimeout = Duration(seconds: 30);
  static const Duration chatApiTimeout = Duration(seconds: 45);
  static const Duration successDelay = Duration(milliseconds: 1200);

  // ── Veri Limitleri ──────────────────────────────────────────
  static const int defaultHistoryDays = 7;
  static const int anomalyMinDays = 3;
  static const int chatHistoryLimit = 50;
  static const int mealHistoryLimit = 10;
  static const int riskHistoryLimit = 30;

  // ── BMR Çarpanları (Mifflin-St Jeor) ────────────────────────
  static const double activityMultiplierLight = 1.375;

  // ── Profil Varsayılanları ───────────────────────────────────
  static const int defaultAge = 30;
  static const double defaultHeight = 170.0;
  static const double defaultWeight = 70.0;
  static const String defaultGender = 'M';
}
