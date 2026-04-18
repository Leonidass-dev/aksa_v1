import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_notifier.dart';
import '../utils/image_utils.dart';
import '../widgets/theme_aware_state.dart';
import '../widgets/common_widgets.dart';
import '../services/api_service.dart';
import '../models/api_models.dart';
import '../services/user_profile_service.dart';
import '../services/health_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with ThemeAwareMixin {
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

  // Gerçek ilerleme verileri
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
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(u.uid)
          .get();
      if (doc.exists) {
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
          'uid': u.uid,
          'fullName': _fullName,
          'email': _email,
          'photoUrl': _photoUrl,
          'bio': '',
        });
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _loadGoals() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(u.uid)
          .collection('settings')
          .doc('health_goals')
          .get();
      if (doc.exists) {
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
          .collection('users')
          .doc(u.uid)
          .collection('health_entries')
          .orderBy('date', descending: true)
          .limit(30)
          .get();
      final count = entries.docs.length;

      // Son 7 günün ortalamasını hesapla
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

      setState(() {
        _activeDays = count.toString();
        _dataPoints = (count * 5).toString();
        if (validDays > 0) {
          _currentAvgSteps = totalSteps / validDays;
          _currentAvgSleep = totalSleep / validDays;
        }
      });

      // Risk geçmişinden en son skoru al
      final history = await FirebaseFirestore.instance
          .collection('users')
          .doc(u.uid)
          .collection('risk_history')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (history.docs.isNotEmpty) {
        final riskScore = history.docs.first.data()['score'] as num?;
        if (riskScore != null) {
          int health = 100 - riskScore.toInt();
          setState(() {
            _healthScore = health.toString();
          });
        }
      }
    } catch (_) {}
  }


  // ── Profil Düzenleme BottomSheet ────────────────────────────────
  void _showEditProfileSheet() {
    final nameCtrl = TextEditingController(text: _fullName);
    final bioCtrl = TextEditingController(text: _bio);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        nameCtrl: nameCtrl,
        bioCtrl: bioCtrl,
        age: _age,
        gender: _gender,
        height: _height,
        weight: _userWeight,
        onSave: (name, bio, age, gender, height, weight) async {
          final u = FirebaseAuth.instance.currentUser;
          if (u == null) return;
          await u.updateDisplayName(name);
          await FirebaseFirestore.instance.collection('users').doc(u.uid).update({
            'fullName': name,
            'bio': bio,
            'age': age,
            'gender': gender,
            'height': height,
            'weight': weight,
          });

          // MODÜL 3: Risk Skorunu Güncelle (Profil değişikliği sonrası)
          await ApiService.fetchRiskScore(
            RiskApiRequest(
              age: age,
              gender: gender,
              height: height,
              weight: weight,
            ),
          );

          setState(() {
            _fullName = name;
            _bio = bio;
            _age = age;
            _gender = gender;
            _height = height;
            _userWeight = weight;
          });
        },
      ),
    );
  }

  // ── Hakkımda Düzenleme Dialog ────────────────────────────────────
  void _showEditBioDialog() {
    final ctrl = TextEditingController(text: _bio);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hakkımda'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          maxLength: 200,
          decoration: const InputDecoration(
            hintText: 'Kendiniz hakkında kısa bir bilgi yazın...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () async {
              final u = FirebaseAuth.instance.currentUser;
              if (u != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(u.uid)
                    .update({'bio': ctrl.text.trim()});
                setState(() => _bio = ctrl.text.trim());
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  // ── Gizlilik Dialog ──────────────────────────────────────────────
  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gizlilik ve Güvenlik'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PrivacyItem(
              icon: Icons.health_and_safety_outlined,
              title: 'Sağlık Verileriniz',
              desc:
                  'Sağlık verileriniz yalnızca size özel yapay zeka analizleri için kullanılır. Üçüncü taraflarla paylaşılmaz.',
            ),
            SizedBox(height: 16),
            _PrivacyItem(
              icon: Icons.lock_outlined,
              title: 'Şifreleme',
              desc:
                  'Tüm verileriniz Firebase güvenlik altyapısıyla şifrelenmiş olarak saklanır.',
            ),
            SizedBox(height: 16),
            _PrivacyItem(
              icon: Icons.delete_outline,
              title: 'Veri Silme',
              desc:
                  'Hesabınızı sildiğinizde tüm kişisel verileriniz kalıcı olarak silinir.',
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anladım'),
          ),
        ],
      ),
    );
  }

  // ── Sağlık Hedefleri Düzenleme ───────────────────────────────────
  void _showHealthGoalsSheet() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HealthGoalsSheet(uid: uid),
    ).then((_) {
      _loadGoals(); // Bottom sheet kapanınca hedefleri yenile
    });
  }

  // ── Yardım Dialog ────────────────────────────────────────────────
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yardım ve Destek'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HelpItem(
              icon: Icons.play_circle_outline,
              title: 'Nasıl kullanılır?',
              desc:
                  'Her gün veri girerek yapay zeka analizi alabilirsiniz. Sağlık → Veri Gir menüsünden başlayın.',
            ),
            SizedBox(height: 12),
            _HelpItem(
              icon: Icons.sync_outlined,
              title: 'Veri senkronizasyonu',
              desc:
                  'Health Connect destekli cihazlarda verileriniz otomatik alınabilir.',
            ),
            SizedBox(height: 12),
            _HelpItem(
              icon: Icons.mail_outline,
              title: 'İletişim',
              desc:
                  'Sorun yaşıyorsanız destek@aksa.app adresine yazabilirsiniz.',
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  // ── Kullanım Koşulları Dialog ─────────────────────────────────────
  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kullanım Koşulları'),
        content: const SingleChildScrollView(
          child: Text(
            'Bu uygulama kişisel sağlık takibi amacıyla geliştirilmiştir. '
            'Uygulama tıbbi teşhis veya tedavi amaçlı kullanılamaz. '
            'Sağlık sorunlarınız için mutlaka bir sağlık profesyoneline danışın.\n\n'
            'Verileriniz güvenli şekilde saklanmakta olup üçüncü taraflarla '
            'paylaşılmamaktadır. Uygulamayı kullanarak bu koşulları kabul etmiş sayılırsınız.',
            style: TextStyle(height: 1.6),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anladım'),
          ),
        ],
      ),
    );
  }

  // ── Gizlilik Politikası Dialog ─────────────────────────────────────
  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gizlilik Politikası'),
        content: const SingleChildScrollView(
          child: Text(
            'Topladığımız veriler: ad, e-posta, sağlık metrikleri (kan basıncı, adım sayısı, uyku süresi).\n\n'
            'Verileriniz Firebase altyapısında şifreli olarak tutulur. '
            'Yapay zeka analizleri yalnızca kendi sunucularımızda gerçekleştirilir.\n\n'
            'Hesabınızı sildiğinizde tüm verileriniz 30 gün içinde kalıcı olarak silinir.',
            style: TextStyle(height: 1.6),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anladım'),
          ),
        ],
      ),
    );
  }

  // ── BMI Hesaplama ──────────────────────────────────────────────────
  double get _bmi {
    if (_height <= 0 || _userWeight <= 0) return 0;
    return _userWeight / ((_height / 100) * (_height / 100));
  }

  String get _bmiCategory {
    final b = _bmi;
    if (b <= 0) return '-';
    if (b < 18.5) return 'Zayıf';
    if (b < 25) return 'Normal';
    if (b < 30) return 'Fazla Kilolu';
    return 'Obez';
  }

  Color get _bmiColor {
    final b = _bmi;
    if (b < 18.5) return AppColors.accent;
    if (b < 25) return AppColors.secondary;
    if (b < 30) return AppColors.accent;
    return AppColors.destructive;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ── Sabit Header ──
                SliverAppBar(
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
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primary, AppColors.primaryLight],
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          child: Column(
                            children: [
                              // Top row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Profilim',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
                              // Profile info row
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
                                      child: _photoUrl.isEmpty
                                          ? const Icon(Icons.person, color: Colors.white, size: 32)
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _fullName.isNotEmpty ? _fullName : 'İsimsiz Kullanıcı',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _email,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.7),
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (_bio.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            _bio,
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.6),
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
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
                ),

                // ── Body ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    child: Column(
                      children: [
                        _buildQuickStats(context),
                        const SizedBox(height: 16),
                        _buildBodyMetrics(context),
                        const SizedBox(height: 16),
                        _buildHealthGoals(context),
                        const SizedBox(height: 16),
                        _buildPreferences(context),
                        const SizedBox(height: 16),
                        _buildAbout(context),
                        const SizedBox(height: 16),
                        _buildSignOut(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ── Hızlı İstatistikler ──
  Widget _buildQuickStats(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _quickStat(cs, _healthScore, 'Sağlık\nSkoru', AppColors.secondary),
          Container(width: 1, height: 40, color: cs.outlineVariant),
          _quickStat(cs, _activeDays, 'Aktif\nGün', AppColors.primary),
          Container(width: 1, height: 40, color: cs.outlineVariant),
          _quickStat(cs, _dataPoints, 'Veri\nNoktası', AppColors.accent),
        ],
      ),
    );
  }

  Widget _quickStat(ColorScheme cs, String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant, height: 1.3),
        ),
      ],
    );
  }

  // ── Vücut Metrikleri (BMI + Boy/Kilo/Yaş) ──
  Widget _buildBodyMetrics(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Vücut Metrikleri', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
              GestureDetector(
                onTap: _showEditProfileSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Düzenle',
                    style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // BMI Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _bmiColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _bmiColor.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _bmiColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.monitor_weight_outlined, color: _bmiColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vücut Kitle İndeksi (BMI)', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _bmi > 0 ? _bmi.toStringAsFixed(1) : '--',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _bmiColor),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _bmiColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _bmiCategory,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _bmiColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Body stats row
          Row(
            children: [
              _bodyMetricChip(cs, Icons.height, 'Boy', '${_height.toInt()} cm'),
              const SizedBox(width: 8),
              _bodyMetricChip(cs, Icons.monitor_weight_outlined, 'Kilo', '${_userWeight.toStringAsFixed(1)} kg', onTap: _showWeightUpdateSheet),
              const SizedBox(width: 8),
              _bodyMetricChip(cs, Icons.cake_outlined, 'Yaş', '$_age'),
              const SizedBox(width: 8),
              _bodyMetricChip(cs, Icons.wc, 'Cinsiyet', _gender == 'M' ? 'Erkek' : 'Kadın'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bodyMetricChip(ColorScheme cs, IconData icon, String label, String value, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: onTap != null ? Border.all(color: AppColors.primary.withValues(alpha: 0.2)) : null,
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: onTap != null ? AppColors.primary : cs.onSurfaceVariant),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface)),
              Text(label, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hızlı Kilo Güncelleme ──
  void _showWeightUpdateSheet() {
    double newWeight = _userWeight;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final cs = Theme.of(ctx).colorScheme;
          final newBmi = newWeight / ((_height / 100) * (_height / 100));
          String bmiCat;
          Color bmiCol;
          if (newBmi < 18.5) { bmiCat = 'Zayıf'; bmiCol = AppColors.accent; }
          else if (newBmi < 25) { bmiCat = 'Normal'; bmiCol = AppColors.secondary; }
          else if (newBmi < 30) { bmiCat = 'Fazla Kilolu'; bmiCol = AppColors.accent; }
          else { bmiCat = 'Obez'; bmiCol = AppColors.destructive; }

          return Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Kilo Güncelle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
                const SizedBox(height: 20),
                Text(
                  '${newWeight.toStringAsFixed(1)} kg',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: cs.onSurface),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('BMI: ${newBmi.toStringAsFixed(1)} ', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: bmiCol.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(bmiCat, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: bmiCol)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.primary,
                    thumbColor: AppColors.primary,
                    inactiveTrackColor: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: newWeight, min: 30, max: 200,
                    onChanged: (v) => setLocal(() => newWeight = double.parse(v.toStringAsFixed(1))),
                  ),
                ),
                const SizedBox(height: 8),
                // +/- butonları
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _weightBtn(ctx, '-1', () => setLocal(() => newWeight = (newWeight - 1).clamp(30, 200))),
                    const SizedBox(width: 8),
                    _weightBtn(ctx, '-0.1', () => setLocal(() => newWeight = double.parse((newWeight - 0.1).clamp(30, 200).toStringAsFixed(1)))),
                    const SizedBox(width: 8),
                    _weightBtn(ctx, '+0.1', () => setLocal(() => newWeight = double.parse((newWeight + 0.1).clamp(30, 200).toStringAsFixed(1)))),
                    const SizedBox(width: 8),
                    _weightBtn(ctx, '+1', () => setLocal(() => newWeight = (newWeight + 1).clamp(30, 200))),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      // Profile güncelle
                      final profile = await UserProfileService.getProfile();
                      if (profile != null) {
                        final updated = UserProfile(
                          uid: profile.uid,
                          fullName: profile.fullName,
                          email: profile.email,
                          age: profile.age,
                          height: profile.height,
                          weight: newWeight,
                          gender: profile.gender,
                          photoUrl: profile.photoUrl,
                          bio: profile.bio,
                        );
                        await UserProfileService.saveProfile(updated);
                      }
                      // Bugünkü entry'ye de yaz
                      final existing = await HealthService.getTodayEntry();
                      final entry = (existing ?? HealthEntry(date: DateTime.now())).copyWith(
                        weight: newWeight,
                        source: 'manual',
                      );
                      await HealthService.saveHealthEntry(entry);

                      if (ctx.mounted) Navigator.pop(ctx);
                      setState(() => _userWeight = newWeight);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Kaydet', style: TextStyle(fontSize: 15)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _weightBtn(BuildContext context, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
      ),
    );
  }

  // ── Sağlık Hedefleri (gerçek verilerle) ──
  Widget _buildHealthGoals(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Gerçek ilerlemeleri hesapla
    final weightProgress = _targetWeight > 0
        ? (1 - ((_userWeight - _targetWeight).abs() / _userWeight)).clamp(0.0, 1.0)
        : 0.0;
    final stepsProgress = _targetSteps > 0
        ? (_currentAvgSteps / _targetSteps).clamp(0.0, 1.0)
        : 0.0;
    final sleepProgress = _targetSleep > 0
        ? (_currentAvgSleep / _targetSleep).clamp(0.0, 1.0)
        : 0.0;

    final goals = [
      _Goal(
        'Hedef Kilo',
        '${_userWeight.toStringAsFixed(1)} / ${_targetWeight.toInt()} kg',
        weightProgress,
        AppColors.primary,
      ),
      _Goal(
        'Günlük Adım',
        '${_currentAvgSteps.toInt()} / ${(_targetSteps / 1000).toStringAsFixed(0)}k ort.',
        stepsProgress,
        AppColors.secondary,
      ),
      _Goal(
        'Uyku Süresi',
        '${_currentAvgSleep.toStringAsFixed(1)} / ${_targetSleep.toStringAsFixed(0)} saat ort.',
        sleepProgress,
        AppColors.accent,
      ),
    ];

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sağlık Hedefleri', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
              GestureDetector(
                onTap: _showHealthGoalsSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Düzenle',
                    style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...goals.map((g) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        g.label,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface),
                      ),
                      Text(
                        g.value,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: g.color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: g.progress,
                            minHeight: 6,
                            backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(g.color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(g.progress * 100).toInt()}%',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: g.color),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildPreferences(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = themeNotifier.value == ThemeMode.dark;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tercihler', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 16),
          _toggleRow(
            context,
            Icons.notifications_outlined,
            AppColors.primary,
            'Bildirimler',
            'Anlık bildirimler ve uyarılar',
            _notifications,
            (v) => setState(() => _notifications = v),
          ),
          Divider(color: cs.outlineVariant, height: 24),
          _toggleRow(
            context,
            Icons.dark_mode_outlined,
            AppColors.accent,
            'Karanlık Mod',
            'Karanlık temaya geç',
            isDark,
            (v) => setState(() {
              themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
            }),
          ),
          Divider(color: cs.outlineVariant, height: 24),
          InkWell(
            onTap: _showPrivacyDialog,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_outlined, color: AppColors.secondary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gizlilik ve Güvenlik', style: TextStyle(fontWeight: FontWeight.w500, color: cs.onSurface)),
                      Text('Veri koruma ayarları', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleRow(
    BuildContext context,
    IconData icon,
    Color color,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: cs.onSurface)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildAbout(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = [
      ('Yardım ve Destek', _showHelpDialog),
      ('Kullanım Koşulları', _showTermsDialog),
      ('Gizlilik Politikası', _showPrivacyPolicyDialog),
    ];
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hakkında', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 16),
          ...items.map(
            (item) => Column(
              children: [
                InkWell(
                  onTap: item.$2,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item.$1, style: TextStyle(color: cs.onSurface)),
                        Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
                      ],
                    ),
                  ),
                ),
                Divider(color: cs.outlineVariant, height: 1),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'AKSA v1.0.0 • Akıllı Kişisel Sağlık Asistanı',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOut(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Çıkış Yap'),
              content: const Text(
                'Hesabınızdan çıkmak istediğinize emin misiniz?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.destructive,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Çıkış Yap'),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await AuthService.signOut();
            if (context.mounted) context.go('/login');
          }
        },
        style: TextButton.styleFrom(
          backgroundColor: AppColors.destructive.withValues(alpha: 0.1),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.logout, color: AppColors.destructive),
        label: const Text(
          'Çıkış Yap',
          style: TextStyle(
            color: AppColors.destructive,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Profil Düzenleme BottomSheet ─────────────────────────────────────────────
class _EditProfileSheet extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController bioCtrl;
  final int age;
  final String gender;
  final double height;
  final double weight;
  final Future<void> Function(String name, String bio, int age, String gender, double height, double weight) onSave;

  const _EditProfileSheet({
    required this.nameCtrl,
    required this.bioCtrl,
    required this.age,
    required this.gender,
    required this.height,
    required this.weight,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ageCtrl = TextEditingController(text: age.toString());
    final heightCtrl = TextEditingController(text: height.toString());
    String selectedGender = gender;
    double selectedWeight = weight;

    return StatefulBuilder(
      builder: (context, setInternalState) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Profili Düzenle',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Ad Soyad',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Yaş',
                        prefixIcon: const Icon(Icons.cake_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: heightCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Boy (cm)',
                        prefixIcon: const Icon(Icons.height),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: selectedWeight.toString()),
                keyboardType: TextInputType.number,
                onChanged: (v) => setInternalState(() => selectedWeight = double.tryParse(v) ?? selectedWeight),
                decoration: InputDecoration(
                  labelText: 'Kilo (kg)',
                  prefixIcon: const Icon(Icons.monitor_weight_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedGender,
                decoration: InputDecoration(
                  labelText: 'Cinsiyet',
                  prefixIcon: const Icon(Icons.wc),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'M', child: Text('Erkek')),
                  DropdownMenuItem(value: 'F', child: Text('Kadın')),
                ],
                onChanged: (v) {
                  if (v != null) setInternalState(() => selectedGender = v);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bioCtrl,
                maxLines: 2,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: 'Hakkımda',
                  prefixIcon: const Icon(Icons.info_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final ageVal = int.tryParse(ageCtrl.text) ?? 30;
                    final heightVal = double.tryParse(heightCtrl.text) ?? 170.0;
                    await onSave(
                      nameCtrl.text.trim(),
                      bioCtrl.text.trim(),
                      ageVal,
                      selectedGender,
                      heightVal,
                      selectedWeight,
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Kaydet', style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sağlık Hedefleri BottomSheet ──────────────────────────────────────────────
class _HealthGoalsSheet extends StatefulWidget {
  final String uid;
  const _HealthGoalsSheet({required this.uid});

  @override
  State<_HealthGoalsSheet> createState() => _HealthGoalsSheetState();
}

class _HealthGoalsSheetState extends State<_HealthGoalsSheet> {
  double _targetWeight = 68;
  double _targetSteps = 10000;
  double _targetSleep = 8;
  bool _saving = false;
  bool _loadingGoals = true;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('settings')
          .doc('health_goals')
          .get();
      if (doc.exists) {
        final d = doc.data()!;
        setState(() {
          _targetWeight = (d['targetWeight'] as num?)?.toDouble() ?? 68;
          _targetSteps = (d['targetSteps'] as num?)?.toDouble() ?? 10000;
          _targetSleep = (d['targetSleep'] as num?)?.toDouble() ?? 8;
        });
      }
    } catch (_) {}
    setState(() => _loadingGoals = false);
  }

  Future<void> _saveGoals() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('settings')
          .doc('health_goals')
          .set({
            'targetWeight': _targetWeight,
            'targetSteps': _targetSteps,
            'targetSleep': _targetSleep,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kaydedilemedi, tekrar deneyin.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _loadingGoals
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Sağlık Hedefleri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 24),
                _goalSlider(
                  cs,
                  'Hedef Kilo',
                  '${_targetWeight.toInt()} kg',
                  _targetWeight,
                  40,
                  150,
                  (v) => setState(() => _targetWeight = v),
                  AppColors.primary,
                ),
                const SizedBox(height: 16),
                _goalSlider(
                  cs,
                  'Günlük Adım',
                  '${(_targetSteps / 1000).toStringAsFixed(1)}k',
                  _targetSteps,
                  2000,
                  20000,
                  (v) => setState(() => _targetSteps = v),
                  AppColors.secondary,
                ),
                const SizedBox(height: 16),
                _goalSlider(
                  cs,
                  'Uyku Süresi',
                  '${_targetSleep.toStringAsFixed(1)} saat',
                  _targetSleep,
                  5,
                  12,
                  (v) => setState(() => _targetSleep = v),
                  AppColors.accent,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _saveGoals,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Kaydet', style: TextStyle(fontSize: 15)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _goalSlider(
    ColorScheme cs,
    String label,
    String valueText,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
            Text(
              valueText,
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            thumbColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.2),
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}

// ── Yardımcı Widget'lar ───────────────────────────────────────────────────────
class _PrivacyItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _PrivacyItem({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _HelpItem({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Goal {
  final String label, value;
  final double progress;
  final Color color;
  const _Goal(this.label, this.value, this.progress, this.color);
}
