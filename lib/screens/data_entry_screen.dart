import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  double _heartRate = 70;
  double _sleepHours = 7.0;
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
          if (entry.weight > 0) _weight = entry.weight;
          if (entry.heartRate > 0) _heartRate = entry.heartRate;
          if (entry.sleepHours > 0) _sleepHours = entry.sleepHours;
        } else {
          // Eğer giriş yoksa varsayılanları koru
          _systolic = 120;
          _diastolic = 80;
          _heartRate = 70;
          _sleepHours = 7.0;
        }
        
        // Eğer bugün henüz veri girilmemişse veya kilo 0 ise profildeki kiloyu al
        if (_weight <= 0 && profile != null) {
          _weight = profile.weight;
        }
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadInitialData();
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
      final existingEntry = await HealthService.getEntryByDate(_selectedDate);
      final entry = (existingEntry ?? HealthEntry(date: _selectedDate)).copyWith(
        weight: _weight,
        systolic: _systolic,
        diastolic: _diastolic,
        heartRate: _heartRate,
        sleepHours: _sleepHours,
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
          heartRateResting: _heartRate,
          heartRateAvg: _heartRate, // Manuel girişte mevcut nabzı kullan
        ),
      );

      if (mounted) {
        setState(() {
          _saving = false;
          _saved = true;
        });
        // Başarı overlay göster
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) => Transform.scale(
              scale: value,
              child: child,
            ),
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: AppColors.secondary, size: 56),
                  ),
                  const SizedBox(height: 16),
                  const Text('Başarıyla Kaydedildi!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'Sağlık verileriniz güncellendi.',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) {
          Navigator.of(context).pop(); // Dialog kapat
          context.go('/app/dashboard');
        }
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
            _buildDatePickerCard(context),
            const SizedBox(height: 16),
            _buildBPCard(context),
            const SizedBox(height: 16),
            _buildWeightCard(context),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildHeartRateCard(context)),
                const SizedBox(width: 16),
                Expanded(child: _buildSleepCard(context)),
              ],
            ),
            const SizedBox(height: 32),
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isToday = _selectedDate.year == DateTime.now().year &&
                    _selectedDate.month == DateTime.now().month &&
                    _selectedDate.day == DateTime.now().day;
    final dateStr = isToday ? 'Bugün' : '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';
    
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(20),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cs.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tarih Seçimi', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              const Icon(Icons.edit_calendar, color: AppColors.primary, size: 20),
            ],
          ),
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
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _stepperButton(
              icon: Icons.remove,
              onTap: val > min ? () {
                HapticFeedback.selectionClick();
                onChanged((val - 1).clamp(min, max));
              } : null,
            ),
            const SizedBox(width: 12),
            Text(val.toInt().toString(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            _stepperButton(
              icon: Icons.add,
              onTap: val < max ? () {
                HapticFeedback.selectionClick();
                onChanged((val + 1).clamp(min, max));
              } : null,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Slider(value: val, min: min, max: max, onChanged: onChanged, activeColor: AppColors.primary),
      ],
    );
  }

  Widget _stepperButton({required IconData icon, VoidCallback? onTap}) {
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.grey.withValues(alpha: 0.1)
              : AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDisabled
                ? Colors.grey.withValues(alpha: 0.2)
                : AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Icon(
          icon,
          color: isDisabled ? Colors.grey : AppColors.primary,
          size: 20,
        ),
      ),
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
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _stepperButton(
                  icon: Icons.remove,
                  onTap: _weight > 40 ? () {
                    HapticFeedback.selectionClick();
                    setState(() => _weight = (_weight - 0.1).clamp(40.0, 150.0));
                  } : null,
                ),
                const SizedBox(width: 16),
                Text('${_weight.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                _stepperButton(
                  icon: Icons.add,
                  onTap: _weight < 150 ? () {
                    HapticFeedback.selectionClick();
                    setState(() => _weight = (_weight + 0.1).clamp(40.0, 150.0));
                  } : null,
                ),
              ],
            ),
            Slider(
              value: _weight,
              min: 40,
              max: 150,
              onChanged: (v) => setState(() => _weight = v),
              activeColor: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeartRateCard(BuildContext context) {
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
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.monitor_heart, color: AppColors.destructive, size: 20),
                SizedBox(width: 8),
                Text('Nabız (bpm)', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Text(_heartRate.toInt().toString(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            Slider(
              value: _heartRate,
              min: 40, max: 200,
              activeColor: AppColors.destructive,
              onChanged: (v) => setState(() => _heartRate = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepCard(BuildContext context) {
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
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bedtime, color: AppColors.sleepPurple, size: 20),
                SizedBox(width: 8),
                Text('Uyku (saat)', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Text(_sleepHours.toStringAsFixed(1), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            Slider(
              value: _sleepHours,
              min: 0, max: 24,
              divisions: 48,
              activeColor: AppColors.sleepPurple,
              onChanged: (v) => setState(() => _sleepHours = v),
            ),
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
