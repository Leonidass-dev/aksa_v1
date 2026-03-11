import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../theme/theme_notifier.dart';
import '../services/health_service.dart';
import '../services/api_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool _loading = true;
  AnomalyApiResult? _result;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChange);
    _runAnomalyCheck();
  }

  void _onThemeChange() => setState(() {});

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChange);
    super.dispose();
  }

  Future<void> _runAnomalyCheck() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    // Son 7 günün verisini Firestore'dan çek
    final entries = await HealthService.getLastNDays(8);

    if (entries.isEmpty) {
      setState(() {
        _loading = false;
        _errorMsg = 'Anomali tespiti için yeterli veri yok.\nVeri Girişi ekranından sağlık verilerini kaydedin.';
      });
      return;
    }

    // Bugünün kaydı en yeni entry; history = geri kalanlar
    final todayEntry = entries.first;
    final historyEntries = entries.skip(1).toList();

    if (historyEntries.length < 3) {
      setState(() {
        _loading = false;
        _errorMsg = 'Anomali tespiti için en az 3 günlük veri gerekiyor.\n${historyEntries.length} gün mevcut.';
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
      history: {'data': historyEntries.map(entryToMap).toList()},
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
    final hasHigh = _result?.anomalies.any((a) => a.severity == 'high') ?? false;
    final headerColor = hasHigh ? AppColors.destructive : AppColors.primary;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [headerColor, headerColor.withValues(alpha: 0.7)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/app/dashboard'),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sağlık Uyarıları',
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        Text('Yapay Zeka Uyarı Analizi',
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  // Yenile butonu
                  GestureDetector(
                    onTap: _loading ? null : _runAnomalyCheck,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.refresh,
                          color: Colors.white.withValues(alpha: _loading ? 0.4 : 1.0), size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Özet bant
              if (!_loading && _result != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatBubble(
                          label: 'İncelenen\nMetrik',
                          value: '${_result!.checkedMetrics}',
                          icon: Icons.analytics_outlined),
                      _StatBubble(
                          label: 'Tespit\nEdilen',
                          value: '${_result!.anomalies.length}',
                          icon: Icons.warning_amber_outlined),
                      _StatBubble(
                          label: 'Durum',
                          value: _result!.hasAnomaly ? 'Dikkat' : 'Normal',
                          icon: _result!.hasAnomaly
                              ? Icons.error_outline
                              : Icons.check_circle_outline),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text('Son 7 gün analiz ediliyor...', style: TextStyle(fontSize: 13)),
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
          child: Text('${_result!.anomalies.length} Uyarı Tespit Edildi',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface)),
        ),
        ..._result!.anomalies.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildAnomalyCard(context, a),
            )),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildAllClearCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_outline, color: AppColors.secondary, size: 40),
          ),
          const SizedBox(height: 16),
          Text('Her Şey Normal!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
          const SizedBox(height: 8),
          Text('Son 7 günlük verilerinde\nhiçbir anormal sapma tespit edilmedi.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String message) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message,
                  style: TextStyle(fontSize: 13, color: cs.onSurface, height: 1.5))),
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

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
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
                      Text(a.metricLabel,
                          style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
                      Text(
                          '${a.todayValue} ${a.unit} — ort. ${a.avgValue} ${a.unit}',
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                // Z-skoru badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('z=${a.zScore.toStringAsFixed(1)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
          ),
          // Açıklama
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(a.description,
                style: TextStyle(fontSize: 13, color: cs.onSurface, height: 1.4)),
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
                    child: Text(a.recommendation,
                        style: TextStyle(fontSize: 12, color: cs.onSurface, height: 1.4)),
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
  const _StatBubble({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
      ],
    );
  }
}