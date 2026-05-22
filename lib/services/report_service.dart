import 'package:aksa_v1/utils/app_logger.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ReportService {
  static Future<void> generateAndShareReport() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Son 30 günlük verileri çek
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('health_entries')
          .orderBy('date', descending: true)
          .limit(30)
          .get();

      // CSV Başlık
      final StringBuffer csvContent = StringBuffer();
      csvContent.writeln('Tarih,Adim Sayisi,Uyku(Saat),Sistolik(Tansiyon),Diastolik(Tansiyon),Nabiz(bpm),Stres,Su(ml)');

      // CSV Satırları
      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        final dateStr = data['date'] != null ? data['date'].toString().split('T')[0] : '';
        final steps = data['steps'] ?? 0;
        final sleep = data['sleep_hours'] ?? 0;
        final sys = data['systolic'] ?? 0;
        final dia = data['diastolic'] ?? 0;
        final hr = data['heart_rate'] ?? 0;
        final stress = data['stress_level'] ?? 0;
        final water = data['water_ml'] ?? 0;

        csvContent.writeln('$dateStr,$steps,$sleep,$sys,$dia,$hr,$stress,$water');
      }

      // Dosyaya yaz
      final dir = await getApplicationDocumentsDirectory();
      final String timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final File file = File('${dir.path}/AKSA_Saglik_Raporu_$timestamp.csv');
      
      await file.writeAsString(csvContent.toString());

      // Paylaş
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Son 30 Günlük Sağlık Raporum',
      );

    } catch (e) {
      AppLogger.debug('Rapor oluşturulurken hata: $e');
      rethrow;
    }
  }
}
