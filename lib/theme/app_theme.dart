import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF2563EB);      // Canlı Royal Blue (Ferahlık için)
  static const Color primaryLight = Color(0xFF60A5FA); // Açık Mavi
  static const Color secondary = Color(0xFF10B981);    // Canlı Emerald (Yeşil)
  static const Color secondaryDark = Color(0xFF059669);
  static const Color accent = Color(0xFFF59E0B);       // Tatlı Turuncu
  static const Color destructive = Color(0xFFEF4444);
  
  // Açık Tema Renkleri
  static const Color background = Color(0xFFF4F7FB);   // Çok açık, ferah gri/mavi
  static const Color card = Color(0xFFFFFFFF);         // Saf Beyaz
  static const Color foreground = Color(0xFF1E293B);   // Yumuşak Siyah (Okunabilirlik)
  static const Color mutedForeground = Color(0xFF64748B);
  static const Color muted = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  
  // Semantik Renkler
  static const Color stressYellow = Color(0xFFF59E0B);
  static const Color sleepPurple = Color(0xFF8B5CF6);
  static const Color waterBlue = Color(0xFF3B82F6);
  static const Color stepsIndigo = Color(0xFF6366F1);
  static const Color chart4 = Color(0xFF6366F1);       // Indigo (Eski widgetlar için)
  static const Color accentDark = Color(0xFFEA580C);   // Koyu Turuncu (Eski widgetlar için)
  
  // Gölgeler için
  static const Color shadowColor = Color(0x0C000000); // Çok hafif, şık gölge
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Inter', // Eğer projede font yüklüyse veya sistem fontuyla daha temiz görünüm
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.destructive,
        surface: AppColors.card,
        onSurface: AppColors.foreground,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.foreground),
        titleTextStyle: TextStyle(
          color: AppColors.foreground,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none, // Çizgileri tamamen kaldırdık (Daha temiz)
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primaryLight,
        secondary: AppColors.secondary,
        error: AppColors.destructive,
        surface: const Color(0xFF1E293B),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
    );
  }
}
