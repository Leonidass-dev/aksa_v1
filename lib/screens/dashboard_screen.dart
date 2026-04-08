import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../models/health_data.dart';
import '../services/health_service.dart';
import '../services/api_service.dart';
import '../services/user_profile_service.dart';
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
  bool _loadingRisk = true;
  String _userName = '';
  double _waterTarget = 2000;


  // Bugünün Firestore'dan gelen verileri
  HealthEntry? _todayEntry;

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
    if (state == AppLifecycleState.resumed) {
      _silentSyncAndLoad();
    }
  }

  Future<void> _silentSyncAndLoad() async {
    // Uygulama açıldığında veya arkaplandan döndüğünde sessizce verileri eşitle
    await HealthService.syncFromDevice();
    // Ardından arayüzü güncelle
    if (mounted) {
      _loadTodayData();
    }
  }

  void _loadUserName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userName =
            user.displayName?.split(' ').first ??
            user.email?.split('@').first ??
            'Kullanıcı';
      });
    }
  }

  Future<void> _loadTodayData() async {
    setState(() => _loadingRisk = true);

    final profile = await UserProfileService.getProfile();
    final pAge = profile?.age ?? 30;
    final pHeight = profile?.height ?? 170.0;
    final pGender = profile?.gender ?? 'M';
    final pWeight = profile?.weight ?? 70.0;

    final entry = await HealthService.getTodayEntry();
    final todayData = entry ?? HealthEntry(date: DateTime.now());

    if (mounted) {
      if (entry != null) setState(() => _todayEntry = entry);

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
          heartRateResting: todayData.heartRate,
          spo2: todayData.spo2,
        ),
      );

      if (mounted) {
        setState(() {
          _waterTarget = HealthService.calculateWaterTarget(pWeight);
        });
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


  Color get _levelColor {
    if (_riskResult == null) return AppColors.primary;
    return _riskResult!.level.color;
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
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _buildQuickActions(context),
                  const SizedBox(height: 20),
                  _buildWaterTracker(context),
                  const SizedBox(height: 20),
                  _buildMoodTracker(context),
                  const SizedBox(height: 20),
                  _buildWeeklyTrend(context),
                  const SizedBox(height: 20),
                  _buildTodayActivity(context),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.only(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_greeting,',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _userName.isEmpty ? 'Kullanici' : _userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.go('/app/data-entry'),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => context.go('/app/alerts'),
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.notifications_none_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bugünün Sağlık Özeti',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.go('/app/risk-score'),
                          child: Text(
                            'Detaylar',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        SizedBox(
                          width: 88,
                          height: 88,
                          child: (_loadingRisk || _riskResult == null)
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 88,
                                      height: 88,
                                      child: CircularProgressIndicator(
                                        value: _riskResult!.score / 100,
                                        strokeWidth: 8,
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.2),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              _levelColor,
                                            ),
                                        strokeCap: StrokeCap.round,
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${_riskResult!.score.toInt()}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Skor',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.6,
                                            ),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _levelColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _riskResult?.level.label ?? '-',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _todayEntry != null && _riskResult != null
                                    ? '${_todayEntry!.steps.toInt()} adım • ${_todayEntry!.sleepHours.toStringAsFixed(1)} saat uyku'
                                    : (_riskResult != null
                                          ? _topFactorSummary()
                                          : 'Veri bekleniyor...'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _topFactorSummary() {
    if (_riskResult == null) return 'Veri bekleniyor...';
    final negative = _riskResult!.topFactors
        .where((f) => f.contribution > 8)
        .map((f) => f.name)
        .take(2)
        .toList();
    if (negative.isEmpty) {
      return 'Tüm göstergeler iyi durumda. Harika gidiyorsunuz!';
    }
    return '${negative.join(', ')} dikkat gerektiriyor.';
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.apple_outlined,
        label: 'Beslenme',
        subtitle: 'Öğün planı',
        color: AppColors.secondary,
        path: '/app/nutrition',
      ),
      _QuickAction(
        icon: Icons.fitness_center_outlined,
        label: 'Egzersiz',
        subtitle: 'Antrenman',
        color: AppColors.primary,
        path: '/app/exercise',
      ),
      _QuickAction(
        icon: Icons.description_outlined,
        label: 'Raporlar',
        subtitle: 'Analizler',
        color: AppColors.accent,
        path: '/app/reports',
      ),
      _QuickAction(
        icon: Icons.warning_amber_outlined,
        label: 'Uyarılar',
        subtitle: 'Anomali tespiti',
        color: AppColors.destructive,
        path: '/app/alerts',
      ),
    ];
    final screenWidth = MediaQuery.of(context).size.width;
    // Calculate aspect ratio dynamically based on screen width
    // Narrower screens need a smaller ratio (more height)
    final double dynamicAspectRatio = screenWidth < 360 ? 1.1 : 1.3;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: dynamicAspectRatio,
      children: actions.map((a) => _buildActionCard(context, a)).toList(),
    );
  }

  Widget _buildActionCard(BuildContext context, _QuickAction action) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => context.go(action.path),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIconBadge(icon: action.icon, color: action.color),
            const Spacer(),
            Text(
              action.label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              action.subtitle,
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyTrend(BuildContext context) {
    if (_weeklyData.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final trendPct = _weeklyData.length >= 2
        ? ((_weeklyData.last - _weeklyData.first) / _weeklyData.first * 100)
              .abs()
        : 0.0;
    final trendUp = _weeklyData.last >= _weeklyData.first;

    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Haftalık Trend',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bu haftaki sağlık skorunuz',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    trendUp ? Icons.trending_up : Icons.trending_down,
                    color: trendUp
                        ? AppColors.secondary
                        : AppColors.destructive,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${trendUp ? "+" : "-"}${trendPct.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: trendUp
                          ? AppColors.secondary
                          : AppColors.destructive,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: CustomPaint(
              size: const Size(double.infinity, 80),
              painter: AppLineChartPainter(
                data: _weeklyData,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _days
                .map(
                  (d) => Text(
                    d,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayActivity(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final int hr = _todayEntry?.heartRate.toInt() ?? 0;
    final int steps = _todayEntry?.steps.toInt() ?? 0;
    final int kcal = (steps * 0.04).toInt(); // basit kalori hesabi

    final stats = [
      _Stat(
        icon: Icons.favorite_outline,
        color: AppColors.secondary,
        title: 'Kalp Atışı',
        subtitle: 'Ortalama',
        value: hr > 0 ? '$hr bpm' : '--',
      ),
      _Stat(
        icon: Icons.directions_walk_outlined,
        color: AppColors.primary,
        title: 'Adım',
        subtitle: 'Bugün',
        value: steps > 0 ? '$steps' : '--',
      ),
      _Stat(
        icon: Icons.local_fire_department_outlined,
        color: AppColors.accent,
        title: 'Kalori',
        subtitle: 'Yakılan (Tahmini)',
        value: kcal > 0 ? '$kcal kcal' : '--',
      ),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bugünün Aktivitesi',
            style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
          ),
          const SizedBox(height: 16),
          ...stats.map(
            (stat) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  AppIconBadge(icon: stat.icon, color: stat.color, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stat.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          stat.subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    stat.value,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
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

  Widget _buildWaterTracker(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final double currentMl = _todayEntry?.waterMl ?? 0;

    return AppCard(
      child: Row(
        children: [
          WaterWaveWidget(currentMl: currentMl, targetMl: _waterTarget),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Su Takibi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  'Hedef: ${_waterTarget.toInt()} ml',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildWaterAddBtn(context, 200),
                    _buildWaterAddBtn(context, 500),
                  ],
                ),
              ],
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              '$amount ml',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Modun Nasıl?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: cs.onSurface,
            ),
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
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                        ),
                      ),
                      child: Text(m['emoji']!, style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m['label']!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.primary : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label, subtitle, path;
  final Color color;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.path,
  });
}

class _Stat {
  final IconData icon;
  final Color color;
  final String title, subtitle, value;
  const _Stat({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
  });
}
