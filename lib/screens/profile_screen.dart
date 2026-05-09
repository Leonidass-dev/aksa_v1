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
import '../widgets/profile/quick_stats_card.dart';
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
import '../widgets/profile/device_status_card.dart';
import '../services/health_service.dart';
import '../constants/app_constants.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadGoals();
    _loadStats();
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

  void _showEditProfileSheet() {
    EditProfileSheet(
      fullName: _fullName, bio: _bio, age: _age,
      gender: _gender, height: _height, weight: _userWeight,
      onSaved: (result) {
        setState(() {
          _fullName = result.name;
          _bio = result.bio;
          _age = result.age;
          _gender = result.gender;
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

  void _showEmergencyEditDialog() {
    final bloodController = TextEditingController(text: _bloodType);
    final allergyController = TextEditingController(text: _allergies);
    final contactController = TextEditingController(text: _emergencyContact);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dijital Sağlık Kartı'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: bloodController, decoration: const InputDecoration(labelText: 'Kan Grubu (Örn: A Rh+)')),
            TextField(controller: allergyController, decoration: const InputDecoration(labelText: 'Alerjiler')),
            TextField(controller: contactController, decoration: const InputDecoration(labelText: 'Acil Durum Kişisi & No')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                await FirebaseFirestore.instance.collection('users').doc(uid).update({
                  'bloodType': bloodController.text,
                  'allergies': allergyController.text,
                  'emergencyContact': contactController.text,
                });
                if (!mounted) return;
                setState(() {
                  _bloodType = bloodController.text;
                  _allergies = allergyController.text;
                  _emergencyContact = contactController.text;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
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
                        QuickStatsCard(
                          healthScore: _healthScore,
                          activeDays: _activeDays,
                          dataPoints: _dataPoints,
                        ),
                        const SizedBox(height: 16),
                        DeviceStatusCard(lastSync: _lastSyncTime),
                        const SizedBox(height: 16),
                        EmergencyCard(
                          bloodType: _bloodType,
                          allergies: _allergies,
                          emergencyContact: _emergencyContact,
                          onEdit: _showEmergencyEditDialog,
                        ),
                        if (_completionRate < 1.0) ...[
                          const SizedBox(height: 16),
                          _buildCompletionCard(),
                        ],
                        const SizedBox(height: 16),
                        BodyMetricsCard(
                          bmi: _bmi,
                          bmiCategory: _bmiCategory,
                          bmiColor: _bmiColor,
                          height: _height,
                          weight: _userWeight,
                          age: _age,
                          gender: _gender,
                          onEdit: _showEditProfileSheet,
                          onWeightTap: () => WeightUpdateSheet(
                            currentWeight: _userWeight,
                            userHeight: _height,
                            userAge: _age,
                            onSaved: (w) => setState(() => _userWeight = w),
                          ).show(context),
                        ),
                        const SizedBox(height: 16),
                        HealthGoalsCard(
                          goals: _buildGoalItems(),
                          onEdit: _showHealthGoalsSheet,
                        ),
                        const SizedBox(height: 16),
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
                        const SizedBox(height: 24),
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
      expandedHeight: 200,
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
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Profilim', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: _showEditProfileSheet, icon: const Icon(Icons.edit_outlined, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundImage: ImageUtils.getPhotoProvider(_photoUrl),
                        child: _photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 32) : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_fullName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(_email, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
