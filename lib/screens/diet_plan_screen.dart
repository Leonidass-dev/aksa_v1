import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';
class DietPlanScreen extends StatefulWidget {
  const DietPlanScreen({super.key});

  @override
  State<DietPlanScreen> createState() => _DietPlanScreenState();
}

class _DietPlanScreenState extends State<DietPlanScreen> {
  bool _loading = true;
  DietPlanResult? _plan;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPlan();
  }

  Future<void> _fetchPlan() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiService.getDietPlan();
      if (res != null) {
        setState(() => _plan = res);
      } else {
        setState(() => _error = "Diyet planı alınamadı veya zaman aşımına uğradı.");
      }
    } catch (e) {
      setState(() => _error = "Hata oluştu: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Günlük Diyetisyen'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Yapay zeka profilinize uygun öğünleri hazırlıyor..."),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.destructive),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchPlan,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (_plan == null) {
      return const Center(child: Text("Veri yok."));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 4),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: AppColors.mutedForeground),
              const SizedBox(width: 8),
              Text(
                "${DateFormat('d MMMM yyyy').format(DateTime.now())} - Günlük Planınız",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        // Kalori ve Advice
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Hedef: ${_plan!.dailyCaloriesTarget} kcal',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _plan!.aiAdvice,
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "Önerilen Öğünler",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ..._plan!.meals.map((m) => _buildMealCard(m)),
      ],
    );
  }

  Widget _buildMealCard(DietMealItem meal) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  meal.mealType,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${meal.calories} kcal',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              meal.foodName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              meal.portion,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    meal.reasoning,
                    style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
