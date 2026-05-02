/// API Request / Response modelleri.
library;
///
/// Bu dosya FastAPI backend ile iletişimde kullanılan tüm veri sınıflarını
/// içerir. Servis katmanından (api_service.dart) ayrılarak bağımsız
/// import edilebilir hale getirilmiştir.

// ═══════════════════════════════════════════════════════════════
// Risk Skoru
// ═══════════════════════════════════════════════════════════════

class RiskApiRequest {
  final double steps;
  final double sleepHours;
  final double heartRateResting;
  final double heartRateAvg; // Yeni alan
  final double systolic;
  final double diastolic;
  final double spo2;
  final double stressLevel;
  final double weight;
  final int age;
  final String gender;
  final double height;

  const RiskApiRequest({
    this.steps = 0,
    this.sleepHours = 0,
    this.heartRateResting = 0,
    this.heartRateAvg = 0, // Varsayılan değer
    this.systolic = 0,
    this.diastolic = 0,
    this.spo2 = 0,
    this.stressLevel = 0,
    this.weight = 0,
    this.age = 30,
    this.gender = 'M',
    this.height = 170,
    this.consumedCalories = 0,
    this.nutritionScore = 70,
  });

  final double consumedCalories;
  final double nutritionScore;

  Map<String, dynamic> toJson() => {
    'steps': steps,
    'sleep_hours': sleepHours,
    'heart_rate_resting': heartRateResting,
    'heart_rate_avg': heartRateAvg, // Backend beklentisiyle eşle
    'systolic': systolic,
    'diastolic': diastolic,
    'spo2': spo2,
    'stress_level': stressLevel,
    'weight': weight,
    'age': age,
    'gender': gender,
    'height': height,
    'consumed_calories': consumedCalories,
    'nutrition_score': nutritionScore,
  };
}

class RiskApiResult {
  final double score;
  final String level;
  final String levelLabel;
  final List<RiskApiFactorItem> topFactors;
  final List<String> recommendations;
  final String modelVersion;

  const RiskApiResult({
    required this.score,
    required this.level,
    required this.levelLabel,
    required this.topFactors,
    required this.recommendations,
    required this.modelVersion,
  });

  factory RiskApiResult.fromJson(Map<String, dynamic> json) => RiskApiResult(
    score: double.tryParse(json['score']?.toString() ?? '0') ?? 0.0,
    level: json['level'] as String? ?? 'low',
    levelLabel: json['level_label'] as String? ?? '',
    topFactors: (json['top_factors'] as List)
        .map((e) => RiskApiFactorItem.fromJson(e))
        .toList(),
    recommendations: List<String>.from(json['recommendations'] ?? []),
    modelVersion: json['model_version'] ?? '',
  );
}

class RiskApiFactorItem {
  final String name;
  final double contribution;
  final String description;

  const RiskApiFactorItem({
    required this.name,
    required this.contribution,
    required this.description,
  });

  factory RiskApiFactorItem.fromJson(Map<String, dynamic> json) =>
      RiskApiFactorItem(
        name: json['name'] as String? ?? '',
        contribution: double.tryParse(json['contribution']?.toString() ?? '0') ?? 0.0,
        description: json['description'] as String? ?? '',
      );
}

// ═══════════════════════════════════════════════════════════════
// Beslenme Analizi
// ═══════════════════════════════════════════════════════════════

class FoodAnalysisResult {
  final String foodName;
  final String portion;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final int healthScore;
  final String recommendation;
  final List<String> tags;

  const FoodAnalysisResult({
    required this.foodName,
    required this.portion,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.healthScore,
    required this.recommendation,
    required this.tags,
  });

  factory FoodAnalysisResult.fromJson(Map<String, dynamic> json) {
    final n = json['nutrients'] as Map<String, dynamic>? ?? {};
    return FoodAnalysisResult(
      foodName: json['food_name'] ?? 'Bilinmiyor',
      portion: json['portion'] ?? '-',
      calories: int.tryParse(n['calories']?.toString() ?? '0') ?? 0,
      proteinG: double.tryParse(n['protein_g']?.toString() ?? '0') ?? 0.0,
      carbsG: double.tryParse(n['carbs_g']?.toString() ?? '0') ?? 0.0,
      fatG: double.tryParse(n['fat_g']?.toString() ?? '0') ?? 0.0,
      fiberG: double.tryParse(n['fiber_g']?.toString() ?? '0') ?? 0.0,
      healthScore: int.tryParse(json['health_score']?.toString() ?? '50') ?? 50,
      recommendation: json['recommendation'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
    );
  }
}

class DietMealItem {
  final String mealType;
  final String foodName;
  final String portion;
  final int calories;
  final String reasoning;

