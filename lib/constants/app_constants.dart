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
  static const double defaultSleepGoal = 8.0; // saat

  // ── API Timeout Süreleri ────────────────────────────────────
  static const Duration apiTimeout = Duration(seconds: 15);
  static const Duration longApiTimeout = Duration(seconds: 30);
  static const Duration chatApiTimeout = Duration(seconds: 45);
  static const Duration imageAnalysisTimeout = Duration(seconds: 90);

  // ── Veri Limitleri ──────────────────────────────────────────
  static const int defaultHistoryDays = 7;
  static const int chatHistoryLimit = 50;
  static const int mealHistoryLimit = 10;
  static const int riskHistoryLimit = 30;

  // ── Bildirim ID'leri ────────────────────────────────────────
  static const int notificationIdWater = 1001;
  static const int notificationIdSteps = 1002;
  static const int notificationIdRisk = 1003;
  static const int notificationIdInstant = 1004;

  // ── Akıllı Bildirim Eşikleri ────────────────────────────────
  static const double lowWaterThresholdMl = 500;
  static const double lowStepThreshold = 3000;
  static const int waterReminderStartHour = 14;
  static const int waterReminderEndHour = 20;
  static const int stepReminderStartHour = 18;
  static const int stepReminderEndHour = 22;

  // ── Profil Varsayılanları ───────────────────────────────────
  static const int defaultAge = 30;
  static const double defaultHeight = 170.0;
  static const double defaultWeight = 70.0;
  static const String defaultGender = 'M';
}
