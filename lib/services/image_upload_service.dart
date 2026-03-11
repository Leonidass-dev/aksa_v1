import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Soyut sınıftır. Gelecekte Firebase Storage kullanmak isterseniz
/// bu sınıfı implement eden 'FirebaseStorageUploadService' yazabilirsiniz.
abstract class ImageUploadService {
  /// Alınan [file] dosyasını buluta ya da veritabanına yükler.
  /// İşlem başarılıysa fotoğrafın String halini (URL veya Base64) döner.
  Future<String?> uploadImage(File file, String userId);
}

/// Dosyaları Base64 metnine dönüştüren ve doğrudan bir URL gibi kullanılmasını sağlayan
/// ücretsiz (Firestore dokümanlarına kaydedilebilir) depolama servisi.
class Base64ImageUploadService implements ImageUploadService {
  @override
  Future<String?> uploadImage(File file, String userId) async {
    try {
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      // Data URI scheme olarak dönüyoruz, böylece anında tanınabilir
      return 'data:image/jpeg;base64,$base64String';
    } catch (e) {
      debugPrint('Base64 dönüştürme hatası: $e');
      return null;
    }
  }
}
