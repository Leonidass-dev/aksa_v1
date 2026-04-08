import 'package:flutter/material.dart';
import '../theme/theme_notifier.dart';

/// ThemeNotifier dinleyicisini otomatik yöneten mixin.
///
/// Kullanım:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with ThemeAwareMixin {
///   // initState ve dispose'da listener otomatik eklenir/kaldırılır
/// }
/// ```
///
/// Her ekranda tekrar eden 8 satırlık boilerplate'i kaldırır:
///   themeNotifier.addListener(_onThemeChange);
///   void _onThemeChange() => setState(() {});
///   themeNotifier.removeListener(_onThemeChange);
mixin ThemeAwareMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChange);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChange);
    super.dispose();
  }

  void _onThemeChange() {
    if (mounted) setState(() {});
  }
}
