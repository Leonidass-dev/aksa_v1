import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/theme_aware_state.dart';
import 'diet_plan_screen.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen>
    with ThemeAwareMixin {
  final _picker = ImagePicker();

  // Analiz sonuçları listesi (öğün bazlı)
  final List<_MealEntry> _meals = [];
  bool _analyzing = false;

  int _calorieGoal = 2000;

  @override
  void initState() {
    super.initState();
    _loadProfileAndHistory();
  }

  Future<void> _loadProfileAndHistory() async {
    // Kalori hedefini profilden hesapla (Mifflin-St Jeor)
    final profile = await UserProfileService.getProfile();
    if (profile != null) {
      double bmr;
      if (profile.gender == 'M') {
        bmr = 10 * profile.weight + 6.25 * profile.height - 5 * profile.age + 5;
      } else {
        bmr =
            10 * profile.weight + 6.25 * profile.height - 5 * profile.age - 161;
      }
      // Hafif aktivite çarpanı (1.375)
      if (mounted) setState(() => _calorieGoal = (bmr * 1.375).round());
    }

    // Geçmiş öğünleri backend'den yükle
    final history = await ApiService.fetchMealHistory(limit: 10);
    if (mounted && history.isNotEmpty) {
      setState(() {
        _meals.addAll(history.map((h) => _MealEntry(
              image: null, // Geriye dönük fotoğrafları DB'de saklamıyoruz
              result: FoodAnalysisResult(
                foodName: h.foodName,
                portion: h.portion ?? '-',
                calories: h.calories,
                proteinG: h.proteinG,
                carbsG: h.carbsG,
                fatG: h.fatG,
                fiberG: h.fiberG,
                healthScore: h.healthScore,
                recommendation: h.recommendation ?? '',
                tags: List<String>.from(h.tags ?? []),
              ),
              dateTime: DateTime.parse(h.analyzedAt).toLocal(),
            )));
      });
    }
  }


  int get _totalCalories {
    final now = DateTime.now();
    return _meals.where((m) {
      return m.dateTime.year == now.year &&
          m.dateTime.month == now.month &&
          m.dateTime.day == now.day;
    }).fold(0, (s, m) => s + m.calories);
  }

  Future<void> _pickAndAnalyze(ImageSource source) async {
    // API hızlandırması için resim boyutu ciddi şekilde sıkıştırıldı
    final xfile = await _picker.pickImage(
      source: source,
      imageQuality: 50,
      maxWidth: 500,
      maxHeight: 500,
    );
    if (xfile == null) return;

    setState(() {
      _analyzing = true;
    });

    final bytes = await xfile.readAsBytes();
    final result = await ApiService.analyzeFoodImage(bytes);

    if (result != null && mounted) {
      setState(() {
        _meals.insert(
          0,
          _MealEntry(
            image: File(xfile.path),
            result: result,
            dateTime: DateTime.now(),
          ),
        );
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yemek analiz edilemedi. Tekrar deneyin.'),
          backgroundColor: AppColors.destructive,
        ),
      );
    }

    if (mounted) setState(() => _analyzing = false);
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Yemek Fotoğrafı Ekle',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gemini AI ile besin değerlerini analiz et',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _SourceButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Kamera',
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndAnalyze(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Galeri',
                    color: AppColors.secondary,
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndAnalyze(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: "diet_plan",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DietPlanScreen()),
              );
            },
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
            label: const Text(
              'Bugün Ne Yemeliyim?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: "add_meal",
            onPressed: _analyzing ? null : _showImageSourceSheet,
            backgroundColor: AppColors.secondary,
            icon: _analyzing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.add_a_photo_outlined, color: Colors.white),
            label: Text(
              _analyzing ? 'Analiz ediliyor...' : 'Öğün Ekle',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildCalorieSummary(context),
                  const SizedBox(height: 20),
                  if (_meals.isEmpty) _buildEmptyState(context),
                  ..._meals.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildMealCard(context, m),
                    ),
                  ),
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
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            children: [
              Row(
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Beslenme Analizi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Yapay Zeka ile besin analizi',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Kalori progress
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.local_fire_department,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Günlük Hedef',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '$_calorieGoal kal',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Alınan',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '$_totalCalories',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (_totalCalories / _calorieGoal).clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_calorieGoal - _totalCalories).abs()} kalori ${_totalCalories > _calorieGoal ? "aşıldı" : "kaldı"}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalorieSummary(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final todayMeals = _meals.where((m) =>
        m.dateTime.year == now.year &&
        m.dateTime.month == now.month &&
        m.dateTime.day == now.day);

    final totalProtein = todayMeals.fold(0.0, (s, m) => s + m.result.proteinG);
    final totalCarbs = todayMeals.fold(0.0, (s, m) => s + m.result.carbsG);
    final totalFat = todayMeals.fold(0.0, (s, m) => s + m.result.fatG);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bugünkü Makrolar',
            style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MacroChip('Protein', totalProtein, 'g', AppColors.secondary),
              const SizedBox(width: 8),
              _MacroChip('Karb', totalCarbs, 'g', AppColors.primary),
              const SizedBox(width: 8),
              _MacroChip('Yağ', totalFat, 'g', AppColors.accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_a_photo_outlined,
              color: AppColors.secondary,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz öğün eklenmedi',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aşağıdaki butona basarak yemek fotoğrafı çek\nGemini AI besin değerlerini analiz etsin',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(BuildContext context, _MealEntry meal) {
    final cs = Theme.of(context).colorScheme;
    final r = meal.result;
    final scoreColor = r.healthScore >= 70
        ? AppColors.secondary
        : r.healthScore >= 40
        ? AppColors.accent
        : AppColors.destructive;

    return Container(
      decoration: _cardDecoration(context),
      child: Column(
        children: [
          // Fotoğraf + başlık
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Stack(
              children: [
                meal.image != null
                    ? Image.file(
                        meal.image!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        // RAM Şişmesini Önleme: Büyük fotoğrafları küçük önbellekleyerek (Downsampling) yükle
                        cacheHeight: 360, 
                      )
                    : Container(
                        height: 180,
                        width: double.infinity,
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        child: const Icon(
                          Icons.fastfood_outlined,
                          size: 64,
                          color: AppColors.secondary,
                        ),
                      ),
                // Sağlık skoru badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scoreColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${r.healthScore}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Kalori badge
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${r.calories} kal',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        r.foodName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      '${meal.dateTime.hour.toString().padLeft(2, '0')}:${meal.dateTime.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  r.portion,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                // Makro satırı
                Row(
                  children: [
                    _MacroChip('P', r.proteinG, 'g', AppColors.secondary),
                    const SizedBox(width: 6),
                    _MacroChip('K', r.carbsG, 'g', AppColors.primary),
                    const SizedBox(width: 6),
                    _MacroChip('Y', r.fatG, 'g', AppColors.accent),
                    const SizedBox(width: 6),
                    _MacroChip('Lif', r.fiberG, 'g', AppColors.chart4),
                  ],
                ),
                if (r.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: r.tags
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (r.recommendation.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.psychology_outlined,
                          color: AppColors.secondary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            r.recommendation,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BoxDecoration(
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
    );
  }
}

// ── Yardımcı widget'lar ───────────────────────────────────────────

class _MacroChip extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color color;
  const _MacroChip(this.label, this.value, this.unit, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '${value.toStringAsFixed(0)}$unit',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SourceButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealEntry {
  final File? image;
  final FoodAnalysisResult result;
  final DateTime dateTime;
  const _MealEntry({
    this.image,
    required this.result,
    required this.dateTime,
  });

  int get calories => result.calories;
}
