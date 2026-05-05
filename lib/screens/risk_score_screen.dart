import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/health_data.dart';
import '../services/health_service.dart';
import '../services/api_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/theme_aware_state.dart';
import 'dart:async';

class RiskScoreScreen extends StatefulWidget {
  const RiskScoreScreen({super.key});

  @override
  State<RiskScoreScreen> createState() => _RiskScoreScreenState();
}

class _RiskScoreScreenState extends State<RiskScoreScreen>
    with ThemeAwareMixin {
  RiskResult _result = RiskResult(
    score: 0,
    level: RiskLevel.low,
    topFactors: [],
    modelVersion: 'none',
    windowEnd: DateTime.now(),
  );
  bool _loading = true;
  bool _hasData = false;

  @override
  void initState() {
    super.initState();
    _loadFromApi();
  }

  Future<void> _loadFromApi() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      // 1 — Profil verisini çek (Yaş, Boy, Kilo, Cinsiyet)
      final profile = await UserProfileService.getProfile();
      final pAge = profile?.age ?? 30;
      final pHeight = profile?.height ?? 170.0;
      final pWeight = profile?.weight ?? 70.0;
      final pGender = profile?.gender ?? 'M';

      // 2 — Firestore'dan bugünün verisini çek
      final entry = await HealthService.getTodayEntry();

      // 3 — Beslenme verilerini çek (Dashboard ile senkronizasyon için)
      final mealHistory = await ApiService.fetchMealHistory(limit: 20);
      final now = DateTime.now();
      final todayMeals = mealHistory.where((m) {
        final d = DateTime.parse(m.analyzedAt).toLocal();
        return d.year == now.year && d.month == now.month && d.day == now.day;
      }).toList();

      final consumedCals = todayMeals.fold(0.0, (s, m) => s + m.calories);
      final avgNutriScore = todayMeals.isEmpty 
          ? 70.0 
          : todayMeals.fold(0.0, (s, m) => s + m.healthScore) / todayMeals.length;

      if (entry != null) {
        // 4 — FastAPI'ye gönder
        final apiResult = await ApiService.fetchRiskScore(
          RiskApiRequest(
            age: pAge,
            gender: pGender,
            height: pHeight,
            weight: pWeight,
            steps: entry.steps,
            sleepHours: entry.sleepHours,
            systolic: entry.systolic,
            diastolic: entry.diastolic,
            heartRateResting: entry.restingHeartRate > 0
                ? entry.restingHeartRate
                : entry.heartRate,
            heartRateAvg: entry.heartRate,
            spo2: entry.spo2,
            stressLevel: entry.stressLevel,
            consumedCalories: consumedCals,
            nutritionScore: avgNutriScore,
          ),
        );

        if (apiResult != null && mounted) {
          setState(() {
            _result = RiskResult(
              score: apiResult.score,
              level: _levelFromString(apiResult.level),
              topFactors: apiResult.topFactors
                  .map(
                    (f) => RiskFactor(
                      name: f.name,
                      contribution: f.contribution,
                      description: f.description,
                    ),
                  )
                  .toList(),
              modelVersion: apiResult.modelVersion,
              windowEnd: DateTime.now(),
            );
            _hasData = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasData = false;
          });
        }
      }
    } catch (e) {
      debugPrint("RiskScoreScreen Hata: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  RiskLevel _levelFromString(String level) => RiskLevelExtension.fromString(level);

  Color get _levelColor => _result.level.color;

  IconData get _levelIcon => _result.level.icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadFromApi,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  children: [
                    if (_loading || !_hasData)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            if (_loading)
                              const CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            const SizedBox(height: 16),
                            Text(
                              _loading
                                  ? 'Risk skorunuz hesaplanıyor...'
                                  : 'Risk skorunuzu görebilmek için "Sağlık Veri Girişi" ekranından bugünün sağlık verilerini (adım, uyku, nabız) kaydetmelisiniz.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      _buildScoreCard(context),
                      const SizedBox(height: 16),
                      _buildAiInsight(context),
                      const SizedBox(height: 16),
                      _buildTopFactors(context),
                      const SizedBox(height: 16),
                      _buildRecommendations(context),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return AppHeader(
      title: 'Sağlık Risk Skoru',
      subtitle: _loading
          ? 'Hesaplanıyor...'
          : _hasData
          ? 'Verileriniz ve Akıllı Analiz'
          : 'Bugün henüz sağlık verisi girmediniz.',
      height: 160,
      trailing: AppRefreshButton(
        onTap: _loading ? null : _loadFromApi,
        isLoading: _loading,
      ),
    );
  }

  Widget _buildScoreCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final score = _result.score.toInt();
    return Transform.translate(
      offset: const Offset(0, -40),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: cs.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: CircularProgressIndicator(
                      value: _result.score / 100,
                      strokeWidth: 12,
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(_levelColor),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        '/ 100',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _levelColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_levelIcon, color: _levelColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _result.level.label,
                    style: TextStyle(
                      color: _levelColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildThresholdBar(),
            const SizedBox(height: 16),
            Text(
              _levelDescription(),
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdBar() {
    return Column(
      children: [
        SizedBox(
          height: 12,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Expanded(
                  flex: 33,
                  child: Container(color: AppColors.secondary),
                ),
                Expanded(flex: 33, child: Container(color: AppColors.accent)),
                Expanded(
                  flex: 34,
                  child: Container(color: AppColors.destructive),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              '0',
              style: TextStyle(fontSize: 10, color: AppColors.mutedForeground),
            ),
            Text(
              '33',
              style: TextStyle(fontSize: 10, color: AppColors.mutedForeground),
            ),
            Text(
              '66',
              style: TextStyle(fontSize: 10, color: AppColors.mutedForeground),
            ),
            Text(
              '100',
              style: TextStyle(fontSize: 10, color: AppColors.mutedForeground),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Düşük',
              style: TextStyle(
                fontSize: 9,
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Orta',
              style: TextStyle(
                fontSize: 9,
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Yüksek',
              style: TextStyle(
                fontSize: 9,
                color: AppColors.destructive,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _levelDescription() {
    switch (_result.level) {
      case RiskLevel.low:
        return 'Sağlık göstergeleriniz iyi durumda. Mevcut alışkanlıklarınızı sürdürün.';
      case RiskLevel.medium:
        return 'Bazı göstergeler dikkat gerektiriyor. Önerileri inceleyip adımlar atmanız önerilir.';
      case RiskLevel.high:
        return 'Sağlık göstergelerinizde önemli sapmalar var. Bir sağlık profesyoneline danışmanız önerilir.';
    }
  }

  Widget _buildAiInsight(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.psychology_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analiz Özeti',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Güncelleme: ${_formatDateTime(_result.windowEnd)}',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Text(
                  _aiInsightText(),
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _aiInsightText() {
    final positives = _result.topFactors
        .where((f) => f.contribution < 0)
        .map((f) => f.name)
        .toList();
    final negatives = _result.topFactors
        .where((f) => f.contribution > 10)
        .map((f) => f.name)
        .toList();

    String text = '';
    if (positives.isNotEmpty) {
      text += '${positives.join(', ')} değerleriniz olumlu katkı sağlıyor. ';
    }
    if (negatives.isNotEmpty) {
      text += '${negatives.join(', ')} alanlarında iyileştirme riski artırıyor. ';
    }
    if (text.isEmpty) {
      text = 'Tüm göstergeler dengeli. Skor hesaplama tamamlandı.';
    }
    return text.trim();
  }

  Widget _buildTopFactors(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Skoru Etkileyen Faktörler',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'İlk 5',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Skoru en çok etkileyen faktörler',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ..._result.topFactors.map((f) => _factorRow(context, f)),
        ],
      ),
    );
  }

  Widget _factorRow(BuildContext context, RiskFactor factor) {
    final cs = Theme.of(context).colorScheme;
    final isPositive = factor.contribution < 0;
    final color = isPositive ? AppColors.secondary : AppColors.destructive;
    final barWidth = factor.contribution.abs().clamp(0.0, 25.0) / 25.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                factor.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                    color: color,
                    size: 14,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${isPositive ? "-" : "+"}${factor.contribution.abs().toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            factor.description,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: barWidth,
              minHeight: 5,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final recs = _generateRecommendations();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kişiselleştirilmiş Öneriler',
            style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
          ),
          const SizedBox(height: 12),
          ...recs.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: r.color.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: r.color.withValues(alpha: 0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(r.icon, color: r.color, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r.text,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_Rec> _generateRecommendations() {
    final recs = <_Rec>[];
    for (final f in _result.topFactors) {
      if (f.contribution <= 0) continue;
      if (f.name.contains('Adım')) {
        recs.add(
          _Rec(
            AppColors.primary,
            Icons.directions_walk_outlined,
            'Günlük 10.000 adım hedefine ulaşmak için kısa yürüyüşler planlayın.',
          ),
        );
      } else if (f.name.contains('Uyku Süresi')) {
        recs.add(
          _Rec(
            AppColors.accent,
            Icons.dark_mode_outlined,
            'Her gece 7-8 saat uyumayı hedefleyin. Düzenli uyku saatleri belirleyin.',
          ),
        );
      } else if (f.name.contains('Uyku Kalitesi')) {
        recs.add(
          _Rec(
            AppColors.accent,
            Icons.bedtime_outlined,
            'Uyku veriminizi artırmak için yatmadan önce ekran süresi kısıtlayın.',
          ),
        );
      } else if (f.name.contains('Kalp')) {
        recs.add(
          _Rec(
            AppColors.destructive,
            Icons.favorite_outline,
            'Nabız değerlerinizi izlemeye devam edin. Anormal yükseklik için doktora danışın.',
          ),
        );
      } else if (f.name.contains('Oksijen')) {
        recs.add(
          _Rec(
            AppColors.destructive,
            Icons.air_outlined,
            'SpO2 değerleriniz düşük. Derin nefes egzersizleri ve doktor kontrolü önerilir.',
          ),
        );
      } else if (f.name.contains('Stres')) {
        recs.add(
          _Rec(
            AppColors.accent,
            Icons.self_improvement_outlined,
            'Stres yönetimi için meditasyon veya nefes egzersizleri deneyin.',
          ),
        );
      } else if (f.name.contains('Aktif')) {
        recs.add(
          _Rec(
            AppColors.primary,
            Icons.fitness_center_outlined,
            'Günde en az 20-30 dakika orta yoğunlukta aktivite hedefleyin.',
          ),
        );
      }
    }
    if (recs.isEmpty) {
      recs.add(
        _Rec(
          AppColors.secondary,
          Icons.check_circle_outline,
          'Tüm sağlık göstergeleriniz iyi durumda. Mevcut rutininizi sürdürün.',
        ),
      );
    }
    return recs.take(4).toList();
  }


  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _Rec {
  final Color color;
  final IconData icon;
  final String text;
  const _Rec(this.color, this.icon, this.text);
}
