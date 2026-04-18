import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/health_service.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/theme_aware_state.dart';
import 'package:intl/intl.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> with ThemeAwareMixin {
  bool _loading = true;
  bool _syncing = false;
  AnomalyApiResult? _result;
  String? _errorMsg;
  DateTime? _analyzedDate;

  @override
  void initState() {
    super.initState();
    _runAnomalyCheck();
  }

  Future<void> _runAnomalyCheck() async {
    setState(() {
      _loading = true;
      _syncing = true;
      _errorMsg = null;
    });

    // ── GÖREVLENDİRME: Önce Saatten Senkronize Ol (Analiz Güncelliği İçin) ──
    try {
      await HealthService.syncFromDevice(force: true);
    } catch (e) {
      debugPrint("Senkronizasyon hatası (geçiliyor): $e");
    }
    
    if (mounted) setState(() => _syncing = false);

    // Son 7 günün verisini Firestore'dan çek
    final entries = await HealthService.getLastNDays(8);

    if (entries.isEmpty) {
      setState(() {
        _loading = false;
        _errorMsg =
            'Anomali tespiti için yeterli veri yok.\nVeri Girişi ekranından sağlık verilerini kaydedin.';
      });
      return;
    }

    // Bugünün kaydı en yeni entry; history = geri kalanlar
    final todayEntry = entries.first;
    final historyEntries = entries.skip(1).toList();
    
    _analyzedDate = todayEntry.date;

    if (historyEntries.length < 3) {
      setState(() {
        _loading = false;
        _errorMsg =
            'Anomali tespiti için en az 3 günlük veri gerekiyor.\n${historyEntries.length} gün mevcut.';
      });
      return;
    }

    Map<String, dynamic> entryToMap(HealthEntry e) => {
      'date': e.date.toIso8601String(),
      'steps': e.steps,
      'sleep_hours': e.sleepHours,
      'heart_rate': e.heartRate,
      'systolic': e.systolic,
      'diastolic': e.diastolic,
      'spo2': e.spo2,
      'weight': e.weight,
    };

    final result = await ApiService.checkAnomalies(
      history: historyEntries.map(entryToMap).toList(),
      today: entryToMap(todayEntry),
    );

    if (mounted) {
      setState(() {
        _result = result;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            Padding(
              padding: const EdgeInsets.all(24),
              child: _buildBody(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final hasHigh =
        _result?.anomalies.any((a) => a.severity == 'high') ?? false;
    final headerColor = hasHigh ? AppColors.destructive : AppColors.primary;

    Widget? summaryBanner;
    if (!_loading && _result != null) {
      summaryBanner = Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatBubble(
              label: 'İncelenen\nMetrik',
              value: '${_result!.checkedMetrics}',
              icon: Icons.analytics_outlined,
            ),
            _StatBubble(
              label: 'Tespit\nEdilen',
              value: '${_result!.anomalies.length}',
              icon: Icons.warning_amber_outlined,
            ),
            _StatBubble(
              label: 'Durum',
              value: _result!.hasAnomaly ? 'Dikkat' : 'Normal',
              icon: _result!.hasAnomaly
                  ? Icons.error_outline
                  : Icons.check_circle_outline,
            ),
          ],
        ),
      );
    }

    return AppHeader(
      title: 'Sağlık Uyarıları',
      subtitle: 'Yapay Zeka Uyarı Analizi',
      gradientColors: [headerColor, headerColor.withValues(alpha: 0.7)],
      trailing: AppRefreshButton(
        onTap: _loading ? null : _runAnomalyCheck,
        isLoading: _loading,
      ),
      bottomContent: summaryBanner,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              _syncing ? 'Akıllı saatten veri alınıyor...' : 'Son 7 gün analiz ediliyor...',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorMsg != null) {
      return _buildInfoCard(context, _errorMsg!);
    }

    if (_result == null || _result!.anomalies.isEmpty) {
      return _buildAllClearCard(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_result!.anomalies.length} Uyarı Tespit Edildi',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (_analyzedDate != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    DateFormat('d MMMM yyyy').format(_analyzedDate!),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
            ],
          ),
        ),
        ..._result!.anomalies.map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildAnomalyCard(context, a),
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildAllClearCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      backgroundColor: AppColors.secondary.withValues(alpha: 0.06),
      border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: AppColors.secondary,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Her Şey Normal!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Son 7 günlük verilerinde\nhiçbir anormal sapma tespit edilmedi.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String message) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: cs.onSurface, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnomalyCard(BuildContext context, AnomalyApiItem a) {
    final cs = Theme.of(context).colorScheme;
    final color = a.severity == 'high'
        ? AppColors.destructive
        : a.severity == 'medium'
        ? AppColors.accent
        : AppColors.secondary;
    final icon = a.severity == 'high'
        ? Icons.error_outline
        : a.severity == 'medium'
        ? Icons.warning_amber_outlined
        : Icons.info_outline;

    return AppCard(
      border: Border.all(color: color.withValues(alpha: 0.3)),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
      child: Column(
        children: [
          // Başlık satırı
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.metricLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        '${a.todayValue} ${a.unit} — ort. ${a.avgValue} ${a.unit}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Z-skoru badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'z=${a.zScore.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Açıklama
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              a.description,
              style: TextStyle(fontSize: 13, color: cs.onSurface, height: 1.4),
            ),
          ),
          // Öneri kutusu
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: color, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      a.recommendation,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBubble extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatBubble({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
