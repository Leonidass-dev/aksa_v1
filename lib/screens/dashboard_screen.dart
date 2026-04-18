import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../models/health_data.dart';
import '../services/health_service.dart';
import '../services/api_service.dart';
import '../services/user_profile_service.dart';
import '../constants/app_constants.dart';
import '../widgets/common_widgets.dart';
import '../widgets/app_line_chart.dart';
import '../widgets/theme_aware_state.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with ThemeAwareMixin, WidgetsBindingObserver {
  static const List<String> _days = [
    'Pzt',
    'Sal',
    'Çar',
    'Per',
    'Cum',
    'Cmt',
    'Paz',
  ];

  RiskResult? _riskResult;
  List<double> _weeklyData = List.filled(7, 0.0);
  double _systolic = 120;
  double _diastolic = 80;
  double _sleep = AppConstants.defaultSleepGoal;
  double _steps = 0;
  bool _loadingRisk = true;
  String _userName = 'Kullanıcı';
  double _userHeight = 175.0; 
  double _userWeight = 70.0;
  double _waterTarget = 2000;
  bool _isSyncing = false;


  // Bugünün Firestore'dan gelen verileri
  HealthEntry? _todayEntry;
  AnomalyApiResult? _anomalyResult; // Modül 7: Anomali Sonuçları
  bool _isAnomalyDismissed = false;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Günaydın';
    if (hour < 18) return 'Tünaydın';
    return 'İyi Akşamlar';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserName();
    _silentSyncAndLoad();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isSyncing) {
      _silentSyncAndLoad();
    }
  }

  Future<void> _silentSyncAndLoad() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      // Health Connect'in `Foreground` kısıtlamasına (Android 14+) takılmamak için
      // render döngüsünün tam olarak bitmesini küçük bir gecikmeyle garantiye alıyoruz
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Uygulama açıldığında veya arkaplandan döndüğünde sessizce verileri eşitle
      await HealthService.syncFromDevice();
      // Ardından arayüzü güncelle
      if (mounted) {
        await _loadTodayData();
      }
    } catch (e) {
      debugPrint("Sessiz senkronizasyon hatası: $e");
    } finally {
      if (mounted) {
        _isSyncing = false;
      }
    }
  }

  void _loadUserName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final nameParts = user.displayName?.split(' ');
      final emailParts = user.email?.split('@');
      setState(() {
        _userName = (nameParts != null && nameParts.isNotEmpty ? nameParts.first : null) ??
            (emailParts != null && emailParts.isNotEmpty ? emailParts.first : null) ??
            'Kullanıcı';
      });
    }
  }

  Future<void> _loadTodayData() async {
    if (!mounted) return;
    setState(() => _loadingRisk = true);

    final profile = await UserProfileService.getProfile();
    final pAge = profile?.age ?? AppConstants.defaultAge;
    final pHeight = profile?.height ?? AppConstants.defaultHeight;
    final pWeight = profile?.weight ?? AppConstants.defaultWeight;
    final pGender = profile?.gender ?? AppConstants.defaultGender;

    if (mounted) {
      setState(() {
        _userHeight = pHeight;
        _userWeight = pWeight;
      });
    }

    final entry = await HealthService.getTodayEntry();
    final todayData = entry ?? HealthEntry(date: DateTime.now());

    if (mounted) {
      if (entry != null) setState(() => _todayEntry = entry);

      // Not: Erken sabah (00:00-02:00) mantığı health_service.dart syncFromDevice içinde zaten uygulanıyor.
      // Firestore'dan gelen veri bu düzeltmeyi içeriyor, burada tekrar etmeye gerek yok.

      // Firestore'dan veri gelsin ya da gelmesin, mevcut profil bilgisiyle API hesaplamasini yap.
      final result = await ApiService.fetchRiskScore(
        RiskApiRequest(
          age: pAge,
          gender: pGender,
          height: pHeight,
          weight: profile?.weight ?? 70.0,
          steps: todayData.steps,
          sleepHours: todayData.sleepHours,
          systolic: todayData.systolic,
          diastolic: todayData.diastolic,
          heartRateResting: todayData.restingHeartRate > 0
              ? todayData.restingHeartRate
              : todayData.heartRate, // Dinlenik yoksa ortalamayı kullan
          heartRateAvg: todayData.heartRate,
          spo2: todayData.spo2,
          stressLevel: todayData.stressLevel,
        ),
      );

      if (mounted) {
        setState(() {
          _waterTarget = HealthService.calculateWaterTarget(pWeight);
        });
      }

      // MODÜL 7: ANOMALİ TESPİTİ (Son 7 gün vs Bugün)
      try {
        final last7Days = await HealthService.getLastNDays(7);
        // Backend beklentisi: history parametresi list[DailySnapshotRequest] olmalıdır.
        final List<Map<String, dynamic>> formattedHistory = last7Days.map((e) {
          final json = e.toJson();
          json.remove('updated_at'); // FieldValue.serverTimestamp hatasını önlemek için
          // 'date' alanı zaten toJson'da var, backend 'date' string bekliyor
          json['date'] ??= DateTime.now().toIso8601String();
          return json;
        }).toList();

        // FieldValue.serverTimestamp() nesnesi (updated_at) JSON encode edilemez, bu yüzden API'ye gitmeden önce siliyoruz
        final todayJson = todayData.toJson();
        todayJson.remove('updated_at');
        todayJson['date'] ??= DateTime.now().toIso8601String();

        final anomaly = await ApiService.checkAnomalies(
          history: formattedHistory,
          today: todayJson,
        );
        if (mounted) {
          setState(() {
            _anomalyResult = anomaly;
            _isAnomalyDismissed = false; // Yeni veri geldiğinde (veya tazelendiğinde) tekrar göster
          });
        }
      } catch (e) {
        debugPrint("Anomali kontrol hatası: $e");
      }

      if (result != null) {
        setState(() {
          _riskResult = RiskResult(
            score: result.score,
            level: RiskLevelExtension.fromString(result.level),
            topFactors: result.topFactors
                .map(
                  (f) => RiskFactor(
                    name: f.name,
                    contribution: f.contribution,
                    description: f.description,
                  ),
                )
                .toList(),
            modelVersion: result.modelVersion,
            windowEnd: DateTime.now(),
          );
        });
      }

      // Haftalık geçmişi al (son 7 skor)
      try {
        final historyDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('risk_history')
            .orderBy('timestamp', descending: true)
            .limit(7)
            .get();
        final List<double> latestScores = [];
        for (var doc in historyDoc.docs) {
          final s = doc.data()['score'] as num?;
          if (s != null) latestScores.add(s.toDouble());
        }
        // Eksik günleri 0 ile doldur
        while (latestScores.length < 7) {
          latestScores.add(0.0);
        }
        if (mounted) {
          setState(() {
            _weeklyData = latestScores.reversed.toList();
          });
        }
      } catch (e) {
        debugPrint('Haftalık risk geçmişi hatası: $e');
      }

      if (mounted) setState(() => _loadingRisk = false);
    }
  }

  Future<void> _handleManualSync() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Veriler senkronize ediliyor...'),
          ],
        ),
        duration: Duration(seconds: 1),
      ),
    );

    final success = await HealthService.syncFromDevice(force: true);
    
    if (success) {
      await _loadTodayData();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Sağlık verileri başarıyla güncellendi! ✅'),
          backgroundColor: AppColors.secondary,
        ),
      );
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Veri çekilemedi. Health Connect izinlerini kontrol edin. ❌'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }


  // ── Yardımcılarım ─────────────────────────────────────────────
  String _calculateBMI(double height, double weight) {
    if (height <= 0 || weight <= 0) return '-';
    final bmi = weight / ((height / 100) * (height / 100));
    String status = '';
    if (bmi < 18.5) status = '(Zayıf)';
    else if (bmi < 25) status = '(Normal)';
    else if (bmi < 30) status = '(Fazla Kilolu)';
    else status = '(Obez)';
    
    return '${bmi.toStringAsFixed(1)} $status';
  }

  Color get _levelColor {
    if (_riskResult == null) return AppColors.primary;
    return _riskResult!.level.color;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _silentSyncAndLoad,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildSliverHeader(context),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_anomalyResult?.hasAnomaly == true && !_isAnomalyDismissed) ...[
                      _buildModernAnomalyBanner(context),
                      const SizedBox(height: 16),
                    ],
                    _buildMainHealthGauge(context),
                    const SizedBox(height: 24),
                    _buildSectionTitle(context, 'Günlük Metrikler', Icons.insights_rounded),
                    const SizedBox(height: 10),
                    _buildMetricsGrid(context),
                    const SizedBox(height: 24),
                    _buildWaterAndMoodSection(context),
                    const SizedBox(height: 24),
                    _buildSectionTitle(context, 'Hızlı Keşfet', Icons.explore_outlined),
                    const SizedBox(height: 10),
                    _buildDiscoverGrid(context),
                    const SizedBox(height: 24),
                    _buildWeeklyTrendCard(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
          ),
        ),
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  _userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                _buildHeaderIcon(Icons.sync_rounded, _handleManualSync),
                const SizedBox(width: 8),
                _buildHeaderIcon(Icons.notifications_none_rounded, () => context.go('/app/alerts'), hasBadge: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon, VoidCallback onTap, {bool hasBadge = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          if (hasBadge)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
      ],
    );
  }

  Widget _buildMainHealthGauge(BuildContext context) {
    final risk = _riskResult;
    return AppCard(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).cardColor,
            Theme.of(context).cardColor.withValues(alpha: 0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Genel Sağlık Durumu',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (risk?.level.color ?? AppColors.primary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  risk?.level.label ?? 'Hesaplanıyor...',
                  style: TextStyle(
                    color: risk?.level.color ?? AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: CircularProgressIndicator(
                  value: (risk?.score ?? 0) / 100,
                  strokeWidth: 16,
                  backgroundColor: Colors.grey.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(risk?.level.color ?? AppColors.primary),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    risk != null ? '${risk.score.toInt()}' : '--',
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -2),
                  ),
                  const Text(
                    'Risk Skoru',
                    style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            _topFactorSummary(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    final entry = _todayEntry;
    final steps = entry?.steps ?? 0;
    final hr = entry?.heartRate ?? 0;
    final sleepH = entry?.sleepHours ?? 0;
    final sys = entry?.systolic ?? 0;
    final dia = entry?.diastolic ?? 0;
    final spo2 = entry?.spo2 ?? 0;
    final stress = entry?.stressLevel ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.35,
      children: [
        _buildMetricTile(
          context,
          icon: Icons.directions_walk_rounded,
          color: const Color(0xFF6366F1),
          label: 'Adım',
          value: steps > 0 ? '${steps.toInt()}' : '--',
          sub: '/ 10.000',
          progress: (steps / 10000).clamp(0.0, 1.0),
        ),
        _buildMetricTile(
          context,
          icon: Icons.favorite_rounded,
          color: AppColors.destructive,
          label: 'Nabız',
          value: hr > 0 ? '${hr.toInt()}' : '--',
          sub: hr > 0 ? 'bpm' : '',
          progress: hr > 0 ? ((hr - 40) / 160).clamp(0.0, 1.0) : 0,
          progressColor: hr > 100 ? AppColors.destructive : AppColors.secondary,
        ),
        _buildMetricTile(
          context,
          icon: Icons.bloodtype_rounded,
          color: AppColors.primary,
          label: 'Oksijen',
          value: spo2 > 0 ? '%${spo2.toInt()}' : '--',
          sub: spo2 > 95 ? 'Normal' : 'Düşük',
          progress: (spo2 / 100).clamp(0.0, 1.0),
        ),
        _buildMetricTile(
          context,
          icon: Icons.psychology_rounded,
          color: const Color(0xFFF59E0B),
          label: 'Stres',
          value: stress > 0 ? '${stress.toInt()}' : '--',
          sub: stress < 40 ? 'Düşük' : stress < 70 ? 'Orta' : 'Yüksek',
          progress: (stress / 100).clamp(0.0, 1.0),
          progressColor: stress > 70 ? AppColors.destructive : stress > 40 ? const Color(0xFFF59E0B) : AppColors.secondary,
        ),
        _buildMetricTile(
          context,
          icon: Icons.bedtime_rounded,
          color: const Color(0xFF8B5CF6),
          label: 'Uyku',
          value: sleepH > 0 ? sleepH.toStringAsFixed(1) : '--',
          sub: sleepH > 0 ? '/ 8 saat' : '',
          progress: (sleepH / 8).clamp(0.0, 1.0),
        ),
        _buildMetricTile(
          context,
          icon: Icons.speed_rounded,
          color: AppColors.accent,
          label: 'Tansiyon',
          value: sys > 0 ? '${sys.toInt()}/${dia.toInt()}' : '--',
          sub: sys > 0 ? (sys < 120 ? 'Normal' : sys < 140 ? 'Yüksek' : 'Riskli') : '',
          progress: sys > 0 ? ((sys - 80) / 120).clamp(0.0, 1.0) : 0,
          progressColor: sys > 140 ? AppColors.destructive : sys > 130 ? AppColors.accent : AppColors.secondary,
          onTap: () => _showBPEntrySheet(context),
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String sub,
    required double progress,
    Color? progressColor,
    VoidCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final pColor = progressColor ?? color;
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.onSurface),
              ),
              const SizedBox(width: 4),
              Text(sub, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(pColor),
            ),
          ),
        ],
      ),
    ),
    );
  }

  // ── Tansiyon Giriş Bottom Sheet ──
  void _showBPEntrySheet(BuildContext context) {
    final entry = _todayEntry;
    double sys = entry?.systolic ?? 120;
    double dia = entry?.diastolic ?? 80;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final cs = Theme.of(ctx).colorScheme;
          String category;
          Color catColor;
          if (sys < 120 && dia < 80) {
            category = 'Normal';
            catColor = AppColors.secondary;
          } else if (sys < 140 || dia < 90) {
            category = 'Yüksek';
            catColor = AppColors.accent;
          } else {
            category = 'Hipertansiyon';
            catColor = AppColors.destructive;
          }

          return Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tansiyon Ölçümü', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(category, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: catColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Sistolik
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sistolik (büyük)', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                    Text('${sys.toInt()} mmHg', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.destructive)),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.destructive,
                    thumbColor: AppColors.destructive,
                    inactiveTrackColor: AppColors.destructive.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: sys, min: 80, max: 200,
                    onChanged: (v) => setLocal(() => sys = v.roundToDouble()),
                  ),
                ),
                const SizedBox(height: 8),
                // Diastolik
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Diastolik (küçük)', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                    Text('${dia.toInt()} mmHg', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.accent)),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.accent,
                    thumbColor: AppColors.accent,
                    inactiveTrackColor: AppColors.accent.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: dia, min: 40, max: 130,
                    onChanged: (v) => setLocal(() => dia = v.roundToDouble()),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final existing = await HealthService.getTodayEntry();
                      final updated = (existing ?? HealthEntry(date: DateTime.now())).copyWith(
                        systolic: sys,
                        diastolic: dia,
                        source: 'manual',
                      );
                      await HealthService.saveHealthEntry(updated);
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadTodayData();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Kaydet', style: TextStyle(fontSize: 15)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  Widget _buildDiscoverGrid(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shortcuts = [
      _Shortcut(Icons.analytics_rounded, 'Raporlar', 'Haftalık analiz', const Color(0xFF8B5CF6), '/app/reports'),
      _Shortcut(Icons.shield_rounded, 'Risk Detayı', 'Skor detayları', AppColors.primary, '/app/risk-score'),
      _Shortcut(Icons.notifications_active_rounded, 'Uyarılar', 'Sağlık alerts', AppColors.accent, '/app/alerts'),
    ];

    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shortcuts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final s = shortcuts[i];
          return GestureDetector(
            onTap: () => context.go(s.path),
            child: Container(
              width: 130,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: s.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: s.color.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(s.icon, color: s.color, size: 22),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface)),
                      Text(s.sub, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernAnomalyBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.destructive.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.destructive.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.destructive, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sağlık Uyarısı!',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.destructive),
                ),
                Text(
                  _anomalyResult?.anomalies.first.description ?? 'Düzensiz metrik tespit edildi.',
                  style: TextStyle(fontSize: 13, color: AppColors.destructive.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.go('/app/alerts'),
            child: const Text('İncele', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          IconButton(
            onPressed: () => setState(() => _isAnomalyDismissed = true),
            icon: Icon(Icons.close, size: 18, color: AppColors.destructive.withValues(alpha: 0.6)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildWaterAndMoodSection(BuildContext context) {
    return Column(
      children: [
        _buildWaterTracker(context),
        const SizedBox(height: 16),
        _buildMoodTracker(context),
      ],
    );
  }

  Widget _buildWeeklyTrendCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Haftalık Risk Trendi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: cs.onSurface)),
              Row(
                children: _days.asMap().entries.take(7).map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(e.value, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: CustomPaint(
              size: const Size(double.infinity, 80),
              painter: AppLineChartPainter(data: _weeklyData, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterTracker(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final double currentMl = _todayEntry?.waterMl ?? 0;
    final double pct = (currentMl / _waterTarget).clamp(0.0, 1.0);
    final Color waterColor = const Color(0xFF3B82F6);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: waterColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.water_drop_rounded, color: waterColor, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text('Su Takibi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: cs.onSurface)),
                ],
              ),
              Text(
                '${currentMl.toInt()} / ${_waterTarget.toInt()} ml',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: waterColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 10,
                  backgroundColor: waterColor.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(waterColor),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Text(
                    '${(pct * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      color: pct > 0.4 ? Colors.white : waterColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Quick add buttons
          Row(
            children: [200, 330, 500].map((amount) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: amount == 500 ? 0 : 8),
                  child: InkWell(
                    onTap: () async {
                      await HealthService.updateWater(amount.toDouble());
                      _loadTodayData();
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: waterColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: waterColor.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.add_rounded, color: waterColor, size: 16),
                          const SizedBox(height: 2),
                          Text(
                            '${amount}ml',
                            style: TextStyle(color: waterColor, fontWeight: FontWeight.w600, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodTracker(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentMood = _todayEntry?.mood ?? 'neutral';
    final moods = [
      {'val': 'happy', 'emoji': '🤩', 'label': 'Harika'},
      {'val': 'good', 'emoji': '😊', 'label': 'İyi'},
      {'val': 'neutral', 'emoji': '😐', 'label': 'Normal'},
      {'val': 'tired', 'emoji': '😫', 'label': 'Yorgun'},
      {'val': 'stressed', 'emoji': '😵‍💫', 'label': 'Stresli'},
    ];

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.emoji_emotions_outlined, color: AppColors.accent, size: 16),
              ),
              const SizedBox(width: 8),
              Text('Bugün Nasılsın?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: cs.onSurface)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: moods.map((m) {
              final isSelected = currentMood == m['val'];
              return GestureDetector(
                onTap: () async {
                  await HealthService.updateMood(m['val']!);
                  _loadTodayData();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent.withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected ? Border.all(color: AppColors.accent.withValues(alpha: 0.3)) : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        m['emoji']!,
                        style: TextStyle(
                          fontSize: 24,
                          color: isSelected ? null : Colors.grey.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m['label']!,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? AppColors.accent : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _topFactorSummary() {
    final risk = _riskResult;
    if (risk == null) return 'Veri bekleniyor...';
    
    final negative = risk.topFactors
        .where((f) => f.contribution > 8)
        .map((f) => f.name)
        .take(2)
        .toList();
    if (negative.isEmpty) {
      return 'Tüm göstergeler iyi durumda. Harika gidiyorsunuz!';
    }
    return '${negative.join(', ')} dikkat gerektiriyor.';
  }
}

class _Shortcut {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final String path;
  const _Shortcut(this.icon, this.label, this.sub, this.color, this.path);
}
