import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        // Bildirime tıklandığında yapılacaklar (örn: uygulama içi yönlendirme)
      },
    );
  }

  /// Periyodik su içme ve hareket hatırlatıcılarını planlar (Sabah 09:00 - Akşam 21:00)
  static Future<void> scheduleNudges() async {
    // Önce eskileri temizle
    await _notifications.cancelAll();

    // 2 saatte bir (ortalama günde 6 bildirim)
    for (int i = 0; i < 6; i++) {
        final scheduleTime = tz.TZDateTime.now(tz.local).add(Duration(hours: (i + 1) * 2));
        
        // Sadece 09:00 ile 21:00 arası bildirimi planla
        if (scheduleTime.hour >= 9 && scheduleTime.hour <= 21) {
            await _notifications.zonedSchedule(
                i,
                'AKSA Hatırlatıcı',
                i % 2 == 0 
                  ? 'Bir bardak su içerek vücudunu tazelemeye ne dersin? 💧'
                  : 'Biraz hareket zamanı! Hadi 5 dakika yürüyelim. 🚶‍♂️',
                scheduleTime,
                const NotificationDetails(
                    android: AndroidNotificationDetails(
                        'aksa_nudges',
                        'Sağlık Hatırlatıcıları',
                        channelDescription: 'Su ve hareket nudgeları için kanal',
                        importance: Importance.max,
                        priority: Priority.high,
                    ),
                    iOS: DarwinNotificationDetails(),
                ),
                androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
                uiLocalNotificationDateInterpretation:
                    UILocalNotificationDateInterpretation.absoluteTime,
                matchDateTimeComponents: DateTimeComponents.time,
            );
        }
    }
  }

  static Future<void> showInstantMessage(String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'instant', 
        'Anlık Bildirimler',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );
    await _notifications.show(99, title, body, details);
  }
}
