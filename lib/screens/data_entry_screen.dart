import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../theme/theme_notifier.dart';
import '../services/health_service.dart';
import '../services/api_service.dart';
import '../services/user_profile_service.dart';

class DataEntryScreen extends StatefulWidget {
  const DataEntryScreen({super.key});

  @override
  State<DataEntryScreen> createState() => _DataEntryScreenState();
}

class _DataEntryScreenState extends State<DataEntryScreen> {
  double _systolic = 120;
  double _diastolic = 80;
  double _sleep = 7.5;
  double _steps = 8000;

  bool _saving = false;
  bool _saved = false;
  bool _isSyncing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChange);
    _loadTodayData();
  }

  void _onThemeChange() => setState(() {});

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChange);
    super.dispose();
  }

  Future<void> _loadTodayData() async {
    final entry = await HealthService.getTodayEntry();
    if (entry != null && mounted) {
      setState(() {
        if (entry.systolic > 0) _systolic = entry.systolic;
        if (entry.diastolic > 0) _diastolic = entry.diastolic;
        if (entry.sleepHours > 0) _sleep = entry.sleepHours;
        if (entry.steps > 0) _steps = entry.steps;
      });
    }
  }

  Future<void> _syncHealthData() async {
    setState(() {
      _isSyncing = true;
      _errorMessage = null;
    });

    final success = await HealthService.syncFromDevice();

    if (mounted) {
      setState(() {
        _isSyncing = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Akıllı cihaz verileri başarıyla senkronize edildi ✓',
            ),
            backgroundColor: AppColors.secondary,
          ),
        );
        _loadTodayData(); // senkronize edilenleri slider'a yansıt
      } else {
        setState(() {
          _errorMessage =
              'Cihaz verilerine ulaşılamadı. İzinleri kontrol edin.';
        });
      }
    }
  }

  Future<void> _handleSave() async {
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      // 2 — UserProfile'ı çek
      final profile = await UserProfileService.getProfile();
      final pAge = profile?.age ?? 30;
      final pHeight = profile?.height ?? 170.0;
      final pWeight = profile?.weight ?? 70.0;
      final pGender = profile?.gender ?? 'M';

      // 1 — Firestore'a kaydet (M1)
      final entry = HealthEntry(
        date: DateTime.now(),
        weight: pWeight,
        systolic: _systolic,
        diastolic: _diastolic,
        sleepHours: _sleep,
        steps: _steps,
        source: 'manual',
      );
      await HealthService.saveHealthEntry(entry);

      // 3 — FastAPI'den risk skoru al
      await ApiService.fetchRiskScore(
        RiskApiRequest(
          age: pAge,
          gender: pGender,
          height: pHeight,
          weight: pWeight,
          steps: _steps,
          sleepHours: _sleep,
          systolic: _systolic,
          diastolic: _diastolic,
        ),
      );

      if (mounted) {
        setState(() {
          _saving = false;
          _saved = true;
        });
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) context.go('/app/dashboard');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = 'Kaydedilirken hata oluştu. Tekrar deneyin.';
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
              child: Column(
                children: [
                  _buildBPCard(context),
                  const SizedBox(height: 16),
                  _buildSleepCard(context),
                  const SizedBox(height: 16),
                  _buildStepsCard(context),
                  const SizedBox(height: 24),
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.destructive.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.destructive.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.destructive,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppColors.destructive,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _buildSyncButton(),
                  const SizedBox(height: 12),
                  _buildSaveButton(),
                  const SizedBox(height: 12),
                  Text(
                    'Son güncelleme: Bugün ${TimeOfDay.now().format(context)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
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
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.go('/app/dashboard'),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sağlık Veri Girişi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Günlük ölçümlerinizi güncelleyin',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBPCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _dataCard(
      context: context,
      icon: Icons.favorite_outline,
      color: AppColors.primary,
      title: 'Tansiyon',
      subtitle: 'Sistolik / Diastolik',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sistolik',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _systolic.toInt().toString(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        'mmHg',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Slider(
                  value: _systolic,
                  min: 80,
                  max: 180,
                  activeColor: AppColors.primary,
                  inactiveColor: cs.surfaceContainerHighest,
                  onChanged: (v) => setState(() => _systolic = v),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Diastolik',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _diastolic.toInt().toString(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        'mmHg',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Slider(
                  value: _diastolic,
                  min: 40,
                  max: 120,
                  activeColor: AppColors.primary,
                  inactiveColor: cs.surfaceContainerHighest,
                  onChanged: (v) => setState(() => _diastolic = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _dataCard(
      context: context,
      icon: Icons.dark_mode_outlined,
      color: AppColors.accent,
      title: 'Uyku Süresi',
      subtitle: 'Dün gece kaç saat uyudunuz',
      child: Column(
        children: [
          Slider(
            value: _sleep,
            min: 0,
            max: 12,
            divisions: 24,
            activeColor: AppColors.accent,
            inactiveColor: cs.surfaceContainerHighest,
            onChanged: (v) => setState(() => _sleep = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _sleep.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Text('saat', style: TextStyle(color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepsCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = (_steps / 10000).clamp(0.0, 1.0);
    return _dataCard(
      context: context,
      icon: Icons.directions_walk_outlined,
      color: AppColors.primary,
      title: 'Günlük Adım',
      subtitle: 'Bugün atılan adım sayısı',
      child: Column(
        children: [
          Slider(
            value: _steps,
            min: 0,
            max: 20000,
            divisions: 400,
            activeColor: AppColors.primary,
            inactiveColor: cs.surfaceContainerHighest,
            onChanged: (v) => setState(() => _steps = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _steps.toInt().toString(),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Text('adım', style: TextStyle(color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hedef İlerlemesi',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '%${(progress * 100).toInt()}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: (_saving || _isSyncing) ? null : _syncHealthData,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primaryLight, width: 2),
          foregroundColor: AppColors.primaryLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSyncing
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.watch_outlined),
                  SizedBox(width: 8),
                  Text(
                    'Akıllı Cihazdan Çek (Health Connect)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_saving || _saved) ? null : _handleSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: _saved ? AppColors.secondary : AppColors.primary,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(_saved ? Icons.check : Icons.save_outlined),
        label: Text(
          _saving
              ? 'Kaydediliyor...'
              : _saved
              ? 'Veriler Başarıyla Kaydedildi!'
              : 'Sağlık Verilerini Kaydet',
        ),
      ),
    );
  }

  Widget _dataCard({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
