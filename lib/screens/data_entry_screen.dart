import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
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
  double _weight = 75;

  bool _saving = false;
  bool _saved = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final entry = await HealthService.getTodayEntry();
    final profile = await UserProfileService.getProfile();
    
    if (mounted) {
      setState(() {
        if (entry != null) {
          if (entry.systolic > 0) _systolic = entry.systolic;
          if (entry.diastolic > 0) _diastolic = entry.diastolic;
          // Eğer bugün zaten bir kilo girilmişse onu kullan
          if (entry.weight > 0) _weight = entry.weight;
        }
        
        // Eğer bugün henüz veri girilmemişse veya kilo 0 ise profildeki kiloyu al
        if (_weight <= 0 && profile != null) {
          _weight = profile.weight;
        }
      });
    }
  }

  Future<void> _handleSave() async {
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final profile = await UserProfileService.getProfile();
      
      // Firestore'a kaydet (M1)
      final entry = HealthEntry(
        date: DateTime.now(),
        weight: _weight,
        systolic: _systolic,
        diastolic: _diastolic,
        source: 'manual',
      );
      await HealthService.saveHealthEntry(entry);

      // Ayrıca kullanıcı profilindeki kiloyu da güncelle (Kalıcılık için)
      if (profile != null) {
        final updatedProfile = UserProfile(
          uid: profile.uid,
          fullName: profile.fullName,
          email: profile.email,
          age: profile.age,
          height: profile.height,
          weight: _weight, // Yeni kilo
          gender: profile.gender,
          photoUrl: profile.photoUrl,
          bio: profile.bio,
        );
        await UserProfileService.saveProfile(updatedProfile);
      }

      // FastAPI'den risk skoru al (M3)
      await ApiService.fetchRiskScore(
        RiskApiRequest(
          age: profile?.age ?? 30,
          gender: profile?.gender ?? 'M',
          height: profile?.height ?? 170,
          weight: _weight,
          systolic: _systolic,
          diastolic: _diastolic,
          heartRateResting: entry.heartRate,
          heartRateAvg: entry.heartRate, // Manuel girişte mevcut nabzı koru
        ),
      );

      if (mounted) {
        setState(() {
          _saving = false;
          _saved = true;
        });
        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) context.go('/app/dashboard');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = 'Hata: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Manuel Kayıt'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/app/dashboard'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildBPCard(context),
            const SizedBox(height: 16),
            _buildWeightCard(context),
            const SizedBox(height: 32),
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBPCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite_rounded, color: AppColors.primary),
                const SizedBox(width: 12),
                Text('Tansiyon', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildBPInput('Sistolik', _systolic, 80, 180, (v) => setState(() => _systolic = v))),
                const SizedBox(width: 16),
                Expanded(child: _buildBPInput('Diastolik', _diastolic, 40, 120, (v) => setState(() => _diastolic = v))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBPInput(String label, double val, double min, double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(val.toInt().toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Slider(value: val, min: min, max: max, onChanged: onChanged, activeColor: AppColors.primary),
      ],
    );
  }

  Widget _buildWeightCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.monitor_weight_rounded, color: AppColors.accent),
                const SizedBox(width: 12),
                Text('Vücut Ağırlığı', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            Slider(
              value: _weight,
              min: 40,
              max: 150,
              onChanged: (v) => setState(() => _weight = v),
              activeColor: AppColors.accent,
            ),
            Text('${_weight.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: (_saving || _saved) ? null : _handleSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: _saved ? AppColors.secondary : AppColors.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _saving
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(
                _saved ? 'Kaydedildi' : 'Bilgileri Kaydet',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
