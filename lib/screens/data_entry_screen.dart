import 'package:aksa_v1/utils/app_logger.dart';
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

  DateTime _selectedDate = DateTime.now();

  bool _saving = false;
  bool _saved = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final entry = await HealthService.getEntryByDate(_selectedDate);
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
    // Mantıksal Hata Çözümü: Tıbben imkansız tansiyon değerini engelle
    if (_diastolic >= _systolic) {
      setState(() {
        _errorMessage = 'Hata: Küçük tansiyon, Büyük tansiyondan büyük veya eşit olamaz.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final profile = await UserProfileService.getProfile();

      // Firestore'a kaydet (M1)
      // Mevcut Health Connect verilerini koruyarak sadece manuel alanları güncelle
      final existingEntry = await HealthService.getEntryByDate(_selectedDate);
      final entry = (existingEntry ?? HealthEntry(date: _selectedDate)).copyWith(
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

      // FastAPI'den risk skoru al (M3) — opsiyonel, başarısız olması save'i etkilememeli
      try {
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
      } catch (e) {
        AppLogger.debug('Risk skoru hesaplanamadı (veri kaydedildi): $e');
      }

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
            _buildDatePicker(context),
            const SizedBox(height: 16),
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

  Widget _buildDatePicker(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateText = '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';
    
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null && picked != _selectedDate) {
          setState(() {
            _selectedDate = picked;
            _saved = false;
            _errorMessage = null;
          });
          _loadInitialData();
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Kayıt Tarihi',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            Text(
              dateText,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
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
                Expanded(child: _buildBPInput('Sistolik', _systolic, 80, 250, (v) => setState(() => _systolic = v))),
                const SizedBox(width: 16),
                Expanded(child: _buildBPInput('Diastolik', _diastolic, 40, 150, (v) => setState(() => _diastolic = v))),
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
              max: 250,
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