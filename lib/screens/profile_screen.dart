import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_notifier.dart';
import '../utils/image_utils.dart';
import '../widgets/theme_aware_state.dart';

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
  bool _loading = true;

  double _targetWeight = 68;
  double _targetSteps = 10000;
  double _targetSleep = 8;

  String _activeDays = '0';
  String _dataPoints = '0';
  String _healthScore = '-';

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
          .get();
      final count = entries.docs.length;
      setState(() {
        _activeDays = count.toString();
        _dataPoints = (count * 5).toString();
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
        onSave: (name, bio) async {
          final u = FirebaseAuth.instance.currentUser;
          if (u == null) return;
          await u.updateDisplayName(name);
          await FirebaseFirestore.instance
              .collection('users')
              .doc(u.uid)
              .update({'fullName': name, 'bio': bio});
          setState(() {
            _fullName = name;
            _bio = bio;
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

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(context),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      children: [
                        _buildProfileCard(context),
                        const SizedBox(height: 16),
                        _buildPersonalInfo(context),
                        const SizedBox(height: 16),
                        _buildPreferences(context),
                        const SizedBox(height: 16),
                        _buildHealthGoals(context),
                        const SizedBox(height: 16),
                        _buildAbout(context),
                        const SizedBox(height: 16),
                        _buildSignOut(context),
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
      height: 160,
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
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Profilim',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Hesabınızı yönetin',
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

  Widget _buildProfileCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Transform.translate(
      offset: const Offset(0, -40),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
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
            Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundImage: ImageUtils.getPhotoProvider(_photoUrl),
                  backgroundColor: AppColors.primary,
                  child: _photoUrl.isEmpty
                      ? const Icon(Icons.person, color: Colors.white, size: 36)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fullName.isNotEmpty ? _fullName : 'İsimsiz Kullanıcı',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        _email,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      if (_bio.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _bio,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // ── Düzenle butonu ──
                GestureDetector(
                  onTap: _showEditProfileSheet,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Divider(color: cs.outlineVariant),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _profileStat(context, _healthScore, 'Sağlık Skoru'),
                _profileStat(context, _activeDays, 'Aktif Gün'),
                _profileStat(context, _dataPoints, 'Veri Noktası'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileStat(BuildContext context, String value, String label) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildPersonalInfo(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = [
      _InfoItem(
        Icons.mail_outline,
        'Email',
        _email.isNotEmpty ? _email : '-',
        null,
      ),
      _InfoItem(
        Icons.info_outline,
        'Hakkımda',
        _bio.isNotEmpty ? _bio : 'Eklemek için dokunun',
        _showEditBioDialog,
      ),
    ];
    return _sectionCard(
      context: context,
      title: 'Kişisel Bilgiler',
      child: Column(
        children: items.asMap().entries.map((e) {
          return Column(
            children: [
              InkWell(
                onTap: e.value.onTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(e.value.icon, color: cs.onSurfaceVariant, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.value.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              e.value.value,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: e.value.onTap != null
                                    ? cs.onSurface
                                    : cs.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (e.value.onTap != null)
                        Icon(
                          Icons.chevron_right,
                          color: cs.onSurfaceVariant,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
              if (e.key < items.length - 1)
                Divider(color: cs.outlineVariant, height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPreferences(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = themeNotifier.value == ThemeMode.dark;
    return _sectionCard(
      context: context,
      title: 'Tercihler',
      child: Column(
        children: [
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
          // ── Gizlilik ve Güvenlik — tıklanabilir ──
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
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppColors.secondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gizlilik ve Güvenlik',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        'Veri koruma ayarları',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
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
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
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

  Widget _buildHealthGoals(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final goals = [
      _Goal(
        'Hedef Kilo',
        '${_targetWeight.toInt()} kg',
        0.60,
        AppColors.primary,
      ),
      _Goal(
        'Günlük Adım',
        '${(_targetSteps / 1000).toStringAsFixed(1)}k',
        0.84,
        AppColors.secondary,
      ),
      _Goal(
        'Uyku Süresi',
        '${_targetSleep.toStringAsFixed(1)} saat',
        0.94,
        AppColors.accent,
      ),
    ];
    return _sectionCard(
      context: context,
      title: 'Sağlık Hedefleri',
      trailing: GestureDetector(
        onTap: _showHealthGoalsSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Düzenle',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      child: Column(
        children: goals
            .map(
              (g) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            g.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                            ),
                          ),
                          Text(
                            g.value,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: g.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: g.progress,
                          minHeight: 6,
                          backgroundColor: cs.outlineVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(g.color),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildAbout(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = [
      ('Yardım ve Destek', _showHelpDialog),
      ('Kullanım Koşulları', _showTermsDialog),
      ('Gizlilik Politikası', _showPrivacyPolicyDialog),
    ];
    return _sectionCard(
      context: context,
      title: 'Hakkında',
      child: Column(
        children: [
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
                        Icon(
                          Icons.chevron_right,
                          color: cs.onSurfaceVariant,
                          size: 20,
                        ),
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
              'Versiyon 1.0.0',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
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

  Widget _sectionCard({
    required BuildContext context,
    required String title,
    required Widget child,
    Widget? trailing,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── Profil Düzenleme BottomSheet ─────────────────────────────────────────────
class _EditProfileSheet extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController bioCtrl;
  final Future<void> Function(String name, String bio) onSave;

  const _EditProfileSheet({
    required this.nameCtrl,
    required this.bioCtrl,
    required this.onSave,
  });

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
          TextField(
            controller: bioCtrl,
            maxLines: 3,
            maxLength: 200,
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
                await onSave(nameCtrl.text.trim(), bioCtrl.text.trim());
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

class _InfoItem {
  final IconData icon;
  final String label, value;
  final VoidCallback? onTap;
  const _InfoItem(this.icon, this.label, this.value, this.onTap);
}

class _Goal {
  final String label, value;
  final double progress;
  final Color color;
  const _Goal(this.label, this.value, this.progress, this.color);
}
