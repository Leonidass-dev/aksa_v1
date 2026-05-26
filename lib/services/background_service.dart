import 'package:aksa_v1/utils/app_logger.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_constants.dart';
import '../firebase_options.dart';
import '../services/user_profile_service.dart';
import '../services/health_service.dart';
import 'api_service.dart';

const fetchBackground = "fetchBackground";

/// Her bir bildirim türüne ayrı ID atanarak, yeni bildirimlerin eskileri ezmesi engellenir.
int _nextNotificationId = AppConstants.notificationIdWater;

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      AppLogger.debug("Arkaplan Görevi Başladı: $task");
      
      // Isolate içinde Firebase başlatılmalı
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return Future.value(true);

      final profile = await UserProfileService.getProfile();
      if (profile == null) return Future.value(true);

      // Sadece Firestore'daki en son veriyi okuyoruz (Health Connect arka planda kısıtlıdır)
      final todayData = await HealthService.getTodayEntry();
      
      final now = DateTime.now();
      
      // 1. Akıllı Su Hatırlatıcısı
      if (now.hour >= AppConstants.waterReminderStartHour && now.hour <= AppConstants.waterReminderEndHour) {
        if (todayData == null || todayData.waterMl < AppConstants.lowWaterThresholdMl) {
          await _showNotification(
            AppConstants.notificationIdWater,
            "💧 Su İçmeyi Unutma!",
            "Günün yarısı bitti ama su tüketimin oldukça düşük. Hemen bir bardak su içerek tazelen!",
          );
        }
      }

      // 2. Akıllı Hareket Hatırlatıcısı
      if (now.hour >= AppConstants.stepReminderStartHour && now.hour <= AppConstants.stepReminderEndHour) {
        if (todayData == null || todayData.steps < AppConstants.lowStepThreshold) {
          await _showNotification(
            AppConstants.notificationIdSteps,
            "🚶‍♂️ Harekete Geçme Zamanı!",
            "Bugün çok hareketsiz kaldın. Kalp sağlığın için 15 dakikalık kısa bir yürüyüşe ne dersin?",
          );
        }
      }

      // 3. Risk Skorunu Kontrol Et
      final riskReq = RiskApiRequest(
        age: profile.age,
        weight: profile.weight,
        height: profile.height,
        gender: profile.gender,
        steps: todayData?.steps ?? 0,
        sleepHours: todayData?.sleepHours ?? 0,
        systolic: todayData?.systolic ?? 0,
        diastolic: todayData?.diastolic ?? 0,
        heartRateResting: todayData?.restingHeartRate ?? 0,
        heartRateAvg: todayData?.heartRate ?? 0,
        spo2: todayData?.spo2 ?? 0,
        stressLevel: todayData?.stressLevel ?? 0,
      );

      final result = await ApiService.fetchRiskScore(riskReq);
      
      if (result != null && result.level == "high") {
        await _showNotification(
          AppConstants.notificationIdRisk,
          "⚠️ Yüksek Sağlık Riski Tespit Edildi!",
          "Gününüzdeki verilerde anormallik var. Lütfen uygulamayı açıp kontrol edin.",
        );
      }

      return Future.value(true);
    } catch (err) {
      AppLogger.debug("Arkaplan Görevi Hatası: $err");
      return Future.value(false);
    }
  });
}

Future<void> _showNotification(int id, String title, String body) async {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings();
  const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
  );
      
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'high_risk_channel',
    'Sağlık Uyarıları',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );
  
  const DarwinNotificationDetails iosPlatformChannelSpecifics =
      DarwinNotificationDetails();
  
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iosPlatformChannelSpecifics,
      );
      
  await flutterLocalNotificationsPlugin.show(
    id,
    title,
    body,
    platformChannelSpecifics,
  );
}

class BackgroundService {
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
    );
    
    await Workmanager().registerPeriodicTask(
      "1",
      fetchBackground,
      frequency: const Duration(hours: 2), // Her 2 saatte bir
      constraints: Constraints(
        networkType: NetworkType.connected, // İnternet varsa çalışsın
      ),
    );
  }
}
