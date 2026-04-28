import 'dart:ui';
import '../theme/app_theme.dart';

/// Vücut Kitle İndeksi (BMI) hesaplama yardımcısı.
/// Tüm BMI logic'ini tek bir yerde tutar (DRY prensibi).
class BmiUtils {
  BmiUtils._();

  /// BMI değerini hesaplar. [height] cm, [weight] kg cinsinden.
  static double calculate(double height, double weight) {
    if (height <= 0 || weight <= 0) return 0;
    return weight / ((height / 100) * (height / 100));
  }

  /// BMI değerine göre Türkçe kategori metni döndürür.
  static String category(double bmi) {
    if (bmi <= 0) return '-';
    if (bmi < 18.5) return 'Zayıf';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Fazla Kilolu';
    return 'Obez';
  }

  /// BMI kategorisine göre uygun rengi döndürür.
  static Color color(double bmi) {
    if (bmi < 18.5) return AppColors.accent;
    if (bmi < 25) return AppColors.secondary;
    if (bmi < 30) return AppColors.accent;
    return AppColors.destructive;
  }
}
