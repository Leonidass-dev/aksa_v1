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
    'genel': [0.5, 0.5, 0.5, 0.5, 0.5],
  };

  List<String> _labels = [];
  bool _loadingData = true;

  @override
  void initState() {
    super.initState();
    _loadFromFirestore();
  }

  Future<void> _loadFromFirestore() async {
    setState(() => _loadingData = true);
    final entries = await HealthService.getLastNDays(7);

    if (entries.isEmpty) {
      if (mounted) setState(() => _loadingData = false);
      return;
    }

    // Eskiden yeniye sırala
    final sorted = entries.reversed.toList();

    final labels = sorted.map((e) {
      final d = e.date;
      return '${d.day}/${d.month}';
    }).toList();

    setState(() {
      _labels = labels;
      _chartData = {
        'steps': sorted.map((e) => e.steps).toList(),
        'heart_rate': sorted.map((e) => e.heartRate).toList(),
        'sleep': sorted.map((e) => e.sleepHours).toList(),
        'risk': sorted
            .map(
              (e) => (e.steps > 0 ? (e.steps / 100) : 0.0).clamp(0.0, 100.0),
            )
            .toList(),
      };
      
      // Radar Chart İçin Normalize Veriler (Son 7 gün ortalaması)
      _calculateRadarData(sorted);
      
      _loadingData = false;
    });
  }

  void _calculateRadarData(List<HealthEntry> entries) async {
    final profile = await UserProfileService.getProfile();
    final weight = profile?.weight ?? 70.0;
    final waterTarget = HealthService.calculateWaterTarget(weight);
    
    double avgSteps = 0, avgSleep = 0, avgWater = 0, avgRh = 0, avgRisk = 0;
    int count = entries.length;
    
    for (var e in entries) {
      avgSteps += e.steps;
      avgSleep += e.sleepHours;
      avgWater += e.waterMl;
      avgRh += e.restingHeartRate > 0 ? e.restingHeartRate : 70;
      avgRisk += (e.systolic > 0 ? (e.systolic - 90) * 0.5 : 20.0);
    }
    
    avgSteps /= count;
    avgSleep /= count;
    avgWater /= count;
    avgRh /= count;
    avgRisk /= count;
    
    setState(() {
      _chartData['genel'] = [
        (avgSteps / 10000).clamp(0.0, 1.0), // Adım (Hedef 10k)
        (avgSleep / 8).clamp(0.0, 1.0),     // Uyku (Hedef 8s)
        (avgWater / waterTarget).clamp(0.0, 1.0), // Su (Hedef Dinamik)
        (1 - ((avgRh - 60) / 40)).clamp(0.1, 1.0), // Kalp (Daha düşük/sabit daha iyi)
        (1 - (avgRisk / 100)).clamp(0.1, 1.0),    // Risk
      ];
    });
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
            else
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
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
                    onTap: () => setState(() => _timeframe = id),
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
    
    final color = _activeTab == 'sleep'
        ? AppColors.accent
        : _activeTab == 'heart_rate'
        ? AppColors.destructive
        : _activeTab == 'steps'
        ? AppColors.secondary
        : AppColors.primary;

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
                    '${_tabs.firstWhere((t) => t.id == _activeTab, orElse: () => _tabs.first).label} Trendi',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    'Son 7 gün',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(
                    Icons.trending_up,
                    color: AppColors.secondary,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '+8%',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: CustomPaint(
              size: const Size(double.infinity, 160),
              painter: AppLineChartPainter(
                data: data,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
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
            'Haftalık ortalama verilerinizin dağılımı',
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
                  switch (index) {
                    case 0: return const RadarChartTitle(text: 'Adım');
                    case 1: return const RadarChartTitle(text: 'Uyku');
                    case 2: return const RadarChartTitle(text: 'Su');
                    case 3: return const RadarChartTitle(text: 'Kalp');
                    case 4: return const RadarChartTitle(text: 'Risk');
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

    final data = _chartData[_activeTab] ?? [];
    if (data.isNotEmpty && data.any((d) => d > 0)) {
      final validData = data.where((d) => d > 0).toList();
      if (validData.isNotEmpty) {
        final average = validData.reduce((a, b) => a + b) / validData.length;
        if (_activeTab == 'steps') {
          final maxSteps = validData.reduce((a, b) => a > b ? a : b);
          avg = '${average.toInt()} adım';
          best = '${maxSteps.toInt()} adım';
        } else if (_activeTab == 'heart_rate') {
          final maxHR = validData.reduce((a, b) => a > b ? a : b);
          final minHR = validData.reduce((a, b) => a < b ? a : b);
          avg = '${average.toInt()} bpm';
          best = '${minHR.toInt()} bpm'; // En düşük (dinlenme) nabız daha iyidir
        } else if (_activeTab == 'sleep') {
          final maxS = validData.reduce((a, b) => a > b ? a : b);
          avg = '${average.toStringAsFixed(1)} saat';
          best = '${maxS.toStringAsFixed(1)} saat';
        } else if (_activeTab == 'risk') {
          final maxR = validData.reduce((a, b) => a > b ? a : b);
          avg = average.toStringAsFixed(1);
          best = maxR.toStringAsFixed(1);
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
                        'Ortalama',
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
                        'En İyi',
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
    final insights = {
      'steps': [
        _Insight(
          AppColors.secondary,
          'Haftalık hareketliliğiniz incelendiğinde bugünlerde aktif olduğunuz görülüyor. Günlük 10 bin hedefi için istikrarlı kalın.',
        ),
      ],
      'heart_rate': [
        _Insight(
          AppColors.destructive,
          'Ortalama kalp atış hızınız stabil. Dinlenme nabzınızın 60-70 arası olması kondisyonunuzun iyi olduğunu gösterir.',
        ),
      ],
      'sleep': [
        _Insight(
          AppColors.accent,
          'Uyku süreniz genel hedeflerle uyumlu. Derin uyku evresini artırmak için uyku düzeninize dikkat edebilirsiniz.',
        ),
      ],
      'risk': [
        _Insight(
          AppColors.primary,
          'Genel sağlık skorunuz verilerinize göre hesaplanmıştır. Egzersiz sıklığını artırmak skoru iyileştirecektir.',
        ),
      ],
      'genel': [
        _Insight(
          AppColors.secondary,
          'Radar grafiği tüm verilerinizin dengeli dağıldığını gösteriyor. Adım ve su hedeflerine odaklanın.',
        ),
      ],
    }[_activeTab] ?? [
      const _Insight(AppColors.primary, 'Veri analizi yapılıyor...')
    ];

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
          Text(
            'Yapay Zeka Yorumları',
            style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
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
