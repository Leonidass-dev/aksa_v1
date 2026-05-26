import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/health_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/theme_aware_state.dart';
import '../widgets/shimmer_loading.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/user_profile_service.dart';
import '../services/api_service.dart';
import '../models/api_models.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with ThemeAwareMixin {
  String _activeTab = 'genel';
  String _timeframe = 'week';

  final _tabs = const [
    _Tab('genel', 'Genel'),
    _Tab('steps', 'Adım'),
    _Tab('heart_rate', 'Nabız'),
    _Tab('sleep', 'Uyku'),
    _Tab('risk', 'Risk'),
    _Tab('ilerleme', 'İlerleme'),
  ];

  Map<String, List<double>> _chartData = const {
    'steps': [],
    'heart_rate': [],
    'sleep': [],
    'risk': [],
    'genel': [0.1, 0.1, 0.1, 0.1, 0.1],
  };

  List<String> _labels = [];
  bool _loadingData = true;
  bool _hasData = false;

  // Genel sekme istatistikleri
  double _overallScore = 0;
  String _bestCategory = '-';

  // AI Haftalık Digest
  WeeklyDigestResponse? _weeklyDigest;
  bool _loadingDigest = false;

  // İlerleme Özeti
  ProgressSummaryResponse? _progressSummary;
  bool _loadingProgress = false;

  @override
  void initState() {
    super.initState();
    _loadFromFirestore();
    _loadWeeklyDigest();
    _loadProgressSummary();
  }

  Future<void> _loadWeeklyDigest() async {
    setState(() => _loadingDigest = true);
    try {
      final result = await ApiService.fetchWeeklyDigest();
      if (mounted) {
        setState(() {
          _weeklyDigest = result;
          _loadingDigest = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDigest = false);
    }
  }

  Future<void> _loadProgressSummary() async {
    setState(() => _loadingProgress = true);
    try {
      final result = await ApiService.fetchProgressSummary(days: 30);
      if (mounted) {
        setState(() {
          _progressSummary = result;
          _loadingProgress = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProgress = false);
    }
  }

  Future<void> _loadFromFirestore() async {
    setState(() => _loadingData = true);
    int days = 7;
    if (_timeframe == 'month') {
      days = 30;
    } else if (_timeframe == '3_months') {
      days = 90;
    } else if (_timeframe == 'year') {
      days = 365;
    }
    
    final entries = await HealthService.getLastNDays(days);

    if (entries.isEmpty) {
      if (mounted) {
        setState(() {
          _loadingData = false;
          _hasData = false;
        });
      }
      return;
    }

    // Eskiden yeniye sırala
    final sorted = entries.reversed.toList();

    final labels = sorted.map((e) {
      final d = e.date;
      return '${d.day}/${d.month}';
    }).toList();

    // Risk: backend geçmişi (dashboard ile aynı); yoksa basit yerel özet
    List<double> riskData = [];
    try {
      final riskHistory = await ApiService.fetchRiskHistory(limit: days);
      if (riskHistory.isNotEmpty) {
        riskData = riskHistory
            .map((e) => e.score)
            .where((s) => s > 0)
            .toList()
            .reversed
            .toList();
      }
    } catch (_) {}
    if (riskData.isEmpty) {
      riskData = sorted.map((e) {
        double r = 10.0;
        if (e.steps > 0) r += ((10000 - e.steps) / 10000 * 15).clamp(0, 15);
        if (e.sleepHours > 0 && e.sleepHours < 6) r += (6 - e.sleepHours) * 3;
        if (e.heartRate > 100) r += (e.heartRate - 100) * 0.5;
        if (e.systolic > 130) r += (e.systolic - 130) * 0.5;
        return r.clamp(0.0, 100.0);
      }).toList();
    } else {
      while (riskData.length < sorted.length) {
        riskData.insert(0, 0.0);
      }
      if (riskData.length > sorted.length) {
        riskData = riskData.sublist(riskData.length - sorted.length);
      }
    }

    // Radar verisini de burada hesapla (setState dışında async çalışsın)
    final profile = await UserProfileService.getProfile();
    final weight = profile?.weight ?? 70.0;
    final waterTarget = HealthService.calculateWaterTarget(weight, 0.0);

    double avgSteps = 0, avgSleep = 0, avgWater = 0, avgRh = 0, avgRisk = 0;
    int count = sorted.length;

    for (var e in sorted) {
      avgSteps += e.steps;
      avgSleep += e.sleepHours;
      avgWater += e.waterMl;
      avgRh += e.restingHeartRate > 0 ? e.restingHeartRate : (e.heartRate > 0 ? e.heartRate : 70);
      avgRisk += (e.systolic > 0 ? (e.systolic - 90) * 0.5 : 20.0);
    }

    avgSteps /= count;
    avgSleep /= count;
    avgWater /= count;
    avgRh /= count;
    avgRisk /= count;

    final radarValues = [
      (avgSteps / 10000).clamp(0.05, 1.0),       // Adım (Hedef 10k, min 0.05 görsel için)
      (avgSleep / 8).clamp(0.05, 1.0),            // Uyku (Hedef 8s)
      (avgWater / waterTarget).clamp(0.05, 1.0),  // Su (Hedef Dinamik)
      (1 - ((avgRh - 60) / 40)).clamp(0.05, 1.0), // Kalp
      (1 - (avgRisk / 100)).clamp(0.05, 1.0),     // Risk
    ];

    // Genel skor & en iyi kategori
    final overallScore = radarValues.reduce((a, b) => a + b) / radarValues.length * 100;
    final categoryNames = ['Adım', 'Uyku', 'Su', 'Kalp', 'Risk'];
    int bestIdx = 0;
    for (int i = 1; i < radarValues.length; i++) {
      if (radarValues[i] > radarValues[bestIdx]) bestIdx = i;
    }

    if (mounted) {
      setState(() {
        _labels = labels;
        _hasData = true;
        _chartData = {
          'steps': sorted.map((e) => e.steps).toList(),
          'heart_rate': sorted.map((e) => e.heartRate).toList(),
          'sleep': sorted.map((e) => e.sleepHours).toList(),
          'risk': riskData,
          'genel': radarValues,
        };
        _overallScore = overallScore;
        _bestCategory = categoryNames[bestIdx];
        _loadingData = false;
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
            if (_loadingData)
              const Padding(
                padding: EdgeInsets.all(24),
                child: ShimmerLoading(
                  showHeader: true,
                  itemCount: 3,
                  itemHeight: 120,
                ),
              )
            else if (!_hasData)
              _buildEmptyState(context)
            else
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildWeeklySummaryCard(context),
                    const SizedBox(height: 20),
                    if (_labels.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_labels.first} – ${_labels.last}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            GestureDetector(
                              onTap: _loadFromFirestore,
                              child: const Icon(
                                Icons.refresh,
                                size: 18,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    _buildTabs(context),
                    const SizedBox(height: 16),
                    if (_activeTab == 'ilerleme')
                      _buildProgressTab(context)
                    else ...[
                      _buildChart(context),
                      const SizedBox(height: 20),
                      _buildStats(context),
                      const SizedBox(height: 20),
                      _buildInsights(context),
                    ],
                    const SizedBox(height: 20),
                    // AI Haftalık Değerlendirme
                    _buildAiDigestCard(context),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bar_chart_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz Yeterli Veri Yok',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Raporları görebilmek için en az 1 günlük\nsağlık verisi gerekiyor.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return AppHeader(
      title: 'Sağlık Raporları',
      subtitle: 'Veri görselleştirme ve analitik',
      bottomContent: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children:
              [
                {'id': 'week', 'label': 'Hafta'},
                {'id': 'month', 'label': 'Ay'},
                {'id': '3_months', 'label': '3 Ay'},
                {'id': 'year', 'label': 'Yıl'},
              ].map((t) {
                final String id = t['id'] as String;
                final String label = t['label'] as String;
                final isActive = _timeframe == id;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _timeframe = id);
                      _loadFromFirestore();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isActive ? AppColors.primary : Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _tabs.map((tab) {
          final isActive = _activeTab == tab.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = tab.id),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? AppColors.primary : cs.outlineVariant,
                  ),
                ),
                child: Text(
                  tab.label,
                  style: TextStyle(
                    color: isActive ? Colors.white : cs.onSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_activeTab == 'genel') {
      return _buildRadarChart(context);
    }

    final data = _chartData[_activeTab] ?? [];

    // Veri kontrolü: Eğer tüm değerler 0 ise "veri yok" göster
    if (data.isEmpty || !data.any((d) => d > 0)) {
      return AppCard(
        child: SizedBox(
          height: 160,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.show_chart, size: 40, color: cs.outlineVariant),
                const SizedBox(height: 8),
                Text(
                  'Bu metrik için veri bulunamadı',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    final color = _activeTab == 'sleep'
        ? AppColors.accent
        : _activeTab == 'heart_rate'
        ? AppColors.destructive
        : _activeTab == 'steps'
        ? AppColors.secondary
        : AppColors.primary;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_tabs.firstWhere((t) => t.id == _activeTab, orElse: () => _tabs.first).label} Trendi',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    _timeframe == 'month' ? 'Son 30 günün özeti' : 'Son 7 günün özeti',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              _buildTrendIndicator(data),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Builder(builder: (context) {
              // BUG-22 Çözümü: Tek veri noktası olduğunda grafiğin patlamaması için veriyi çoğalt
              final displayData = data.length == 1 ? [data.first, data.first] : data;
              final maxX = (displayData.length - 1).toDouble();

              return LineChart(
                LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _getInterval(_activeTab, displayData),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: _timeframe == 'month' ? 5 : 1,
                      getTitlesWidget: (value, meta) {
                        int idx = value.toInt();
                        if (data.length == 1 && idx == 1) idx = 0; // Tek veri varsa etiketi de kopyala
                        
                        if (idx >= 0 && idx < _labels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _labels[idx],
                              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: _getInterval(_activeTab, displayData),
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10),
                          textAlign: TextAlign.right,
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: maxX,
                minY: _getMinY(_activeTab, displayData),
                maxY: _getMaxY(_activeTab, displayData),
                lineBarsData: [
                  LineChartBarData(
                    spots: displayData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                    isCurved: true,
                    gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: data.length < 15,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 3,
                        strokeColor: color,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.0)],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => cs.surfaceContainerHighest,
                    tooltipRoundedRadius: 12,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((s) {
                        return LineTooltipItem(
                          '${s.y.toInt()}${_getUnit(_activeTab)}',
                          TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  double _getInterval(String tab, List<double> data) {
    if (tab == 'steps') return 2500;
    if (tab == 'heart_rate') return 20;
    if (tab == 'sleep') return 2;
    return 20;
  }

  double _getMinY(String tab, List<double> data) {
    if (tab == 'steps') return 0;
    if (tab == 'heart_rate') return 40;
    if (tab == 'sleep') return 0;
    return 0;
  }

  double _getMaxY(String tab, List<double> data) {
    if (data.isEmpty) return 100;
    final max = data.reduce((a, b) => a > b ? a : b);
    if (tab == 'steps') return max < 10000 ? 12000 : max * 1.2;
    return max * 1.2;
  }

  String _getUnit(String tab) {
    if (tab == 'steps') return ' adım';
    if (tab == 'heart_rate') return ' bpm';
    if (tab == 'sleep') return ' sa';
    return '';
  }

  Widget _buildRadarChart(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radarData = _chartData['genel']!;

    return AppCard(
      child: Column(
        children: [
          const Text(
            'Sağlık Dengesi Özeti',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            _timeframe == 'month'
                ? 'Son 30 günlük ortalama dağılımınız'
                : 'Haftalık ortalama verilerinizin dağılımı',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 240,
            child: RadarChart(
              RadarChartData(
                radarShape: RadarShape.polygon,
                dataSets: [
                  RadarDataSet(
                    fillColor: AppColors.primary.withValues(alpha: 0.2),
                    borderColor: AppColors.primary,
                    entryRadius: 3,
                    dataEntries: radarData.map((e) => RadarEntry(value: e)).toList(),
                  ),
                ],
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                radarBorderData: const BorderSide(color: Colors.transparent),
                titlePositionPercentageOffset: 0.15,
                titleTextStyle: TextStyle(color: cs.onSurface, fontSize: 11),
                getTitle: (index, angle) {
                  final pct = (radarData.length > index ? radarData[index] * 100 : 0).toInt();
                  switch (index) {
                    case 0: return RadarChartTitle(text: 'Adım\n%$pct');
                    case 1: return RadarChartTitle(text: 'Uyku\n%$pct');
                    case 2: return RadarChartTitle(text: 'Su\n%$pct');
                    case 3: return RadarChartTitle(text: 'Kalp\n%$pct');
                    case 4: return RadarChartTitle(text: 'Risk\n%$pct');
                    default: return const RadarChartTitle(text: '');
                  }
                },
                tickCount: 4,
                ticksTextStyle: const TextStyle(color: Colors.transparent),
                gridBorderData: BorderSide(color: cs.outlineVariant, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String avg = '-';
    String best = '-';
    String avgLabel = 'Ortalama';
    String bestLabel = 'En İyi';

    final data = _chartData[_activeTab] ?? [];
    if (_activeTab == 'genel') {
      // Genel sekmede özel istatistikler göster
      avg = '${_overallScore.toInt()}%';
      best = _bestCategory;
      avgLabel = 'Genel Skor';
      bestLabel = 'En İyi Alan';
    } else if (data.isNotEmpty && data.any((d) => d > 0)) {
      final validData = data.where((d) => d > 0).toList();
      if (validData.isNotEmpty) {
        final average = validData.reduce((a, b) => a + b) / validData.length;
        if (_activeTab == 'steps') {
          final maxSteps = validData.reduce((a, b) => a > b ? a : b);
          avg = '${average.toInt()} adım';
          best = '${maxSteps.toInt()} adım';
        } else if (_activeTab == 'heart_rate') {
          final minHR = validData.reduce((a, b) => a < b ? a : b);
          avg = '${average.toInt()} bpm';
          best = '${minHR.toInt()} bpm'; // En düşük (dinlenme) nabız daha iyidir
          bestLabel = 'En Düşük';
        } else if (_activeTab == 'sleep') {
          final maxS = validData.reduce((a, b) => a > b ? a : b);
          avg = '${average.toStringAsFixed(1)} saat';
          best = '${maxS.toStringAsFixed(1)} saat';
        } else if (_activeTab == 'risk') {
          final minR = validData.reduce((a, b) => a < b ? a : b);
          avg = average.toStringAsFixed(1);
          best = minR.toStringAsFixed(1); // En düşük risk daha iyidir
          bestLabel = 'En Düşük Risk';
        }
      }
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'İstatistik Özeti',
            style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        avgLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        avg,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bestLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        best,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Comparative metric
          if (_activeTab != 'genel' && _timeframe == 'week' && data.length > 3)
            Builder(builder: (context) {
              // Verinin ilk yarısı vs ikinci yarısı karşılaştırması
              final half = data.length ~/ 2;
              final firstHalf = data.sublist(0, half);
              final secondHalf = data.sublist(half);
              final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
              final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;
              
              if (firstAvg == 0) return const SizedBox.shrink();
              
              final changePercent = ((secondAvg - firstAvg) / firstAvg * 100).round().abs();
              final isImproved = secondAvg >= firstAvg;
              final trendIcon = isImproved ? Icons.trending_up : Icons.trending_down;
              final trendColor = isImproved ? AppColors.secondary : AppColors.accent;
              final trendText = isImproved
                  ? 'Dönem başına göre %$changePercent artış gösteriliyor'
                  : 'Dönem başına göre %$changePercent azalış gösteriliyor';

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: trendColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(trendIcon, color: trendColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trendText,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildInsights(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    // Veriye göre dinamik içgörüler oluştur
    final data = _chartData[_activeTab] ?? [];
    final validData = data.where((d) => d > 0).toList();
    
    List<_Insight> insights;
    
    if (_activeTab == 'genel') {
      final weakest = _chartData['genel']!;
      int worstIdx = 0;
      for (int i = 1; i < weakest.length; i++) {
        if (weakest[i] < weakest[worstIdx]) worstIdx = i;
      }
      final worstNames = ['Adım sayısı', 'Uyku düzeni', 'Su tüketimi', 'Kalp sağlığı', 'Risk yönetimi'];
      insights = [
        _Insight(
          AppColors.secondary,
          'Genel sağlık skorunuz: ${_overallScore.toInt()}%. En güçlü alanınız: $_bestCategory.',
        ),
        _Insight(
          AppColors.accent,
          'Gelişim alanı: ${worstNames[worstIdx]}. Bu alandaki hedeflerinize odaklanmanız genel skorunuzu yükseltecektir.',
        ),
      ];
    } else if (_activeTab == 'steps') {
      final avg = validData.isNotEmpty ? validData.reduce((a, b) => a + b) / validData.length : 0;
      insights = [
        _Insight(
          avg >= 8000 ? AppColors.secondary : AppColors.accent,
          avg >= 8000
              ? 'Harika! Ortalama ${avg.toInt()} adımla günlük hedefinize yakınsınız. Bu istikrarı koruyun.'
              : 'Ortalama ${avg.toInt()} adım. Günlük 10.000 hedefi için kısa yürüyüşler eklemeyi deneyin.',
        ),
      ];
    } else if (_activeTab == 'heart_rate') {
      final avg = validData.isNotEmpty ? validData.reduce((a, b) => a + b) / validData.length : 0;
      insights = [
        _Insight(
          avg > 0 && avg < 100 ? AppColors.secondary : AppColors.destructive,
          avg > 0
              ? 'Ortalama nabzınız ${avg.toInt()} bpm. ${avg < 80 ? "Bu sağlıklı bir aralıktır." : "Stres yönetimi ve düzenli egzersiz nabzınızı düşürebilir."}'
              : 'Nabız verisi henüz kaydedilmemiş. Saatinizin nabız ölçümünün açık olduğundan emin olun.',
        ),
      ];
    } else if (_activeTab == 'sleep') {
      final avg = validData.isNotEmpty ? validData.reduce((a, b) => a + b) / validData.length : 0;
      insights = [
        _Insight(
          avg >= 7 ? AppColors.secondary : AppColors.accent,
          avg > 0
              ? 'Ortalama ${avg.toStringAsFixed(1)} saat uyku. ${avg >= 7 ? "Yetişkinler için önerilen 7-9 saat aralığındasınız." : "Hedef 7-9 saat. Uyku düzeninizi iyileştirmeye çalışın."}'
              : 'Uyku verisi henüz kaydedilmemiş.',
        ),
      ];
    } else {
      insights = [
        const _Insight(
          AppColors.primary,
          'Risk skoru adım, uyku, nabız ve tansiyon verilerinize göre hesaplanır. Düşük skor daha iyidir.',
        ),
      ];
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.05),
            AppColors.secondary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Yapay Zeka Yorumları',
                style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...insights.map(
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      i.text,
                      style: TextStyle(fontSize: 13, color: cs.onSurface),
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
  Widget _buildWeeklySummaryCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Haftalık Özet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _summaryItem(
                'Genel Skor',
                '${_overallScore.toInt()}%',
                Icons.analytics_outlined,
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              _summaryItem(
                'En İyi Alan',
                _bestCategory,
                Icons.star_outline,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Son 7 günde sağlık dengeniz ${_overallScore > 70 ? "gayet iyi" : "geliştirilebilir"} durumda. $_bestCategory verileriniz bu haftanın yıldızı oldu!',
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // AI HAFTALIK DEĞERLENDİRME KARTI
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAiDigestCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loadingDigest) {
      return const ShimmerLoading(
        showHeader: false,
        itemCount: 1,
        itemHeight: 180,
      );
    }

    if (_weeklyDigest == null) {
      return const SizedBox.shrink();
    }

    final digest = _weeklyDigest!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6366F1).withValues(alpha: 0.08),
            const Color(0xFF8B5CF6).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Haftalık Değerlendirme',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      '${digest.periodStart} — ${digest.periodEnd}',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: _loadingDigest ? null : _loadWeeklyDigest,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            digest.digest,
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: cs.outlineVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _digestStatItem(
                Icons.directions_walk_rounded,
                '${digest.avgSteps.toInt()}',
                'Ort. Adım',
                AppColors.secondary,
              ),
              _digestStatItem(
                Icons.bedtime_rounded,
                '${digest.avgSleep.toStringAsFixed(1)}s',
                'Ort. Uyku',
                AppColors.accent,
              ),
              _digestStatItem(
                Icons.restaurant_rounded,
                '${digest.totalMeals}',
                'Öğün',
                AppColors.primary,
              ),
              _digestStatItem(
                Icons.fitness_center_rounded,
                '${digest.totalExercises}',
                'Egzersiz',
                const Color(0xFF8B5CF6),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _digestStatItem(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: cs.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // İLERLEME SEKMESİ
  // ═══════════════════════════════════════════════════════════════

  Widget _buildProgressTab(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loadingProgress) {
      return const ShimmerLoading(
        showHeader: true,
        itemCount: 3,
        itemHeight: 120,
      );
    }

    if (_progressSummary == null) {
      return AppCard(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          children: [
            Icon(Icons.timeline_rounded, size: 40, color: cs.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'İlerleme verisi alınamadı',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Backend sunucusuna bağlanılamıyor.',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadProgressSummary,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    final p = _progressSummary!;
    final mealPct = p.daysInPeriod > 0
        ? (p.totalMealDays / p.daysInPeriod).clamp(0.0, 1.0)
        : 0.0;
    final exercisePct = p.daysInPeriod > 0
        ? (p.totalExerciseDays / p.daysInPeriod).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      children: [
        // Streak Kartları
        Row(
          children: [
            Expanded(
              child: _streakCard(
                context,
                icon: Icons.restaurant_rounded,
                label: 'Öğün Serisi',
                streak: p.mealStreak,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _streakCard(
                context,
                icon: Icons.fitness_center_rounded,
                label: 'Egzersiz Serisi',
                streak: p.exerciseStreak,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Tamamlama Oranları
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Son ${p.daysInPeriod} Gün Özeti',
                style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
              ),
              const SizedBox(height: 20),
              _progressBar(
                context,
                label: 'Öğün Takibi',
                value: '${p.totalMealDays}/${p.daysInPeriod} gün',
                progress: mealPct,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              _progressBar(
                context,
                label: 'Egzersiz Planı',
                value: '${p.totalExerciseDays}/${p.daysInPeriod} gün',
                progress: exercisePct,
                color: AppColors.secondary,
              ),
              const SizedBox(height: 20),
              Divider(color: cs.outlineVariant.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _miniStat(
                      context,
                      Icons.local_fire_department_rounded,
                      '${p.totalCaloriesBurned}',
                      'Kalori Yakıldı',
                      AppColors.destructive,
                    ),
                  ),
                  Expanded(
                    child: _miniStat(
                      context,
                      Icons.timer_rounded,
                      '${p.totalExerciseMinutes}',
                      'Dakika Egzersiz',
                      AppColors.accent,
                    ),
                  ),
                  if (p.avgHealthScore > 0)
                    Expanded(
                      child: _miniStat(
                        context,
                        Icons.favorite_rounded,
                        '${p.avgHealthScore.toInt()}',
                        'Sağlık Skoru',
                        AppColors.secondary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Son Yemekler
        if (p.monthlyMeals.isNotEmpty) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Son Kaydedilen Öğünler',
                  style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
                ),
                const SizedBox(height: 12),
                ...p.monthlyMeals.take(5).map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.restaurant, size: 16, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m['food_name']?.toString() ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              m['date']?.toString() ?? '',
                              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${m['calories'] ?? 0} kcal',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Son Egzersizler
        if (p.monthlyExercises.isNotEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Son Egzersiz Planları',
                  style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
                ),
                const SizedBox(height: 12),
                ...p.monthlyExercises.take(5).map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          (e['has_feedback'] == true) ? Icons.check_circle : Icons.fitness_center,
                          size: 16,
                          color: (e['has_feedback'] == true) ? AppColors.secondary : AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${e['exercise_count'] ?? 0} egzersiz · ${e['total_duration'] ?? 0} dk',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              e['date']?.toString() ?? '',
                              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${e['total_calories'] ?? 0} kcal',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
      ],
    );
  }

  Widget _streakCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int streak,
    required Color color,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            '$streak gün 🔥',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: cs.onSurface,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _progressBar(
    BuildContext context, {
    required String label,
    required String value,
    required double progress,
    required Color color,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 13, color: cs.onSurface)),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: cs.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _miniStat(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: cs.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTrendIndicator(List<double> data) {
    if (data.length < 2) {
      return const SizedBox.shrink();
    }
    final validData = data.where((d) => d > 0).toList();
    if (validData.length < 2) {
      return const SizedBox.shrink();
    }

    final mid = validData.length ~/ 2;
    final firstHalf = validData.sublist(0, mid);
    final secondHalf = validData.sublist(mid);
    final avgFirst = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
    final avgSecond = secondHalf.reduce((a, b) => a + b) / secondHalf.length;

    if (avgFirst == 0) return const SizedBox.shrink();

    final pctChange = ((avgSecond - avgFirst) / avgFirst * 100).round();
    final isUp = pctChange >= 0;
    // Risk tabında artma kötü, diğerlerinde iyi
    final isPositive = _activeTab == 'risk' ? !isUp : isUp;
    final color = isPositive ? AppColors.secondary : AppColors.destructive;

    return Row(
      children: [
        Icon(
          isUp ? Icons.trending_up : Icons.trending_down,
          color: color,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          '${isUp ? "+" : ""}$pctChange%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _Tab {
  final String id, label;
  const _Tab(this.id, this.label);
}

class _Insight {
  final Color color;
  final String text;
  const _Insight(this.color, this.text);
}
