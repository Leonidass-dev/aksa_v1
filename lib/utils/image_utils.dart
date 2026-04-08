import 'dart:convert';
import 'package:flutter/material.dart';

/// Base64 data URI veya normal URL'den [ImageProvider] oluşturur.
///
/// Kullanım:
/// ```dart
/// final provider = ImageUtils.getPhotoProvider(user.photoUrl);
/// CircleAvatar(backgroundImage: provider);
/// ```
///
/// Daha önce `profile_screen.dart` ve `profile_page.dart` dosyalarında
/// birebir aynı şekilde tekrarlanıyordu.
class ImageUtils {
  ImageUtils._(); // Singleton oluşturulmasını engelle

  /// [url] boş veya null ise `null` döner.
  /// `data:image` ile başlıyorsa Base64 decode edip [MemoryImage] döner.
  /// Diğer URL'ler için [NetworkImage] döner.
  static ImageProvider? getPhotoProvider(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      final base64Str = url.split(',').last;
      return MemoryImage(base64Decode(base64Str));
    }
    return NetworkImage(url);
  }
}