  const DietMealItem({
    required this.mealType,
    required this.foodName,
    required this.portion,
    required this.calories,
    required this.reasoning,
  });

  factory DietMealItem.fromJson(Map<String, dynamic> json) => DietMealItem(
        mealType: json['meal_type'] as String? ?? '',
        foodName: json['food_name'] as String? ?? '',
        portion: json['portion'] as String? ?? '',
        calories: json['calories'] as int? ?? 0,
        reasoning: json['reasoning'] as String? ?? '',
      );
}

class DietPlanResult {
  final int dailyCaloriesTarget;
  final List<DietMealItem> meals;
  final String aiAdvice;

  const DietPlanResult({
    required this.dailyCaloriesTarget,
    required this.meals,
    required this.aiAdvice,
  });

  factory DietPlanResult.fromJson(Map<String, dynamic> json) => DietPlanResult(
        dailyCaloriesTarget: json['daily_calories_target'] as int? ?? 0,
        meals: (json['meals'] as List<dynamic>?)
                ?.map((e) => DietMealItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        aiAdvice: json['ai_advice'] as String? ?? '',
      );
}

// ═══════════════════════════════════════════════════════════════
// Anomali Tespiti
// ═══════════════════════════════════════════════════════════════

class AnomalyApiItem {
  final String metric;
  final String metricLabel;
  final double zScore;
  final double todayValue;
  final double avgValue;
  final String unit;
  final String severity; // "low" | "medium" | "high"
  final String description;
  final String recommendation;

  const AnomalyApiItem({
    required this.metric,
    required this.metricLabel,
    required this.zScore,
    required this.todayValue,
    required this.avgValue,
    required this.unit,
    required this.severity,
    required this.description,
    required this.recommendation,
  });

  factory AnomalyApiItem.fromJson(Map<String, dynamic> json) => AnomalyApiItem(
    metric: json['metric'] ?? '',
    metricLabel: json['metric_label'] ?? '',
    zScore: double.tryParse(json['z_score']?.toString() ?? '0') ?? 0.0,
    todayValue: double.tryParse(json['today_value']?.toString() ?? '0') ?? 0.0,
    avgValue: double.tryParse(json['avg_value']?.toString() ?? '0') ?? 0.0,
    unit: json['unit'] ?? '',
    severity: json['severity'] ?? 'low',
    description: json['description'] ?? '',
    recommendation: json['recommendation'] ?? '',
  );
}

class AnomalyApiResult {
  final bool hasAnomaly;
  final List<AnomalyApiItem> anomalies;
  final int checkedMetrics;
  final String modelVersion;

  const AnomalyApiResult({
    required this.hasAnomaly,
    required this.anomalies,
    required this.checkedMetrics,
    required this.modelVersion,
  });

  factory AnomalyApiResult.fromJson(Map<String, dynamic> json) =>
      AnomalyApiResult(
        hasAnomaly: json['has_anomaly'] as bool? ?? false,
        anomalies: (json['anomalies'] as List? ?? [])
            .map((e) => AnomalyApiItem.fromJson(e))
            .toList(),
        checkedMetrics: (json['checked_metrics'] ?? 0) as int,
        modelVersion: json['model_version'] ?? '',
      );
}

// ═══════════════════════════════════════════════════════════════
// Egzersiz Planı
// ═══════════════════════════════════════════════════════════════

class ExerciseApiRequest {
  final int age;
  final double weight;
  final double height;
  final String gender;
  final String riskLevel;
  final double? systolicBp;
  final double? diastolicBp;
  final double? heartRate;
  final bool forceRefresh;

  const ExerciseApiRequest({
    required this.age,
    required this.weight,
    required this.height,
    required this.gender,
    required this.riskLevel,
    this.systolicBp,
    this.diastolicBp,
    this.heartRate,
    this.forceRefresh = false,
  });

  Map<String, dynamic> toJson() => {
    'age': age,
    'weight': weight,
    'height': height,
    'gender': gender,
    'risk_level': riskLevel,
    'force_refresh': forceRefresh,
    if (systolicBp != null) 'systolic_bp': systolicBp,
    if (diastolicBp != null) 'diastolic_bp': diastolicBp,
    if (heartRate != null) 'heart_rate': heartRate,
  };
}

class ExerciseApiItem {
  final String title;
  final int durationMinutes;
  final String intensity;
  final int calories;
  final String type;
  final String description;

