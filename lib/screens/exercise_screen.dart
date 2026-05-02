import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/health_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/common_widgets.dart';
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


  @override
  void initState() {
    super.initState();
    _loadExercisePlan();
  }

  Future<void> _loadExercisePlan({bool force = false}) async {
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
      final riskReq = RiskApiRequest(
        age: profile.age,
        gender: profile.gender,
        weight: profile.weight,
        height: profile.height,
        steps: todayData.steps,
        sleepHours: todayData.sleepHours,
        systolic: todayData.systolic,
        diastolic: todayData.diastolic,
      );

      final riskResult = await ApiService.fetchRiskScore(riskReq);
      if (riskResult != null) {
        riskLevelStr = riskResult.level; // 'low', 'medium', 'high'
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
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Yapay zeka size özel egzersiz planı hazırlıyor...',
              style: TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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

  Widget _buildTodayStatusCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final riskLevel = _apiResult != null ? _apiResult!.aiAdvice : '';
    
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
                        child: const Icon(
                          Icons.fitness_center,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ex.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                            Text(
                              ex.type,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
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
                    child: TextButton(
                      onPressed: () => _showExerciseTimer(context, ex),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.06,
                        ),
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
          setState(() => _completedToday++);
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

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.exercise.durationMinutes * 60;
    _remainingSeconds = _totalSeconds;
  }

  void _startTimer() {
    setState(() => _isRunning = true);
    _tick();
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_isRunning) return;
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          _isRunning = false;
          _isComplete = true;
          widget.onComplete();
        }
      });
      if (_isRunning) _tick();
    });
  }

  void _togglePause() {
    setState(() => _isRunning = !_isRunning);
    if (_isRunning) _tick();
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
