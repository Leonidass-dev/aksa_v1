import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../utils/image_utils.dart';
import '../utils/bmi_utils.dart';
import '../widgets/theme_aware_state.dart';
import 'package:aksa_v1/services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/profile/body_metrics_card.dart';
import '../widgets/profile/health_goals_card.dart';
import '../widgets/profile/preferences_card.dart';
import '../widgets/profile/about_card.dart';
import '../widgets/profile/sign_out_button.dart';
import '../widgets/profile/edit_profile_sheet.dart';
import '../widgets/profile/health_goals_sheet.dart';
import '../widgets/profile/weight_update_sheet.dart';
import '../widgets/profile/profile_dialogs.dart';
import '../widgets/profile/emergency_card.dart';
import '../services/health_service.dart';
import '../constants/app_constants.dart';
import '../widgets/profile/health_id_card.dart';
import '../widgets/profile/activity_rings.dart';
import '../widgets/profile/integrations_card.dart';
import '../widgets/profile/device_center_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with ThemeAwareMixin {
  bool _notifications = true;
  String _fullName = '';
  String _email = '';
  String _photoUrl = '';
  String _bio = '';
  int _age = 30;
  String _gender = 'M';
  double _height = 170.0;
  double _userWeight = 75.0;
  bool _loading = true;
  final ImagePicker _picker = ImagePicker();

  double _targetWeight = 68;
  double _targetSteps = 10000;
  double _targetSleep = 8;

  String _activeDays = '0';
  String _dataPoints = '0';
  String _healthScore = '-';

  // Acil Durum Bilgileri
  String _bloodType = '';
  String _allergies = '';
  String _emergencyContact = '';
  DateTime? _lastSyncTime;

  double _currentAvgSteps = 0;
  double _currentAvgSleep = 0;
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
      _email = u.email ?? '';
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
          _allergies = data['allergies'] ?? '';
          _emergencyContact = data['emergencyContact'] ?? '';
        });
      }
    } catch (_) {}
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
      final count = entries.docs.length;

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
          _activeDays = count.toString();
          _dataPoints = (count * 5).toString();
          if (validDays > 0) {
            _currentAvgSteps = totalSteps / validDays;
            _currentAvgSleep = totalSleep / validDays;
          }
        });
      }

      // Son senkronizasyon saatini al
      final todayEntry = await HealthService.getTodayEntry();
      if (mounted) {
        setState(() => _lastSyncTime = todayEntry?.date);
      }
    } catch (_) {}
  }

  double get _bmi => BmiUtils.calculate(_height, _userWeight);
  String get _bmiCategory => BmiUtils.category(_bmi, _age);
  Color get _bmiColor => BmiUtils.color(_bmi, _age);

  double get _completionRate {
    double score = 0;
    if (_fullName.isNotEmpty) score += 0.2;
    if (_age > 0) score += 0.2;
    if (_height > 0) score += 0.2;
    if (_userWeight > 0) score += 0.2;
    if (_bloodType.isNotEmpty) score += 0.1;
    if (_emergencyContact.isNotEmpty) score += 0.1;
    return score.clamp(0.0, 1.0);
  }

  void _showEditProfileSheet({EditMode mode = EditMode.identity}) {
    EditProfileSheet(
      fullName: _fullName, bio: _bio, age: _age,
      gender: _gender, bloodType: _bloodType, 
      allergies: _allergies, emergencyContact: _emergencyContact,
      height: _height, weight: _userWeight,
      mode: mode,
      onSaved: (result) {
        setState(() {
          _fullName = result.name;
          _bio = result.bio;
          _age = result.age;
          _gender = result.gender;
          _bloodType = result.bloodType;
          _allergies = result.allergies;
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

  Future<void> _pickProfilePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        setState(() => _photoUrl = image.path);
      }
    } catch (e) {
      debugPrint('Fotoğraf seçme hatası: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildSliverHeader(context),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    child: Column(
                      children: [
                        // 1. Aktivite Halkaları (Hızlı Özet)
                        ActivityRings(
                          stepsProgress: _targetSteps > 0 ? (_currentAvgSteps / _targetSteps).clamp(0.0, 1.0) : 0.0,
                          sleepProgress: _targetSleep > 0 ? (_currentAvgSleep / _targetSleep).clamp(0.0, 1.0) : 0.0,
                          waterProgress: 0.7, 
                          stepsLabel: '${_currentAvgSteps.toInt()} / ${(_targetSteps / 1000).toStringAsFixed(0)}k',
                          sleepLabel: '${_currentAvgSleep.toStringAsFixed(1)} / ${_targetSleep.toInt()} sa',
                          waterLabel: '1.4 / 2.0 L',
                        ),
                        const SizedBox(height: 20),

                        // 2. Vücut Metrikleri (Boy, Kilo, BMI)
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
                        const SizedBox(height: 16),

                        // 3. Sağlık Hedefleri
                        HealthGoalsCard(
                          goals: _buildGoalItems(),
                          onEdit: _showHealthGoalsSheet,
                        ),
                        const SizedBox(height: 16),

                        const SizedBox(height: 20),

                        // 5. Cihaz Merkezi (Dinamik Kaynak Takibi)
                        DeviceCenterCard(
                          data: HealthService.getLastSyncSourceInfo(),
                          lastSyncTime: _lastSyncTime,
                        ),
                        const SizedBox(height: 16),

                        // 6. Bağlantı Merkezi (En altta, sistem katmanı olarak)
                        const IntegrationsCard(),
                        const SizedBox(height: 20),

                        // 6. Tercihler ve Bilgi
                        PreferencesCard(
                          notifications: _notifications,
                          onNotificationChanged: (v) => setState(() => _notifications = v),
                          onPrivacyTap: () => ProfileDialogs.showPrivacy(context),
                        ),
                        const SizedBox(height: 16),
                        AboutCard(
                          onHelpTap: () => ProfileDialogs.showHelp(context),
                          onTermsTap: () => ProfileDialogs.showTerms(context),
                          onPrivacyPolicyTap: () => ProfileDialogs.showPrivacyPolicy(context),
                        ),
                        const SizedBox(height: 32),
                        
                        // 7. Çıkış Butonu
                        const SignOutButton(),
                      ],
                    ),
                  ),
                ),
              ],
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
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Profilim', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 48), // Denge için
                    ],
                  ),
                ),
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

  Widget _buildCompletionCard() {
    final pct = (_completionRate * 100).toInt();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Profil Tamamlama', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              Text('%$pct', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: _completionRate, backgroundColor: AppColors.primary.withValues(alpha: 0.1), valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary)),
        ],
      ),
    );
  }
}
