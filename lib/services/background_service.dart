import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

const fetchBackground = "fetchBackground";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint("Arkaplan Görevi Başladı: $task");
      
      // Risk Skorunu backend'den çek
      // Arkaplan isolate'inde Health Connect erişimi kısıtlı olduğundan,
      // backend'deki en son kayıtlı sağlık verisini kullanıyoruz.
      final riskReq = RiskApiRequest(
        age: 30,
        weight: 70,
        height: 175,
      );

      final result = await ApiService.fetchRiskScore(riskReq);
      
      if (result != null && result.level == "high") {
        await _showNotification(
          "⚠️ Yüksek Sağlık Riski Tespit Edildi!",
          "Verilerinizde anormallik var. Lütfen uygulamayı açıp kontrol edin.",
        );
      }

      return Future.value(true);
    } catch (err) {
      debugPrint("Arkaplan Görevi Hatası: $err");
      return Future.value(false); // retry
    }
  });
}

Future<void> _showNotification(String title, String body) async {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
      
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'high_risk_channel',
    'Sağlık Uyarıları',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );
  
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);
      
  await flutterLocalNotificationsPlugin.show(
    0,
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
