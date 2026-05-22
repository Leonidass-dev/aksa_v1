import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_notifier.dart';
import '../../widgets/common_widgets.dart';

/// Tercihler kartı — bildirim, dark mode ve gizlilik ayarları.
class PreferencesCard extends StatefulWidget {
  final VoidCallback onPrivacyTap;

  const PreferencesCard({
    super.key,
    required this.onPrivacyTap,
  });

  @override
  State<PreferencesCard> createState() => _PreferencesCardState();
}

class _PreferencesCardState extends State<PreferencesCard> {
  bool _notifications = true;
  bool _waterNotif = true;
  bool _exerciseNotif = true;
  bool _summaryNotif = false;
  bool _useMetric = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifications = prefs.getBool('pref_notifications') ?? true;
      _waterNotif = prefs.getBool('pref_water_notif') ?? true;
      _exerciseNotif = prefs.getBool('pref_exercise_notif') ?? true;
      _summaryNotif = prefs.getBool('pref_summary_notif') ?? false;
      _useMetric = prefs.getBool('pref_use_metric') ?? true;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = themeNotifier.value == ThemeMode.dark;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tercihler', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 16),
          _toggleRow(
            context, 
            Icons.notifications_outlined, 
            AppColors.primary,
            'Bildirimler', 
            'Tüm anlık bildirimler', 
            _notifications, 
            (v) {
              setState(() => _notifications = v);
              _savePreference('pref_notifications', v);
            }
          ),
          if (_notifications) ...[
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 8),
              child: Column(
                children: [
                  _subToggleRow(context, 'Su Hatırlatması', _waterNotif, (v) {
                    setState(() => _waterNotif = v);
                    _savePreference('pref_water_notif', v);
                  }),
                  _subToggleRow(context, 'Egzersiz Hatırlatması', _exerciseNotif, (v) {
                    setState(() => _exerciseNotif = v);
                    _savePreference('pref_exercise_notif', v);
                  }),
                  _subToggleRow(context, 'Günlük Özet', _summaryNotif, (v) {
                    setState(() => _summaryNotif = v);
                    _savePreference('pref_summary_notif', v);
                  }),
                ],
              ),
            ),
          ],
          Divider(color: cs.outlineVariant, height: 24),
          _toggleRow(
            context, 
            Icons.dark_mode_outlined, 
            AppColors.accent,
            'Karanlık Mod', 
            'Karanlık temaya geç', 
            isDark,
            (v) {
              themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
            }
          ),
          Divider(color: cs.outlineVariant, height: 24),
          _toggleRow(
            context, 
            Icons.straighten_outlined, 
            AppColors.stepsIndigo,
            'Ölçü Birimi', 
            _useMetric ? 'Metrik (cm, kg)' : 'İmparatorluk (ft, lbs)', 
            _useMetric,
            (v) {
              setState(() => _useMetric = v);
              _savePreference('pref_use_metric', v);
            }
          ),
          Divider(color: cs.outlineVariant, height: 24),
          _buildPrivacyRow(context),
        ],
      ),
    );
  }

  Widget _subToggleRow(BuildContext context, String title, bool value, ValueChanged<bool> onChanged) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        Switch(
          value: value, 
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
        ),
      ],
    );
  }

  Widget _toggleRow(BuildContext context, IconData icon, Color color,
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: cs.onSurface)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.primary),
      ],
    );
  }

  Widget _buildPrivacyRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: widget.onPrivacyTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shield_outlined, color: AppColors.secondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gizlilik ve Güvenlik', style: TextStyle(fontWeight: FontWeight.w500, color: cs.onSurface)),
                Text('Veri koruma ayarları', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
        ],
      ),
    );
  }
}
