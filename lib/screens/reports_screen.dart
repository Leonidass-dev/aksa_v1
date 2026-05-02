import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/health_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/app_line_chart.dart';
import '../widgets/theme_aware_state.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/user_profile_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadFromFirestore();
  }

  Future<void> _loadFromFirestore() async {
    setState(() => _loadingData = true);
    final days = _timeframe == 'month' ? 30 : 7;
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

    // Risk verisini hesapla
    final riskData = sorted.map((e) {
      double r = 10.0;
      if (e.steps > 0) r += ((10000 - e.steps) / 10000 * 15).clamp(0, 15);
      if (e.sleepHours > 0 && e.sleepHours < 6) r += (6 - e.sleepHours) * 3;
      if (e.heartRate > 100) r += (e.heartRate - 100) * 0.5;
      if (e.systolic > 130) r += (e.systolic - 130) * 0.5;
      return r.clamp(0.0, 100.0);
    }).toList();

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
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 12),
                    Text(
                      'Veriler yükleniyor...',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
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
                    _buildChart(context),
                    const SizedBox(height: 20),
                    _buildStats(context),
                    const SizedBox(height: 20),
                    _buildInsights(context),
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
      trailing: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.download_outlined,
          color: Colors.white,
          size: 20,
        ),
      ),
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
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _getInterval(_activeTab, data),
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
                        if (value.toInt() >= 0 && value.toInt() < _labels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _labels[value.toInt()],
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
                      interval: _getInterval(_activeTab, data),
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
                maxX: (data.length - 1).toDouble(),
                minY: _getMinY(_activeTab, data),
                maxY: _getMaxY(_activeTab, data),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
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
              ),
            ),
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
    final cs = Theme.of(context).colorScheme;
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
            'Son 7 günde sağlık dengeniz ${_overallScore > 70 ? "gayet iyi" : "geliştirilebilir"} durumda. ${_bestCategory} verileriniz bu haftanın yıldızı oldu!',
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
