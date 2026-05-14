import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/health_data.dart';
import '../services/health_service.dart';
import '../services/api_service.dart';
import '../services/user_profile_service.dart';
import '../constants/app_constants.dart';
import '../widgets/theme_aware_state.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/common_widgets.dart';
import '../widgets/dashboard/metrics_grid.dart';
import '../widgets/dashboard/water_tracker_card.dart';
import '../widgets/dashboard/mood_tracker_card.dart';
import '../widgets/dashboard/weekly_trend_card.dart';
import '../widgets/dashboard/anomaly_banner.dart';
import '../widgets/dashboard/discover_grid.dart';
import '../widgets/dashboard/bp_entry_sheet.dart';
import '../widgets/dashboard/stress_entry_sheet.dart';

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
  bool _initialLoadDone = false;
  DateTime? _lastSyncTime;

  // Bugünün Firestore'dan gelen verileri
  HealthEntry? _todayEntry;
  bool _isDataMissing = false;
  AnomalyApiResult? _anomalyResult; // Modül 7: Anomali Sonuçları
  bool _isAnomalyDismissed = false;
  StreamSubscription? _syncSubscription;
  StreamSubscription? _userSubscription;


  // Health Connect durum kontrolü
  String _hcStatus = 'checking'; // 'available', 'unavailable', 'update_required', 'error'
  bool _hcBannerDismissed = false;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Günaydın';
    if (hour >= 12 && hour < 18) return 'Tünaydın';
    if (hour >= 18 && hour < 22) return 'İyi Akşamlar';
    return 'İyi Geceler';
  }

  // ── Lifecycle ────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserName();
    _checkHealthConnectStatus();
    _silentSyncAndLoad();
    
    // Kullanıcı profil değişikliklerini dinle
    _userSubscription = FirebaseAuth.instance.userChanges().listen((user) {
      if (mounted) _loadUserName();
    });
    
    // Canlı veri güncellemelerini dinle
    _syncSubscription = HealthService.syncUpdates.listen((event) {
      if (mounted) {
        debugPrint("📡 Dashboard: Yeni veri algılandı, güncelleniyor...");
        _loadTodayData();
      }
    });


    
    // Uygulama yüklendikten sonra (frame render edildikten sonra) disclaimer kontrolü yap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMedicalDisclaimer();
    });
  }

  Future<void> _checkHealthConnectStatus() async {
    final status = await HealthService.checkHealthConnectStatus();
    if (mounted) {
      setState(() => _hcStatus = status);
    }
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
    _syncSubscription?.cancel();
    _userSubscription?.cancel();

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
      await HealthService.syncFromDevice();
      if (mounted) await _loadTodayData();
    } catch (e) {
      debugPrint("Sessiz senkronizasyon hatası: $e");
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      } else {
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

    try {
      final profile = await UserProfileService.getProfile();
      final pAge = profile?.age ?? AppConstants.defaultAge;
      final pHeight = profile?.height ?? AppConstants.defaultHeight;
      final pWeight = profile?.weight ?? AppConstants.defaultWeight;
      final pGender = profile?.gender ?? AppConstants.defaultGender;

      final entry = await HealthService.getTodayEntry();
      final todayData = entry ?? HealthEntry(date: DateTime.now());

      if (!mounted) return;

      if (entry != null) {
        setState(() {
          _todayEntry = entry;
          _isDataMissing = false;
        });
      } else {
        setState(() {
          _isDataMissing = true;
        });
      }

      // BESLENME ENTEGRASYONU (Tez Modül 5)
      final mealHistory = await ApiService.fetchMealHistory(limit: 100);
      final now = DateTime.now();
      final todayMeals = mealHistory.where((m) {
        final d = DateTime.parse(m.analyzedAt).toLocal();
        return d.year == now.year && d.month == now.month && d.day == now.day;
      }).toList();

      final consumedCals = todayMeals.fold(0.0, (s, m) => s + m.calories);
      final avgNutriScore = todayMeals.isEmpty 
          ? 70.0 
          : todayMeals.fold(0.0, (s, m) => s + m.healthScore) / todayMeals.length;

      try {
        final result = await ApiService.fetchRiskScore(
          RiskApiRequest(
            age: pAge,
            gender: pGender,
            height: pHeight,
            weight: pWeight,
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
            consumedCalories: consumedCals,
            nutritionScore: avgNutriScore,
          ),
        );

        if (result != null && mounted) {
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
      } catch (e) {
        debugPrint("Risk skoru hesaplama hatası: $e");
      }

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



      // Haftalık risk geçmişi (Backend API'den çek)
      try {
        final history = await ApiService.fetchRiskHistory(limit: 7);
        final latestScores = history.map((e) => e.score).toList();
        
        while (latestScores.length < 7) {
          latestScores.add(0.0);
        }
        
        if (mounted) {
          setState(() => _weeklyData = latestScores.reversed.toList());
        }
      } catch (e) {
        debugPrint('Haftalık risk geçmişi hatası: $e');
      }

    } catch (e) {
      debugPrint("_loadTodayData ana hata: $e");
    } finally {
      if (mounted) {
        setState(() {
          _initialLoadDone = true;
          _lastSyncTime = DateTime.now();
        });
      }
    }
  }

  Future<void> _handleManualSync() async {
    HapticFeedback.mediumImpact();
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

  String _calculateTrend() {
    if (_weeklyData.length < 2) return 'Stabil';
    final today = _weeklyData.last;
    final yesterday = _weeklyData[_weeklyData.length - 2];
    
    if (today > yesterday + 5) return 'Artıyor';
    if (today < yesterday - 5) return 'Azalıyor';
    return 'Stabil';
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/app/data-entry'),
        backgroundColor: AppColors.secondary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Veri Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        onRefresh: _silentSyncAndLoad,
        color: AppColors.primary,
        backgroundColor: Colors.white,
        strokeWidth: 3,
        displacement: 40,
        edgeOffset: 20,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildSliverHeader(context),
            if (!_initialLoadDone && _isSyncing)
              const SliverToBoxAdapter(child: DashboardShimmer())
            else if (_initialLoadDone && _todayEntry == null && _isDataMissing)
              SliverToBoxAdapter(child: _buildEmptyState(context))
            else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Health Connect kurulum banner'ı
                    if (_hcStatus != 'available' && _hcStatus != 'checking' && !_hcBannerDismissed) ...[
                      _buildHealthConnectBanner(context),
                      const SizedBox(height: 16),
                    ],
                    if (_anomalyResult?.hasAnomaly == true && !_isAnomalyDismissed) ...[
                      AnomalyBanner(
                        anomalyResult: _anomalyResult!,
                        onViewDetails: () => context.go('/app/alerts'),
                        onDismiss: () => setState(() => _isAnomalyDismissed = true),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildWellnessSummary(context),
                    const SizedBox(height: 12),
                    _buildDailySummaryCard(context),
                    const SizedBox(height: 12),
                    _buildSectionTitle(context, 'Günlük Metrikler', Icons.insights_rounded),
                    if (_lastSyncTime != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 4),
                        child: Text(
                          'Son güncelleme: ${_relativeTime(_lastSyncTime!)}',
                          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ),
                    DashboardMetricsGrid(
                      todayEntry: _todayEntry,
                      onBPTap: () => BPEntrySheet(todayEntry: _todayEntry, onSaved: _loadTodayData).show(context),
                      onStressTap: () => StressEntrySheet(todayEntry: _todayEntry, onSaved: _loadTodayData).show(context),
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
                    const SizedBox(height: 20),
                    _buildSectionTitle(context, 'Hızlı Keşfet', Icons.explore_outlined),
                    const SizedBox(height: 4),
                    const DiscoverGrid(),
                    const SizedBox(height: 24),
                    _buildSectionTitle(context, 'Haftalık Risk Trendi', Icons.trending_up_rounded),
                    const SizedBox(height: 4),
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
                  Row(
                    children: [
                      Text(
                        _greeting,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w400),
                      ),
                      if (_riskResult != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            color: _riskResult!.level.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
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
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(
            color: AppColors.primary.withValues(alpha: 0.1),
            thickness: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildDailySummaryCard(BuildContext context) {
    if (_todayEntry == null) return const SizedBox.shrink();
    
    final steps = _todayEntry!.steps;
    final sleep = _todayEntry!.sleepHours;
    
    String message = "Bugün hareketlisiniz, harika!";
    if (steps < 4000) {
      message = "Bugün biraz hareketsiz kaldınız, kısa bir yürüyüş iyi gelebilir.";
    } else if (steps > 8000 && sleep >= 7) {
      message = "Harika bir gün! Hem aktifsiniz hem de uykunuzu almışsınız.";
    } else if (sleep > 0 && sleep < 5) {
      message = "Dün gece az uyumuşsunuz, bugün kendinizi yormamaya çalışın.";
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 100),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.monitor_heart_outlined, size: 72, color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 24),
          Text(
            'Henüz Sağlık Verisi Yok',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cs.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Akıllı saatinizi bağlayarak otomatik veri çekebilir veya manuel olarak sağlık verilerinizi girebilirsiniz.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _handleManualSync,
                  icon: const Icon(Icons.watch_rounded, size: 18),
                  label: const Text('Saati Bağla'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/app/data-entry'),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Manuel Giriş'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    side: const BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthConnectBanner(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUpdate = _hcStatus == 'update_required';
    final bannerColor = isUpdate ? AppColors.accent : AppColors.primary;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            bannerColor.withValues(alpha: 0.12),
            bannerColor.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bannerColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bannerColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isUpdate ? Icons.system_update_rounded : Icons.health_and_safety_rounded,
                  color: bannerColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUpdate ? 'Health Connect Güncellemesi Gerekli' : 'Health Connect Gerekli',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cs.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isUpdate
                          ? 'Akıllı saatinizden veri almaya devam etmek için Health Connect\'i güncellemeniz gerekiyor.'
                          : 'Akıllı saat verilerinizi otomatik almak için Health Connect uygulamasını telefonunuza yükleyin.',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.4),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _hcBannerDismissed = true),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 18, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                const marketUrl = 'market://details?id=com.google.android.apps.healthdata';
                const webUrl = 'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata';
                final marketUri = Uri.parse(marketUrl);
                if (await canLaunchUrl(marketUri)) {
                  await launchUrl(marketUri, mode: LaunchMode.externalApplication);
                } else {
                  await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
                }
              },
              icon: Icon(isUpdate ? Icons.system_update_rounded : Icons.download_rounded, size: 18),
              label: Text(isUpdate ? 'Health Connect\'i Güncelle' : 'Play Store\'dan Yükle'),
              style: FilledButton.styleFrom(
                backgroundColor: bannerColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWellnessSummary(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final risk = _riskResult;
    final score = risk?.score.round() ?? 0;
    final color = risk?.level.color ?? AppColors.secondary;

    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.go('/app/risk-score'),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.02),
              ],
            ),
          ),
          child: Row(
            children: [
              // Skor Halkası
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 8,
                      backgroundColor: color.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        'PUAN',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 20),
              // Bilgi Bölümü
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Sağlık: ${risk?.level.label ?? "Hesaplanıyor"}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: cs.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_lastSyncTime != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              '${_lastSyncTime!.hour}:${_lastSyncTime!.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _topFactorSummary(),
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _calculateTrend() == 'Artıyor' 
                                ? Icons.trending_up_rounded 
                                : _calculateTrend() == 'Azalıyor'
                                    ? Icons.trending_down_rounded
                                    : Icons.trending_flat_rounded, 
                            size: 14, 
                            color: color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Risk seviyeniz ${_calculateTrend().toLowerCase()}.',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    return '${diff.inDays} gün önce';
  }
}

