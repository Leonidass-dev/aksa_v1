import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../services/user_profile_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  int _step = 0; // 0: kişisel, 1: vücut

  // Seçimler
  String _gender = 'M';
  int _age = 25;
  double _height = 170;
  double _weight = 70;

  // Kontrolcüler
  final _ageCtrl = TextEditingController(text: '25');
  final _heightCtrl = TextEditingController(text: '170');
  final _weightCtrl = TextEditingController(text: '70');

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final user = FirebaseAuth.instance.currentUser!;
    final profile = UserProfile(
      uid: user.uid,
      fullName: user.displayName ?? '',
      email: user.email ?? '',
      age: _age,
      height: _height,
      weight: _weight,
      gender: _gender,
      photoUrl: user.photoURL,
    );

    await UserProfileService.saveProfile(profile);

    if (mounted) {
      setState(() => _loading = false);
      context.go('/app/dashboard');
    }
  }

  void _next() {
    if (_step == 0) {
      setState(() => _step = 1);
    } else {
      _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: _step == 0 ? _buildStep0(context) : _buildStep1(context),
                ),
              ),
            ),
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.monitor_heart_outlined, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text('AKSA',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _step == 0 ? 'Kişisel Bilgiler' : 'Vücut Ölçüleri',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _step == 0
                ? 'Adım 1/2 — Kimliğinizi tanımlayalım'
                : 'Adım 2/2 — Risk motoruna parametre girilecek',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
          ),
          const SizedBox(height: 14),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _step == 0 ? 0.5 : 1.0,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep0(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Cinsiyet', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
        const SizedBox(height: 12),
        Row(
          children: [
            _GenderButton(label: 'Erkek', value: 'M', icon: Icons.male,
                selected: _gender == 'M', onTap: () => setState(() => _gender = 'M')),
            const SizedBox(width: 12),
            _GenderButton(label: 'Kadın', value: 'F', icon: Icons.female,
                selected: _gender == 'F', onTap: () => setState(() => _gender = 'F')),
            const SizedBox(width: 12),
            _GenderButton(label: 'Diğer', value: 'O', icon: Icons.person_outline,
                selected: _gender == 'O', onTap: () => setState(() => _gender = 'O')),
          ],
        ),
        const SizedBox(height: 28),
        Text('Yaş', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _ageCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.cake_outlined, color: AppColors.primary),
            hintText: 'Yaşınızı girin',
            suffixText: 'yıl',
          ),
          validator: (v) {
            final n = int.tryParse(v ?? '');
            if (n == null || n < 10 || n > 120) return '10–120 arasında girin';
            return null;
          },
          onChanged: (v) => _age = int.tryParse(v) ?? _age,
        ),
      ],
    );
  }

  Widget _buildStep1(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Boy', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _heightCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.height, color: AppColors.primary),
            hintText: 'Boyunuzu girin',
            suffixText: 'cm',
          ),
          validator: (v) {
            final n = double.tryParse(v ?? '');
            if (n == null || n < 100 || n > 250) return '100–250 cm arası girin';
            return null;
          },
          onChanged: (v) => _height = double.tryParse(v) ?? _height,
        ),
        const SizedBox(height: 24),
        Text('Kilo', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _weightCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.monitor_weight_outlined, color: AppColors.primary),
            hintText: 'Kilonuzu girin',
            suffixText: 'kg',
          ),
          validator: (v) {
            final n = double.tryParse(v ?? '');
            if (n == null || n < 20 || n > 300) return '20–300 kg arası girin';
            return null;
          },
          onChanged: (v) => _weight = double.tryParse(v) ?? _weight,
        ),
        const SizedBox(height: 28),
        // BMI önizlemesi
        _buildBmiPreview(context),
      ],
    );
  }

  Widget _buildBmiPreview(BuildContext context) {
    final bmi = _weight / ((_height / 100) * (_height / 100));
    final cs = Theme.of(context).colorScheme;
    String category;
    Color color;
    if (bmi < 18.5) {
      category = 'Zayıf';
      color = AppColors.accent;
    } else if (bmi < 25) {
      category = 'Normal';
      color = AppColors.secondary;
    } else if (bmi < 30) {
      category = 'Fazla Kilolu';
      color = AppColors.accent;
    } else {
      category = 'Obez';
      color = AppColors.destructive;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(Icons.calculate_outlined, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tahmini VKİ (BMI)',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              Text('${bmi.toStringAsFixed(1)} — $category',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: () => setState(() => _step = 0),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Geri'),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _loading ? null : _next,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                backgroundColor: AppColors.primary,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      _step == 0 ? 'Devam Et →' : 'Kaydet & Başla 🚀',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderButton extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _GenderButton({
    required this.label, required this.value, required this.icon,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : Theme.of(context).colorScheme.outlineVariant;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: selected ? 2 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? AppColors.primary : Theme.of(context).colorScheme.onSurfaceVariant, size: 28),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? AppColors.primary : Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
