import 'dart:async';
import 'package:aksa_v1/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../utils/bmi_utils.dart';
import '../widgets/theme_aware_state.dart';
import '../widgets/profile/body_metrics_card.dart';
import '../widgets/profile/health_goals_card.dart';
import '../widgets/profile/preferences_card.dart';
import '../widgets/profile/about_card.dart';
import '../widgets/profile/sign_out_button.dart';
import '../widgets/profile/edit_profile_sheet.dart';
import '../widgets/profile/weight_update_sheet.dart';
import '../widgets/profile/profile_dialogs.dart';
import '../widgets/profile/health_goals_sheet.dart';
import '../services/health_service.dart';
import '../widgets/profile/health_id_card.dart';
import '../widgets/profile/activity_rings.dart';
import '../widgets/profile/integrations_card.dart';
import '../widgets/profile/device_center_card.dart';
import '../widgets/profile/clinical_profile_card.dart';
import '../widgets/profile/report_export_card.dart';
import '../widgets/profile/profile_skeleton.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with ThemeAwareMixin {
  bool _notifications = true;
  String _fullName = '';
  String _photoUrl = '';
  String _bio = '';
  int _age = 30;
  String _gender = 'M';
  double _height = 170.0;
  double _userWeight = 75.0;
  bool _loading = true;

  double _targetWeight = 68;
  double _targetSteps = 10000;
  double _targetSleep = 8;

  // Acil Durum Bilgileri ve Klinik
  String _bloodType = '';
  List<String> _allergies = [];
  String _emergencyContact = '';
  String _dietPreference = '';
  DateTime? _lastSyncTime;

  double _currentAvgSteps = 0;
  double _currentAvgSleep = 0;
  
  // Su takibi
  double _currentWaterMl = 0;
  double _targetWaterMl = 2000;

  StreamSubscription? _syncSub;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadGoals();
    _loadStats();

    // Senkronizasyon tamamlandığında UI'ı güncelle
    _syncSub = HealthService.syncUpdates.listen((_) {
      if (mounted) {
        _loadStats();
        _loadUser(); // Belki kümülatif veriler değişmiştir
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    setState(() {
      _fullName = u.displayName ?? '';
      _photoUrl = u.photoURL ?? '';
    });
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _fullName = data['fullName'] ?? _fullName;
          _bio = data['bio'] ?? '';
          _photoUrl = data['photoUrl'] ?? _photoUrl;
          _age = (data['age'] as num?)?.toInt() ?? 30;
          _gender = data['gender'] ?? 'M';
          _height = (data['height'] as num?)?.toDouble() ?? 170.0;
          _userWeight = (data['weight'] as num?)?.toDouble() ?? 75.0;
          _bloodType = data['bloodType'] ?? '';
          if (data['allergies'] is String) {
            _allergies = (data['allergies'] as String)
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
          } else if (data['allergies'] is List) {
            _allergies = (data['allergies'] as List).map((e) => e.toString()).toList();
          } else {
            _allergies = [];
          }
          _dietPreference = data['dietPreference'] ?? '';
          _emergencyContact = data['emergencyContact'] ?? '';
          
          // Su hedefini kiloya göre hesapla
          _targetWaterMl = HealthService.calculateWaterTarget(_userWeight, 0);
        });
      }
    } catch (e, st) {
      AppLogger.error('Profil yüklenirken hata oluştu', error: e, stackTrace: st);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadGoals() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(u.uid)
          .collection('settings').doc('health_goals').get();
      if (doc.exists && mounted) {
        final d = doc.data()!;
        setState(() {
          _targetWeight = (d['targetWeight'] as num?)?.toDouble() ?? 68.0;
          _targetSteps = (d['targetSteps'] as num?)?.toDouble() ?? 10000.0;
          _targetSleep = (d['targetSleep'] as num?)?.toDouble() ?? 8.0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    try {
      final entries = await FirebaseFirestore.instance
          .collection('users').doc(u.uid)
          .collection('health_entries')
          .orderBy('date', descending: true).limit(30).get();

      double totalSteps = 0, totalSleep = 0;
      int validDays = 0;
      for (var doc in entries.docs.take(7)) {
        final d = doc.data();
        final steps = (d['steps'] as num?)?.toDouble() ?? 0;
        final sleep = (d['sleep_hours'] as num?)?.toDouble() ?? 0;
        if (steps > 0 || sleep > 0) validDays++;
        totalSteps += steps;
        totalSleep += sleep;
      }

      if (mounted) {
        setState(() {
          if (validDays > 0) {
            _currentAvgSteps = totalSteps / validDays;
            _currentAvgSleep = totalSleep / validDays;
          }
        });
      }

      // Son senkronizasyon saatini ve bugünkü su verisini al
      final todayEntry = await HealthService.getTodayEntry();
      if (mounted) {
        setState(() {
          _lastSyncTime = todayEntry?.date;
          _currentWaterMl = todayEntry?.waterMl ?? 0;
        });
      }
    } catch (_) {}
  }

  /// Pull-to-refresh handler
  Future<void> _onRefresh() async {
    await Future.wait([
      _loadUser(),
      _loadGoals(),
      _loadStats(),
    ]);
  }

  double get _bmi => BmiUtils.calculate(_height, _userWeight);
  String get _bmiCategory => BmiUtils.category(_bmi, _age);
  Color get _bmiColor => BmiUtils.color(_bmi, _age);



  void _showEditProfileSheet({EditMode mode = EditMode.identity}) {
    EditProfileSheet(
      fullName: _fullName, bio: _bio, age: _age,
      gender: _gender, bloodType: _bloodType, 
      allergies: _allergies.join(', '), emergencyContact: _emergencyContact,
      height: _height, weight: _userWeight,
      mode: mode,
      onSaved: (result) {
        setState(() {
          _fullName = result.name;
          _bio = result.bio;
          _age = result.age;
          _gender = result.gender;
          _bloodType = result.bloodType;
          _allergies = result.allergies.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          _emergencyContact = result.emergencyContact;
          _height = result.height;
          _userWeight = result.weight;
        });
      },
    ).show(context);
  }

  void _showHealthGoalsSheet() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HealthGoalsSheet(uid: uid),
    ).then((_) => _loadGoals());
  }


  // ── Section Header Builder ────────────────────────────────────
  Widget _sectionHeader(String title, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Su progress hesapla
    final waterProgress = _targetWaterMl > 0 
        ? (_currentWaterMl / _targetWaterMl).clamp(0.0, 1.0) 
        : 0.0;
    final waterLabel = '${(_currentWaterMl / 1000).toStringAsFixed(1)} / ${(_targetWaterMl / 1000).toStringAsFixed(1)} L';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? const ProfileSkeleton()
          : RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppColors.primary,
              child: CustomScrollView(
                slivers: [
                  _buildSliverHeader(context),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ═══ SAĞLIK ÖZETİ ═══
                          _sectionHeader('Sağlık Özeti', Icons.analytics_outlined),

                          // 1. Aktivite Halkaları (Hızlı Özet)
                          ActivityRings(
                            stepsProgress: _targetSteps > 0 ? (_currentAvgSteps / _targetSteps).clamp(0.0, 1.0) : 0.0,
                            sleepProgress: _targetSleep > 0 ? (_currentAvgSleep / _targetSleep).clamp(0.0, 1.0) : 0.0,
                            waterProgress: waterProgress,
                            stepsLabel: '${_currentAvgSteps.toInt()} / ${(_targetSteps / 1000).toStringAsFixed(0)}k',
                            sleepLabel: '${_currentAvgSleep.toStringAsFixed(1)} / ${_targetSleep.toInt()} sa',
                            waterLabel: waterLabel,
                          ),
                          const SizedBox(height: 16),

                          BodyMetricsCard(
                            bmi: _bmi,
                            bmiCategory: _bmiCategory,
                            bmiColor: _bmiColor,
                            height: _height,
                            weight: _userWeight,
                            age: _age,
                            gender: _gender,
                            onEdit: () => _showEditProfileSheet(mode: EditMode.metrics),
                            onWeightTap: () => WeightUpdateSheet(
                              currentWeight: _userWeight,
                              userHeight: _height,
                              userAge: _age,
                              onSaved: (w) => setState(() => _userWeight = w),
                            ).show(context),
                          ),

                          // ═══ KLİNİK PROFİL ═══
                          _sectionHeader('Klinik Profil', Icons.medical_services_outlined),

                          ClinicalProfileCard(
                            bloodType: _bloodType,
                            allergies: _allergies,
                            dietPreference: _dietPreference,
                            onEdit: () => _showEditProfileSheet(mode: EditMode.identity),
                          ),
                          const SizedBox(height: 16),

                          // 3. Sağlık Hedefleri
                          HealthGoalsCard(
                            goals: _buildGoalItems(),
                            onEdit: _showHealthGoalsSheet,
                          ),
                          const SizedBox(height: 16),

                          // 4. Sağlık Raporu Dışa Aktarma
                          const ReportExportCard(),

                          // ═══ CİHAZ & BAĞLANTILAR ═══
                          _sectionHeader('Cihaz & Bağlantılar', Icons.devices_rounded),

                          // 5. Cihaz Merkezi (Dinamik Kaynak Takibi)
                          DeviceCenterCard(
                            data: HealthService.getLastSyncSourceInfo(),
                            lastSyncTime: _lastSyncTime,
                          ),
                          const SizedBox(height: 16),

                          // 6. Bağlantı Merkezi
                          const IntegrationsCard(),

                          // ═══ AYARLAR ═══
                          _sectionHeader('Ayarlar', Icons.settings_outlined),

                          // 7. Tercihler ve Bilgi
                          PreferencesCard(
                            onPrivacyTap: () => ProfileDialogs.showPrivacy(context),
                          ),
                          const SizedBox(height: 16),
                          AboutCard(
                            onHelpTap: () => ProfileDialogs.showHelp(context),
                            onTermsTap: () => ProfileDialogs.showTerms(context),
                            onPrivacyPolicyTap: () => ProfileDialogs.showPrivacyPolicy(context),
                            onDisclaimerTap: () => ProfileDialogs.showMedicalDisclaimer(context),
                          ),
                          const SizedBox(height: 32),
                          
                          // 8. Çıkış Butonu
                          const SignOutButton(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  List<GoalItem> _buildGoalItems() {
    final weightProgress = _targetWeight > 0 ? (1 - ((_userWeight - _targetWeight).abs() / _userWeight)).clamp(0.0, 1.0) : 0.0;
    final stepsProgress = _targetSteps > 0 ? (_currentAvgSteps / _targetSteps).clamp(0.0, 1.0) : 0.0;
    final sleepProgress = _targetSleep > 0 ? (_currentAvgSleep / _targetSleep).clamp(0.0, 1.0) : 0.0;

    return [
      GoalItem('Hedef Kilo', '${_userWeight.toStringAsFixed(1)} / ${_targetWeight.toInt()} kg', weightProgress, AppColors.primary),
      GoalItem('Günlük Adım', '${_currentAvgSteps.toInt()} / ${(_targetSteps / 1000).toStringAsFixed(0)}k ort.', stepsProgress, AppColors.secondary),
      GoalItem('Uyku Süresi', '${_currentAvgSleep.toStringAsFixed(1)} / ${_targetSleep.toStringAsFixed(0)} saat ort.', sleepProgress, AppColors.accent),
    ];
  }

  Widget _buildSliverHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppColors.primary,
      elevation: 0,
      stretch: true,
      centerTitle: true,
      title: const Text('Profilim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                HealthIdCard(
                  name: _fullName,
                  bloodType: _bloodType,
                  age: _age,
                  gender: _gender,
                  photoUrl: _photoUrl,
                  onTap: () => _showEditProfileSheet(mode: EditMode.identity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
