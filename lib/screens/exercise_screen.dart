import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/health_service.dart';
import '../services/user_profile_service.dart';
import '../utils/health_data_quality.dart';
import '../widgets/common_widgets.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/theme_aware_state.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen>
    with ThemeAwareMixin {
  bool _loading = true;
  ExerciseApiResult? _apiResult;
  String? _errorMsg;
  int _completedToday = 0;
  Set<String> _completedExercises = {};

  // Egzersiz tipi → ikon haritası
  static final _exerciseIconMap = <String, IconData>{
    'kardiyo': Icons.directions_run,
    'koşu': Icons.directions_run,
    'yürüyüş': Icons.directions_walk,
    'yoga': Icons.self_improvement,
    'esneme': Icons.accessibility_new,
    'bisiklet': Icons.pedal_bike,
    'yüzme': Icons.pool,
    'kuvvet': Icons.fitness_center,
    'pilates': Icons.self_improvement,
    'dans': Icons.music_note,
    'meditasyon': Icons.spa,
    'nefes': Icons.air,
  };

  IconData _getExerciseIcon(String type) {
    final lowerType = type.toLowerCase();
    for (final entry in _exerciseIconMap.entries) {
      if (lowerType.contains(entry.key)) return entry.value;
    }
    return Icons.fitness_center;
  }


  @override
  void initState() {
    super.initState();
    _loadCompletedExercises();
    _loadExercisePlan();
  }

  Future<void> _loadCompletedExercises() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final key = 'completed_exercises_${today.year}_${today.month}_${today.day}';
    final saved = prefs.getStringList(key) ?? [];
    if (mounted) {
      setState(() {
        _completedExercises = saved.toSet();
        _completedToday = _completedExercises.length;
      });
    }
  }

  Future<void> _saveCompletedExercise(String exerciseTitle) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final key = 'completed_exercises_${today.year}_${today.month}_${today.day}';
    _completedExercises.add(exerciseTitle);
    await prefs.setStringList(key, _completedExercises.toList());
  }

  Future<void> _loadExercisePlan({bool force = false}) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final profile = await UserProfileService.getProfile();
      if (profile == null) {
        setState(() {
          _errorMsg = 'Egzersiz planı için profilinizi tamamlamalısınız.';
          _loading = false;
        });
        return;
      }

      final today = await HealthService.getTodayEntry();
      final todayData = today ?? HealthEntry(date: DateTime.now());

      String riskLevelStr = 'low';

      // Her durumda profile verisini katarak bir risk hesapla
      if (HealthDataQuality.hasActionableVitals(todayData)) {
        final riskReq = RiskApiRequest(
          age: profile.age,
          gender: profile.gender,
          weight: profile.weight,
          height: profile.height,
          steps: todayData.steps,
          sleepHours: todayData.sleepHours,
          systolic: todayData.systolic,
          diastolic: todayData.diastolic,
          heartRateResting: HealthDataQuality.restingHeartRateForRisk(todayData),
          heartRateAvg: HealthDataQuality.heartRateForRisk(todayData),
        );

        final riskResult = await ApiService.fetchRiskScore(riskReq);
        if (riskResult != null && riskResult.level != 'unknown') {
          riskLevelStr = riskResult.level;
        }
      }

      final req = ExerciseApiRequest(
        age: profile.age,
        weight: profile.weight,
        height: profile.height,
        gender: profile.gender,
        riskLevel: riskLevelStr,
        systolicBp: today?.systolic,
        diastolicBp: today?.diastolic,
        heartRate: today?.heartRate,
        forceRefresh: force,
      );

      final result = await ApiService.fetchExercisePlan(req);

      if (mounted) {
        setState(() {
          _apiResult = result;
          if (result == null) {
            _errorMsg = 'Egzersiz planı alınamadı.';
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = 'Bir hata oluştu: $e';
          _loading = false;
        });
      }
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

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const ShimmerLoading(
        showHeader: true,
        itemCount: 3,
        itemHeight: 160,
      );
    }

    if (_errorMsg != null) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.destructive.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.destructive.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              _errorMsg!,
              style: const TextStyle(color: AppColors.destructive),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _errorMsg!.contains('profil')
                ? () => context.go('/profile-setup')
                : _loadExercisePlan,
            child: Text(_errorMsg!.contains('profil')
                ? 'Profilimi Tamamla'
                : 'Tekrar Dene'),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildTodayStatusCard(context),
        if (_completedExercises.isNotEmpty && _apiResult != null) ...[
          const SizedBox(height: 12),
          _buildPerformanceSummary(context),
        ],
        const SizedBox(height: 20),
        if (_apiResult != null && _apiResult!.exercises.isNotEmpty)
          _buildExerciseList(context, _apiResult!.exercises)
        else
          AppEmptyState(
            icon: Icons.fitness_center_outlined,
            title: 'Plan Bulunamadı',
            subtitle: 'Şu anki sağlık verilerinize göre bir plan üretilemedi. Lütfen daha sonra tekrar deneyin.',
          ),
        const SizedBox(height: 20),
        _buildStats(context),
        const SizedBox(height: 20),
        if (_apiResult != null) _buildTips(context, _apiResult!.aiAdvice),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final duration = _apiResult?.totalDurationMinutes ?? 0;
    final calories = _apiResult?.totalCalories ?? 0;

    return AppHeader(
      title: 'Egzersiz Planı',
      subtitle: 'Yapay Zeka Destekli',
      trailing: AppRefreshButton(
        onTap: _loading ? null : () => _loadExercisePlan(force: true),
        isLoading: _loading,
      ),
      bottomContent: Row(
        children: [
          Expanded(
            child: _summaryCard(
              Icons.access_time_outlined,
              'Süre',
              '$duration dak',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _summaryCard(
              Icons.bolt_outlined,
              'Hedef Kalori',
              '$calories',
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceSummary(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final exercises = _apiResult!.exercises;
    int completedMins = 0;
    int completedCals = 0;
    for (final ex in exercises) {
      if (_completedExercises.contains(ex.title)) {
        completedMins += ex.durationMinutes;
        completedCals += ex.calories;
      }
    }
    final totalMins = _apiResult!.totalDurationMinutes;
    final progress = totalMins > 0 ? (completedMins / totalMins).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Bugünkü İlerleme', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('$completedMins / $totalMins dk', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              const Spacer(),
              Icon(Icons.local_fire_department_outlined, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('$completedCals kcal yakıldı', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayStatusCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    String statusTitle = _apiResult != null ? 'Kişisel Analiz Hazır' : 'Analiz Ediliyor';
    String statusDesc = _apiResult != null 
        ? 'Sağlık verileriniz ve risk profiliniz Gemini AI tarafından işlendi.'
        : 'Verileriniz ML Pipeline üzerinden analiz ediliyor...';
    IconData statusIcon = _apiResult != null ? Icons.verified_user_rounded : Icons.analytics_outlined;
    Color statusColor = _apiResult != null ? AppColors.secondary : AppColors.primary;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      statusDesc,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: cs.outlineVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statusDetail(Icons.favorite_border, 'Risk', _apiResult != null ? 'Hesaplandı' : '-'),
              _statusDetail(Icons.speed, 'Efor', 'Kişiselleştirildi'),
              _statusDetail(Icons.calendar_today_outlined, 'Tarih', 'Bugün'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusDetail(IconData icon, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseList(
    BuildContext context,
    List<ExerciseApiItem> exercises,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Size Özel Günlük Öneriler',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            TextButton(
              onPressed: () => _loadExercisePlan(force: true),
              child: const Text(
                'Yeni Plan Üret',
                style: TextStyle(color: AppColors.primary, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...exercises.map(
          (ex) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.2),
                              AppColors.secondary.withValues(alpha: 0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _getExerciseIcon(ex.type),
                          color: _completedExercises.contains(ex.title)
                              ? AppColors.secondary
                              : AppColors.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text(
                               ex.type.toUpperCase(),
                               style: TextStyle(
                                 fontSize: 10,
                                 fontWeight: FontWeight.w900,
                                 letterSpacing: 0.5,
                                 color: cs.primary.withValues(alpha: 0.7),
                               ),
                             ),
                             const SizedBox(height: 2),
                             Text(
                               ex.title,
                               style: TextStyle(
                                 fontWeight: FontWeight.bold,
                                 fontSize: 16,
                                 color: cs.onSurface,
                               ),
                             ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${ex.durationMinutes} dak',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.bolt,
                                  size: 14,
                                  color: cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${ex.calories} kal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _difficultyBadge(ex.intensity),
                    ],
                  ),
                  if (ex.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      ex.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: _completedExercises.contains(ex.title)
                        ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, color: AppColors.secondary, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Tamamlandı ✅',
                                  style: TextStyle(
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : TextButton(
                            onPressed: () => _showExerciseTimer(context, ex),
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.06),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text(
                              'Egzersizi Başlat',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _difficultyBadge(String difficulty) {
    Color color;
    switch (difficulty.toLowerCase()) {
      case 'düşük':
        color = AppColors.secondary;
        break;
      case 'orta':
        color = AppColors.accent;
        break;
      case 'yüksek':
        color = AppColors.destructive;
        break;
      default:
        color = AppColors.secondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        difficulty,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showExerciseTimer(BuildContext context, ExerciseApiItem exercise) {
    showDialog(
      context: context,
      builder: (ctx) => _ExerciseTimerDialog(
        exercise: exercise,
        onComplete: () {
          HapticFeedback.mediumImpact();
          _saveCompletedExercise(exercise.title);
          setState(() {
            _completedToday++;
            _completedExercises.add(exercise.title);
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${exercise.title} tamamlandı! 🎉'),
                backgroundColor: AppColors.secondary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Not: _cardDecoration AppCard ile değiştirildi
    final totalDur = _apiResult?.totalDurationMinutes ?? 0;
    final totalCal = _apiResult?.totalCalories ?? 0;
    final exerciseCount = _apiResult?.exercises.length ?? 0;
    final completedPct = exerciseCount > 0
        ? (_completedToday / exerciseCount).clamp(0.0, 1.0)
        : 0.0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bugünkü İlerleme',
            style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statItem(context, '$_completedToday/$exerciseCount', 'Egzersiz'),
              _statItem(context, '$totalDur', 'Dakika'),
              _statItem(context, '$totalCal', 'Kalori'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bugünkü İlerleme',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              Text(
                '%${(completedPct * 100).toInt()}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: completedPct,
              minHeight: 10,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(BuildContext context, String value, String label) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildTips(BuildContext context, String aiAdvice) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Yapay Zeka Tavsiyesi',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            aiAdvice.isNotEmpty
                ? aiAdvice
                : 'Sağlıklı bir yaşam için düzenli egzersiz yapmaya devam edin.',
            style: TextStyle(fontSize: 14, color: cs.onSurface, height: 1.5),
          ),
        ],
      ),
    );
  }

}


// ── Egzersiz Zamanlayıcı Dialog ──────────────────────────────────
class _ExerciseTimerDialog extends StatefulWidget {
  final ExerciseApiItem exercise;
  final VoidCallback onComplete;
  const _ExerciseTimerDialog({
    required this.exercise,
    required this.onComplete,
  });

  @override
  State<_ExerciseTimerDialog> createState() => _ExerciseTimerDialogState();
}

class _ExerciseTimerDialogState extends State<_ExerciseTimerDialog> {
  late int _remainingSeconds;
  late int _totalSeconds;
  bool _isRunning = false;
  bool _isComplete = false;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.exercise.durationMinutes * 60;
    _remainingSeconds = _totalSeconds;
  }

  void _startTimer() {
    setState(() => _isRunning = true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          _isRunning = false;
          _isComplete = true;
          timer.cancel();
          widget.onComplete();
        }
      });
    });
  }

  void _togglePause() {
    setState(() => _isRunning = !_isRunning);
    if (_isRunning) {
      _startTimer();
    } else {
      _timer?.cancel();
    }
  }

  String get _timeText {
    final min = _remainingSeconds ~/ 60;
    final sec = _remainingSeconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  double get _progress =>
      _totalSeconds > 0 ? 1.0 - (_remainingSeconds / _totalSeconds) : 0.0;

  @override
  void dispose() {
    _timer?.cancel();
    _isRunning = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.exercise.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.exercise.type,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: _progress,
                      strokeWidth: 10,
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isComplete ? AppColors.secondary : AppColors.primary,
                      ),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isComplete)
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.secondary,
                          size: 40,
                        )
                      else
                        Text(
                          _timeText,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                      if (_isComplete)
                        Text(
                          'Tamamlandı!',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        Text(
                          'Kalan süre',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (_isComplete)
              Column(
                children: [
                  Text(
                    'Bu egzersiz nasıldı?',
                    style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ApiService.sendExerciseFeedback('too_easy');
                            Navigator.pop(context);
                          },
                          child: const Text('Çok Kolay'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            ApiService.sendExerciseFeedback('perfect');
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                          child: const Text('İdeal'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ApiService.sendExerciseFeedback('too_hard');
                            Navigator.pop(context);
                          },
                          child: const Text('Çok Zor'),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _isRunning = false;
                        Navigator.pop(context);
                      },
                      child: const Text('İptal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isRunning
                          ? _togglePause
                          : (_remainingSeconds > 0 ? _startTimer : null),
                      child: Text(_isRunning ? 'Duraklat' : 'Başlat'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