  const ExerciseApiItem({
    required this.title,
    required this.durationMinutes,
    required this.intensity,
    required this.calories,
    required this.type,
    required this.description,
  });

  factory ExerciseApiItem.fromJson(Map<String, dynamic> json) =>
      ExerciseApiItem(
        title: json['title'] ?? 'Egzersiz',
        durationMinutes: int.tryParse(json['duration_minutes']?.toString() ?? '0') ?? 0,
        intensity: json['intensity'] ?? 'Düşük',
        calories: int.tryParse(json['calories']?.toString() ?? '0') ?? 0,
        type: json['type'] ?? 'Genel',
        description: json['description'] ?? '',
      );
}

class ExerciseApiResult {
  final List<ExerciseApiItem> exercises;
  final int totalDurationMinutes;
  final int totalCalories;
  final String aiAdvice;

  const ExerciseApiResult({
    required this.exercises,
    required this.totalDurationMinutes,
    required this.totalCalories,
    required this.aiAdvice,
  });

  factory ExerciseApiResult.fromJson(Map<String, dynamic> json) {
    return ExerciseApiResult(
      exercises: (json['exercises'] as List? ?? [])
          .map((e) => ExerciseApiItem.fromJson(e))
          .toList(),
      totalDurationMinutes: int.tryParse(json['total_duration_minutes']?.toString() ?? '0') ?? 0,
      totalCalories: int.tryParse(json['total_calories']?.toString() ?? '0') ?? 0,
      aiAdvice: json['ai_advice'] ?? '',
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AI Asistan
// ═══════════════════════════════════════════════════════════════

class AssistantChatResponse {
  final String reply;
  final bool isSafe;

  const AssistantChatResponse({required this.reply, this.isSafe = true});

  factory AssistantChatResponse.fromJson(Map<String, dynamic> json) {
    return AssistantChatResponse(
      reply: json['reply'] ?? 'Yanıt alınamadı.',
      isSafe: json['is_safe'] ?? true,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Geçmiş Kayıtlar
// ═══════════════════════════════════════════════════════════════

class RiskHistoryItem {
  final int id;
  final double score;
  final String level;
  final String? levelLabel;
  final String calculatedAt;

  const RiskHistoryItem({
    required this.id,
    required this.score,
    required this.level,
    this.levelLabel,
    required this.calculatedAt,
  });

  factory RiskHistoryItem.fromJson(Map<String, dynamic> json) =>
      RiskHistoryItem(
        id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
        score: double.tryParse(json['score']?.toString() ?? '0') ?? 0.0,
        level: json['level'] as String? ?? 'low',
        levelLabel: json['level_label'] as String?,
        calculatedAt: json['calculated_at'] as String,
      );
}

class MealHistoryItem {
  final int id;
  final String foodName;
  final String? portion;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final int healthScore;
  final String? recommendation;
  final List<String>? tags;
  final String analyzedAt;

  const MealHistoryItem({
    required this.id,
    required this.foodName,
    this.portion,
    required this.calories,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.fiberG = 0,
    required this.healthScore,
    this.recommendation,
    this.tags,
    required this.analyzedAt,
  });

  factory MealHistoryItem.fromJson(Map<String, dynamic> json) =>
      MealHistoryItem(
        id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
        foodName: json['food_name'] as String? ?? 'Bilinmiyor',
        portion: json['portion'] as String?,
        calories: int.tryParse(json['calories']?.toString() ?? '0') ?? 0,
        proteinG: double.tryParse(json['protein_g']?.toString() ?? '0') ?? 0.0,
        carbsG: double.tryParse(json['carbs_g']?.toString() ?? '0') ?? 0.0,
        fatG: double.tryParse(json['fat_g']?.toString() ?? '0') ?? 0.0,
        fiberG: double.tryParse(json['fiber_g']?.toString() ?? '0') ?? 0.0,
        healthScore: int.tryParse(json['health_score']?.toString() ?? '0') ?? 0,
        recommendation: json['recommendation'] as String?,
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList(),
        analyzedAt: json['analyzed_at'] as String,
      );
}

class ChatHistoryItem {
  final int id;
  final String role;
  final String content;
  final bool isSafe;
  final String createdAt;

  const ChatHistoryItem({
    required this.id,
    required this.role,
    required this.content,
    required this.isSafe,
    required this.createdAt,
  });

  factory ChatHistoryItem.fromJson(Map<String, dynamic> json) =>
      ChatHistoryItem(
        id: json['id'] as int,
        role: json['role'] as String,
        content: json['content'] as String,
        isSafe: json['is_safe'] as bool? ?? true,
        createdAt: json['created_at'] as String,
      );
}
