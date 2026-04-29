import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../utils/image_utils.dart';
import '../utils/bmi_utils.dart';
import '../widgets/theme_aware_state.dart';
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

  double _targetWeight = 68;
  double _targetSteps = 10000;
  double _targetSleep = 8;

  String _activeDays = '0';
  String _dataPoints = '0';
  String _healthScore = '-';

  double _currentAvgSteps = 0;
  double _currentAvgSleep = 0;

  // ── Lifecycle ────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadGoals();
    _loadStats();
  }

  // ── Data Loading ─────────────────────────────────────────────────

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
        });
      } else {
        await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
          'uid': u.uid, 'fullName': _fullName, 'email': _email, 'photoUrl': _photoUrl, 'bio': '',
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
        final sleep = (d['sleepHours'] as num?)?.toDouble() ?? 0;
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

      final history = await FirebaseFirestore.instance
          .collection('users').doc(u.uid)
          .collection('risk_history')
          .orderBy('timestamp', descending: true).limit(1).get();

      if (history.docs.isNotEmpty && mounted) {
        final riskScore = history.docs.first.data()['score'] as num?;
        if (riskScore != null) {
          setState(() => _healthScore = (100 - riskScore.toInt()).toString());
        }
      }
    } catch (_) {}
  }

  // ── BMI Hesaplama (BmiUtils'e delege) ────────────────────────────

  double get _bmi => BmiUtils.calculate(_height, _userWeight);
  String get _bmiCategory => BmiUtils.category(_bmi, _age);
  Color get _bmiColor => BmiUtils.color(_bmi, _age);

  double get _completionRate {
    double score = 0;
    if (_fullName.isNotEmpty && _fullName != 'Kullanıcı' && _fullName != 'Guest') score += 0.2;
    if (_age > 0) score += 0.2;
    if (_height > 0) score += 0.2;
    if (_userWeight > 0) score += 0.2;
    if (_gender.isNotEmpty) score += 0.1;
    if (_bio.isNotEmpty) score += 0.1;
    return score;
  }

  // ── Actions ──────────────────────────────────────────────────────

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

  // ── UI Build ─────────────────────────────────────────────────────

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
                        const SizedBox(height: 16),
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
    final weightProgress = _targetWeight > 0
        ? (1 - ((_userWeight - _targetWeight).abs() / _userWeight)).clamp(0.0, 1.0)
        : 0.0;
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
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Profilim', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      GestureDetector(
                        onTap: _showEditProfileSheet,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 32,
                          backgroundImage: ImageUtils.getPhotoProvider(_photoUrl),
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          child: _photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 32) : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _fullName.isNotEmpty ? _fullName : 'İsimsiz Kullanıcı',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(_email, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                            if (_bio.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _bio,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ],
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
        titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
        title: const SizedBox.shrink(),
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
              Row(
                children: [
                  const Icon(Icons.stars_rounded, color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Profil Tamamlama',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary.withValues(alpha: 0.8)),
                  ),
                ],
              ),
              Text(
                '%$pct',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _completionRate,
              minHeight: 8,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Profilinizi tamamlayarak daha doğru sağlık analizleri alabilirsiniz.',
            style: TextStyle(fontSize: 11, color: AppColors.mutedForeground),
          ),
        ],
      ),
    );
  }
}
