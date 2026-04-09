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
import '../widgets/water_wave_widget.dart';

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
      // Uygulama açıldığında veya arkaplandan döndüğünde sessizce verileri eşitle
      await HealthService.syncFromDevice();
      // Ardından arayüzü güncelle
      if (mounted) {
        await _loadTodayData();
      }
    } finally {
      _isSyncing = false;
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

      // Cihaz verileri (steps, heartRate, sleepHours) manuel verilerden (manualSteps vb) üstündür.
      // KRİTİK: Eğer saat gece yarısı (00:00 - 02:00) ise ve cihazdan 0 veri geliyorsa, 
      // manuel veriyi SILME (çünkü kullanıcı daha yürümeye başlamamış ama dün manuel veri girmiş olabilir).
      final isEarlyMorning = DateTime.now().hour < 2;
      
      final steps = (todayData.steps > 0 || !isEarlyMorning) ? todayData.steps : (entry?.steps ?? 0);
      final heartRate = (todayData.heartRate > 0 || !isEarlyMorning) ? todayData.heartRate : (entry?.heartRate ?? 0);
      final sleepHours = (todayData.sleepHours > 0 || !isEarlyMorning) ? todayData.sleepHours : (entry?.sleepHours ?? 0);

      // Firestore'dan veri gelsin ya da gelmesin, mevcut profil bilgisiyle API hesaplamasini yap.
      final result = await ApiService.fetchRiskScore(
        RiskApiRequest(
          age: pAge,
          gender: pGender,
          height: pHeight,
          weight: profile?.weight ?? 70.0,
          steps: steps,
          sleepHours: sleepHours,
          systolic: todayData.systolic,
          diastolic: todayData.diastolic,
          heartRateResting: heartRate, // Dinlenik
          heartRateAvg: heartRate,     // Şimdilik aynı, pipeline'dan gelmeli
          spo2: todayData.spo2,
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
        // Metrik bazlı history map oluştur (Backend beklentisi: {'steps': [v1,v2...], 'heart_rate': [...]})
        final Map<String, List<double>> formattedHistory = {
          'steps': last7Days.map((e) => e.steps).toList(),
          'heart_rate': last7Days.map((e) => e.heartRate).toList(),
          'sleep_hours': last7Days.map((e) => e.sleepHours).toList(),
          'systolic': last7Days.map((e) => e.systolic).toList(),
          'diastolic': last7Days.map((e) => e.diastolic).toList(),
          'weight': last7Days.map((e) => e.weight).toList(),
        };

        final anomaly = await ApiService.checkAnomalies(
          history: formattedHistory,
          today: todayData.toJson(),
        );
        if (mounted) {
          setState(() => _anomalyResult = anomaly);
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

    final success = await HealthService.syncFromDevice();
    
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/app/data-entry'),
        backgroundColor: AppColors.primary,
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
      body: RefreshIndicator(
        onRefresh: _silentSyncAndLoad,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildSliverHeader(context),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_anomalyResult?.hasAnomaly == true) ...[
                      _buildModernAnomalyBanner(context),
                      const SizedBox(height: 20),
                    ],
                    _buildMainHealthGauge(context),
                    const SizedBox(height: 32),
                    _buildSectionTitle(context, 'Günlük Metrikler', Icons.insights_rounded),
                    const SizedBox(height: 12),
                    _buildMetricsGrid(context),
                    const SizedBox(height: 32),
                    _buildSectionTitle(context, 'Hızlı Keşfet', Icons.explore_outlined),
                    const SizedBox(height: 12),
                    _buildDiscoverGrid(context),
                    const SizedBox(height: 32),
                    _buildWaterAndMoodSection(context),
                    const SizedBox(height: 40),
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
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildMetricTile(
          context,
          'Adım',
          '${entry?.steps.toInt() ?? 0}',
          Icons.directions_walk_rounded,
          AppColors.primary,
          'Hedef: 10k',
        ),
        _buildMetricTile(
          context,
          'Nabız',
          entry?.heartRate != null ? '${entry!.heartRate.toInt()} bpm' : '--',
          Icons.favorite_rounded,
          AppColors.secondary,
          'Dinlenik',
        ),
        _buildMetricTile(
          context,
          'Uyku',
          '${entry?.sleepHours.toStringAsFixed(1) ?? 0} s',
          Icons.bedtime_rounded,
          Colors.indigo,
          'Kaliteli',
        ),
        _buildMetricTile(
          context,
          'Tansiyon',
          (entry?.systolic ?? 0) > 0 ? '${entry!.systolic.toInt()}/${entry.diastolic.toInt()}' : '--',
          Icons.speed_rounded,
          AppColors.destructive,
          'Normal',
        ),
      ],
    );
  }

  Widget _buildMetricTile(BuildContext context, String label, String value, IconData icon, Color color, String sub) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Text(sub, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      children: [
        _buildDiscoverItem(context, Icons.apple_rounded, 'Beslenme', AppColors.secondary, '/app/nutrition'),
        _buildDiscoverItem(context, Icons.fitness_center_rounded, 'Egzersiz', AppColors.primary, '/app/exercise'),
        _buildDiscoverItem(context, Icons.psychology_rounded, 'AI Asistan', AppColors.accent, '/app/assistant'),
        _buildDiscoverItem(context, Icons.analytics_rounded, 'Raporlar', Colors.purple, '/app/reports'),
      ],
    );
  }

  Widget _buildDiscoverItem(BuildContext context, IconData icon, String label, Color color, String path) {
    return GestureDetector(
      onTap: () => context.go(path),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        ],
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
        ],
      ),
    );
  }

  Widget _buildWaterAndMoodSection(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildWaterTracker(context)),
        const SizedBox(width: 16),
        Expanded(child: _buildMoodTracker(context)),
      ],
    );
  }

  Widget _buildWeeklyTrendCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Haftalık Trend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          SizedBox(
            height: 100,
            child: CustomPaint(
              size: const Size(double.infinity, 100),
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

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Su Takibi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: [
              WaterWaveWidget(currentMl: currentMl, targetMl: _waterTarget),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _buildWaterAddBtn(context, 200),
                    const SizedBox(height: 8),
                    _buildWaterAddBtn(context, 500),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaterAddBtn(BuildContext context, int amount) {
    return InkWell(
      onTap: () async {
        await HealthService.updateWater(amount.toDouble());
        _loadTodayData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text('+$amount', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildMoodTracker(BuildContext context) {
    final currentMood = _todayEntry?.mood ?? 'neutral';
    final moods = [
      {'val': 'happy', 'emoji': '🤩'},
      {'val': 'good', 'emoji': '😊'},
      {'val': 'neutral', 'emoji': '😐'},
      {'val': 'tired', 'emoji': '😫'},
      {'val': 'stressed', 'emoji': '😵‍💫'},
    ];

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Modun?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                child: Text(
                  m['emoji']!,
                  style: TextStyle(
                    fontSize: 22,
                    color: isSelected ? null : Colors.grey.withValues(alpha: 0.5),
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
