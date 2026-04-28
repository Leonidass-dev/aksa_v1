import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../models/health_data.dart';
import '../services/health_service.dart';
import '../services/api_service.dart';
import '../services/user_profile_service.dart';
import '../constants/app_constants.dart';
import '../widgets/theme_aware_state.dart';
import '../widgets/dashboard/health_gauge_card.dart';
import '../widgets/dashboard/metrics_grid.dart';
import '../widgets/dashboard/water_tracker_card.dart';
import '../widgets/dashboard/mood_tracker_card.dart';
import '../widgets/dashboard/weekly_trend_card.dart';
import '../widgets/dashboard/anomaly_banner.dart';
import '../widgets/dashboard/discover_grid.dart';
import '../widgets/dashboard/bp_entry_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with ThemeAwareMixin, WidgetsBindingObserver {

  RiskResult? _riskResult;
  List<double> _weeklyData = List.filled(7, 0.0);
  String _userName = 'Kullanıcı';
  double _waterTarget = 2000;
  bool _isSyncing = false;

  // Bugünün Firestore'dan gelen verileri
  HealthEntry? _todayEntry;
  bool _isDataMissing = false;
  AnomalyApiResult? _anomalyResult; // Modül 7: Anomali Sonuçları
  bool _isAnomalyDismissed = false;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Günaydın';
    if (hour < 18) return 'Tünaydın';
    return 'İyi Akşamlar';
  }

  // ── Lifecycle ────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserName();
    _silentSyncAndLoad();
    
    // Uygulama yüklendikten sonra (frame render edildikten sonra) disclaimer kontrolü yap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMedicalDisclaimer();
    });
  }

  Future<void> _checkMedicalDisclaimer() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_medical_disclaimer') ?? false;
    
    if (!hasSeen && mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false, // Kullanıcı kabul etmek zorunda
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.destructive),
              SizedBox(width: 8),
              Text('Tıbbi Uyarı'),
            ],
          ),
          content: const Text(
            'Bu uygulama yapay zeka destekli genel sağlık analizleri sunar '
            'ancak tıbbi bir teşhis, tedavi veya doktor tavsiyesi yerine geçmez.\n\n'
            'Herhangi bir sağlık sorununuzda mutlaka bir sağlık profesyoneline başvurunuz.',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                await prefs.setBool('has_seen_medical_disclaimer', true);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Anladım, Kabul Ediyorum'),
            ),
          ],
        ),
      );
    }
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

  // ── Data Loading ─────────────────────────────────────────────────

  Future<void> _silentSyncAndLoad() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      await Future.delayed(const Duration(milliseconds: 800));
      await HealthService.syncFromDevice();
      if (mounted) await _loadTodayData();
    } catch (e) {
      debugPrint("Sessiz senkronizasyon hatası: $e");
    } finally {
      if (mounted) _isSyncing = false;
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
    setState(() => _isSyncing = true);

    final profile = await UserProfileService.getProfile();
    final pAge = profile?.age ?? AppConstants.defaultAge;
    final pHeight = profile?.height ?? AppConstants.defaultHeight;
    final pWeight = profile?.weight ?? AppConstants.defaultWeight;
    final pGender = profile?.gender ?? AppConstants.defaultGender;

    final entry = await HealthService.getTodayEntry();
    final todayData = entry ?? HealthEntry(date: DateTime.now());

    if (mounted) {
      if (entry != null) {
        setState(() {
          _todayEntry = entry;
          _isDataMissing = (entry.steps == 0 && entry.heartRate == 0);
        });
      } else {
        setState(() {
          _isDataMissing = true;
        });
      }

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
              : todayData.heartRate,
          heartRateAvg: todayData.heartRate,
          spo2: todayData.spo2,
          stressLevel: todayData.stressLevel,
        ),
      );

      if (mounted) {
        setState(() => _waterTarget = HealthService.calculateWaterTarget(pWeight, todayData.activeCalories));
      }

      // MODÜL 7: ANOMALİ TESPİTİ
      try {
        final last7Days = await HealthService.getLastNDays(7);
        final formattedHistory = last7Days.map((e) {
          final json = e.toJson();
          json.remove('updated_at');
          json['date'] ??= DateTime.now().toIso8601String();
          return json;
        }).toList();

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
            _isAnomalyDismissed = false;
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
                .map((f) => RiskFactor(name: f.name, contribution: f.contribution, description: f.description))
                .toList(),
            modelVersion: result.modelVersion,
            windowEnd: DateTime.now(),
          );
        });
      }

      // Haftalık risk geçmişi
      try {
        final historyDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('risk_history')
            .orderBy('timestamp', descending: true)
            .limit(7)
            .get();
        final latestScores = <double>[];
        for (var doc in historyDoc.docs) {
          final s = doc.data()['score'] as num?;
          if (s != null) latestScores.add(s.toDouble());
        }
        while (latestScores.length < 7) latestScores.add(0.0);
        if (mounted) setState(() => _weeklyData = latestScores.reversed.toList());
      } catch (e) {
        debugPrint('Haftalık risk geçmişi hatası: $e');
      }

      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _handleManualSync() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
          SizedBox(width: 12),
          Text('Akıllı saatten veri çekiliyor...'),
        ]),
        duration: Duration(seconds: 3),
        backgroundColor: AppColors.primary,
      ),
    );

    final ok = await HealthService.syncFromDevice(force: true);
    if (mounted) await _loadTodayData();

    if (ok) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Veri başarıyla güncellendi! ✅'), backgroundColor: AppColors.secondary),
      );
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Veri çekilemedi. Health Connect izinlerini kontrol edin. ❌'), backgroundColor: Colors.redAccent),
      );
    }
  }

  String _topFactorSummary() {
    final risk = _riskResult;
    if (risk == null) return 'Veri bekleniyor...';
    final negative = risk.topFactors
        .where((f) => f.contribution > 8)
        .map((f) => f.name)
        .take(2)
        .toList();
    if (negative.isEmpty) return 'Tüm göstergeler iyi durumda. Harika gidiyorsunuz!';
    return '${negative.join(', ')} dikkat gerektiriyor.';
  }

  // ── UI Build ─────────────────────────────────────────────────────

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
                      AnomalyBanner(
                        anomalyResult: _anomalyResult!,
                        onViewDetails: () => context.go('/app/alerts'),
                        onDismiss: () => setState(() => _isAnomalyDismissed = true),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_isDataMissing) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Güncel sağlık verisi bulunamadı. Lütfen saatinizi senkronize edin.',
                                style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    HealthGaugeCard(
                      riskResult: _riskResult,
                      factorSummary: _topFactorSummary(),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle(context, 'Günlük Metrikler', Icons.insights_rounded),
                    const SizedBox(height: 10),
                    DashboardMetricsGrid(
                      todayEntry: _todayEntry,
                      onBPTap: () => BPEntrySheet(todayEntry: _todayEntry, onSaved: _loadTodayData).show(context),
                    ),
                    const SizedBox(height: 24),
                    WaterTrackerCard(
                      currentMl: _todayEntry?.waterMl ?? 0,
                      targetMl: _waterTarget,
                      onAddWater: (amount) async {
                        await HealthService.updateWater(amount);
                        _loadTodayData();
                      },
                    ),
                    const SizedBox(height: 16),
                    MoodTrackerCard(
                      currentMood: _todayEntry?.mood ?? 'neutral',
                      onMoodSelected: (mood) async {
                        await HealthService.updateMood(mood);
                        _loadTodayData();
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle(context, 'Hızlı Keşfet', Icons.explore_outlined),
                    const SizedBox(height: 10),
                    const DiscoverGrid(),
                    const SizedBox(height: 24),
                    WeeklyTrendCard(weeklyData: _weeklyData),
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
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w400),
                  ),
                  Text(
                    _userName,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
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
              right: 6, top: 6,
              child: Container(
                width: 8, height: 8,
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
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
      ],
    );
  }
}
