import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../theme/theme_notifier.dart';
import '../services/api_service.dart';
import '../services/health_service.dart';
import '../services/user_profile_service.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  bool _loading = true;
  ExerciseApiResult? _apiResult;
  String? _errorMsg;

  static const _schedule = [
    _Day('Pzt', true, true),
    _Day('Sal', true, true),
    _Day('Çar', true, true),
    _Day('Per', true, false),
    _Day('Cum', true, false),
    _Day('Cmt', false, false),
    _Day('Paz', true, false),
  ];

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChange);
    _loadExercisePlan();
  }

  void _onThemeChange() => setState(() {});

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChange);
    super.dispose();
  }

  Future<void> _loadExercisePlan() async {
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
            Text('Yapay zeka size özel egzersiz planı hazırlıyor...',
                style: TextStyle(fontSize: 13), textAlign: TextAlign.center),
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
              border: Border.all(color: AppColors.destructive.withValues(alpha: 0.3)),
            ),
            child: Text(_errorMsg!, style: const TextStyle(color: AppColors.destructive)),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/profile-setup'),
            child: const Text('Profilimi Tamamla'),
          )
        ],
      );
    }

    return Column(
      children: [
        _buildSchedule(context),
        const SizedBox(height: 20),
        if (_apiResult != null && _apiResult!.exercises.isNotEmpty)
          _buildExerciseList(context, _apiResult!.exercises)
        else
          const Text('Bugün için egzersiz bulunamadı.'),
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
                children: [
                  GestureDetector(
                    onTap: () => context.go('/app/dashboard'),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Egzersiz Planı',
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        Text('Yapay Zeka Destekli',
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _loading ? null : _loadExercisePlan,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.refresh,
                          color: Colors.white.withValues(alpha: _loading ? 0.4 : 1.0), size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _summaryCard(Icons.access_time_outlined, 'Süre', '$duration dak')),
                  const SizedBox(width: 12),
                  Expanded(child: _summaryCard(Icons.bolt_outlined, 'Hedef Kalori', '$calories')),
                ],
              ),
            ],
          ),
        ),
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
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSchedule(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('Haftalık Program',
                  style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _schedule.map((item) {
              Color bgColor;
              Color textColor;
              if (item.completed) {
                bgColor = AppColors.secondary; textColor = Colors.white;
              } else if (item.active) {
                bgColor = AppColors.primary; textColor = Colors.white;
              } else {
                bgColor = cs.surfaceContainerHighest; textColor = cs.onSurfaceVariant;
              }
              return Column(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
                    child: Center(
                      child: Text(item.day[0],
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(item.day, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseList(BuildContext context, List<ExerciseApiItem> exercises) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Bugünkü Antrenman',
                style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
            TextButton(
              onPressed: _loadExercisePlan,
              child: const Text('Yeni Plan Üret',
                  style: TextStyle(color: AppColors.primary, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...exercises.map((ex) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: _cardDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary.withValues(alpha: 0.2), AppColors.secondary.withValues(alpha: 0.2)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.fitness_center, color: AppColors.primary, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ex.title, style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                          Text(ex.type, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 14, color: cs.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text('${ex.durationMinutes} dak', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                              const SizedBox(width: 12),
                              Icon(Icons.bolt, size: 14, color: cs.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text('${ex.calories} kal', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
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
                  Text(ex.description, style: TextStyle(fontSize: 13, color: cs.onSurface, height: 1.4)),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.06),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Egzersizi Başlat',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _difficultyBadge(String difficulty) {
    Color color;
    switch (difficulty.toLowerCase()) {
      case 'düşük': color = AppColors.secondary; break;
      case 'orta': color = AppColors.accent; break;
      case 'yüksek': color = AppColors.destructive; break;
      default: color = AppColors.secondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(difficulty, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildStats(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bu Haftaki İlerleme',
              style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 16),
          Row(
            children: [
              _statItem(context, '3', 'Antrenman'),
              _statItem(context, '120', 'Dakika'),
              _statItem(context, '850', 'Kalori'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Haftalık Hedef', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              Text('%60', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: 0.60,
              minHeight: 10,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
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
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cs.onSurface)),
          Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
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
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('Yapay Zeka Tavsiyesi',
                  style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            aiAdvice.isNotEmpty ? aiAdvice : 'Sağlıklı bir yaşam için düzenli egzersiz yapmaya devam edin.',
            style: TextStyle(fontSize: 14, color: cs.onSurface, height: 1.5),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: cs.outlineVariant),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
    );
  }
}

class _Day {
  final String day;
  final bool active, completed;
  const _Day(this.day, this.active, this.completed);
}