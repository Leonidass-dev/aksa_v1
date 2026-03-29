import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'health_service.dart';

/// FastAPI backend'e HTTP istekleri gönderen servis.
/// Tüm istekler Firebase token ile korunur.
class ApiService {
  // Production build: flutter build apk --dart-define=API_BASE_URL=https://your-production-url.com/api
  // Dev build: varsayılan olarak localhost kullanır
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api', // Android emülatör localhost
  );

  // ── Firebase Token Helper ─────────────────────────────────────
  static Future<Map<String, String>> _authHeaders() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Yemek Fotoğrafı Analizi ──────────────────────────────────
  static Future<FoodAnalysisResult?> analyzeFoodImage(
      List<int> imageBytes) async {
    try {
      final base64Image = base64Encode(imageBytes);
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/analyze-food'),
            headers: headers,
            body: jsonEncode({'image_base64': base64Image}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return FoodAnalysisResult.fromJson(jsonDecode(response.body));
      }
    } catch (_) {}
    return null;
  }

  // ── Anomali Tespiti ────────────────────────────────────────────
  static Future<AnomalyApiResult?> checkAnomalies({
    required Map<String, dynamic> history,
    required Map<String, dynamic> today,
  }) async {
    try {
      final headers = await _authHeaders();
      final res = await http.post(
        Uri.parse('$_baseUrl/anomaly-check'),
        headers: headers,
        body: jsonEncode({'history': history, 'today': today}),
      );
      if (res.statusCode == 200) {
        return AnomalyApiResult.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
      }
    } catch (e) {
      debugPrint('Anomaly API hatası: $e');
    }
    return null;
  }

  // ── Egzersiz Planı Önerisi ─────────────────────────────────────
  static Future<ExerciseApiResult?> fetchExercisePlan(ExerciseApiRequest req) async {
    try {
      final headers = await _authHeaders();
      final res = await http.post(
        Uri.parse('$_baseUrl/exercise-plan'),
        headers: headers,
        body: jsonEncode(req.toJson()),
      );
      if (res.statusCode == 200) {
        return ExerciseApiResult.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
      }
    } catch (e) {
      debugPrint('Exercise API hatası: $e');
    }
    return null;
  }

  // ── Risk Skoru ────────────────────────────────────────────────
  static Future<RiskApiResult?> fetchRiskScore(RiskApiRequest req) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/risk-score'),
            headers: headers,
            body: jsonEncode(req.toJson()),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return RiskApiResult.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      // Backend erişilemiyorsa null dön → ekranlar demo veriyi kullanır
    }
    return null;
  }

  /// Bağlantı testi — demo endpoint'i çağırır.
  static Future<RiskApiResult?> fetchDemoRiskScore() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/risk-score/demo'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return RiskApiResult.fromJson(jsonDecode(response.body));
      }
    } catch (_) {}
    return null;
  }

  // ── Risk Geçmişi ──────────────────────────────────────────────
  static Future<List<RiskHistoryItem>> fetchRiskHistory({int limit = 30}) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(
            Uri.parse('$_baseUrl/risk-history?limit=$limit'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final list = jsonDecode(utf8.decode(response.bodyBytes)) as List;
        return list.map((e) => RiskHistoryItem.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Risk history hatası: $e');
    }
    return [];
  }

  // ── Yemek Geçmişi ────────────────────────────────────────────
  static Future<List<MealHistoryItem>> fetchMealHistory({int limit = 30}) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(
            Uri.parse('$_baseUrl/meal-history?limit=$limit'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final list = jsonDecode(utf8.decode(response.bodyBytes)) as List;
        return list.map((e) => MealHistoryItem.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Meal history hatası: $e');
    }
    return [];
  }

  // ── AI Asistan Chat ────────────────────────────────────────────
  static Future<AssistantChatResponse?> sendAssistantMessage(String message) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/assistant/chat'),
            headers: headers,
            body: jsonEncode({'message': message}),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        return AssistantChatResponse.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      }
    } catch (e) {
      debugPrint('Assistant API hatası: $e');
    }
    return null;
  }

  // ── Chat Geçmişi ──────────────────────────────────────────────
  static Future<List<ChatHistoryItem>> fetchChatHistory({int limit = 50}) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(
            Uri.parse('$_baseUrl/assistant/history?limit=$limit'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final list = jsonDecode(utf8.decode(response.bodyBytes)) as List;
        return list.map((e) => ChatHistoryItem.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Chat history hatası: $e');
    }
    return [];
  }

  // ── Sağlık Verisi Backend Sync ────────────────────────────────
  /// Firestore'daki sağlık verisini backend PostgreSQL'e de gönderir.
  static Future<bool> syncHealthToBackend(HealthEntry entry) async {
    try {
      final headers = await _authHeaders();
      final body = {
        'record_date': '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}',
        'steps': entry.steps,
        'heart_rate': entry.heartRate,
        'resting_heart_rate': entry.restingHeartRate,
        'spo2': entry.spo2,
        'systolic': entry.systolic,
        'diastolic': entry.diastolic,
        'sleep_hours': entry.sleepHours,
        'sleep_deep_min': entry.sleepDeepMin,
        'sleep_light_min': entry.sleepLightMin,
        'sleep_rem_min': entry.sleepRemMin,
        'sleep_awake_min': entry.sleepAwakeMin,
        'active_calories': entry.activeCalories,
        'total_calories': entry.totalCalories,
        'distance_m': entry.distanceM,
        'stress_level': entry.stressLevel,
        'weight': entry.weight,
        'source': entry.source,
      };

      final response = await http
          .post(
            Uri.parse('$_baseUrl/health'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Health sync hatası: $e');
      return false;
    }
  }
}

// ── Request / Response Modelleri ─────────────────────────────────

class RiskApiRequest {
  final double steps;
  final double sleepHours;
  final double heartRateResting;
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
    this.systolic = 0,
    this.diastolic = 0,
    this.spo2 = 0,
    this.stressLevel = 0,
    this.weight = 0,
    this.age = 30,
    this.gender = 'M',
    this.height = 170,
  });

  Map<String, dynamic> toJson() => {
        'steps': steps,
        'sleep_hours': sleepHours,
        'heart_rate_resting': heartRateResting,
        'systolic': systolic,
        'diastolic': diastolic,
        'spo2': spo2,
        'stress_level': stressLevel,
        'weight': weight,
        'age': age,
        'gender': gender,
        'height': height,
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
        score: (json['score'] as num).toDouble(),
        level: json['level'] as String,
        levelLabel: json['level_label'] as String,
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
        name: json['name'] as String,
        contribution: (json['contribution'] as num).toDouble(),
        description: json['description'] as String,
      );
}

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
      calories: (n['calories'] ?? 0) as int,
      proteinG: (n['protein_g'] ?? 0).toDouble(),
      carbsG: (n['carbs_g'] ?? 0).toDouble(),
      fatG: (n['fat_g'] ?? 0).toDouble(),
      fiberG: (n['fiber_g'] ?? 0).toDouble(),
      healthScore: (json['health_score'] ?? 50) as int,
      recommendation: json['recommendation'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
    );
  }
}

// ── Anomali Veri Modelleri ─────────────────────────────────────────────

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
        zScore: (json['z_score'] ?? 0).toDouble(),
        todayValue: (json['today_value'] ?? 0).toDouble(),
        avgValue: (json['avg_value'] ?? 0).toDouble(),
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

// ── Egzersiz Veri Modelleri ─────────────────────────────────────────────

class ExerciseApiRequest {
  final int age;
  final double weight;
  final double height;
  final String gender;
  final String riskLevel;
  final double? systolicBp;
  final double? diastolicBp;
  final double? heartRate;

  const ExerciseApiRequest({
    required this.age,
    required this.weight,
    required this.height,
    required this.gender,
    required this.riskLevel,
    this.systolicBp,
    this.diastolicBp,
    this.heartRate,
  });

  Map<String, dynamic> toJson() => {
    'age': age,
    'weight': weight,
    'height': height,
    'gender': gender,
    'risk_level': riskLevel,
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

  factory ExerciseApiItem.fromJson(Map<String, dynamic> json) => ExerciseApiItem(
    title: json['title'] ?? 'Egzersiz',
    durationMinutes: (json['duration_minutes'] ?? 0) as int,
    intensity: json['intensity'] ?? 'Düşük',
    calories: (json['calories'] ?? 0) as int,
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
      totalDurationMinutes: (json['total_duration_minutes'] ?? 0) as int,
      totalCalories: (json['total_calories'] ?? 0) as int,
      aiAdvice: json['ai_advice'] ?? '',
    );
  }
}

// ── Asistan Veri Modelleri ──────────────────────────────────────────────

class AssistantChatResponse {
  final String reply;
  final bool isSafe;

  const AssistantChatResponse({
    required this.reply,
    this.isSafe = true,
  });

  factory AssistantChatResponse.fromJson(Map<String, dynamic> json) {
    return AssistantChatResponse(
      reply: json['reply'] ?? 'Yanıt alınamadı.',
      isSafe: json['is_safe'] ?? true,
    );
  }
}

// ── Geçmiş Veri Modelleri (Yeni) ────────────────────────────────────────

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

  factory RiskHistoryItem.fromJson(Map<String, dynamic> json) => RiskHistoryItem(
    id: json['id'] as int,
    score: (json['score'] as num).toDouble(),
    level: json['level'] as String,
    levelLabel: json['level_label'] as String?,
    calculatedAt: json['calculated_at'] as String,
  );
}

class MealHistoryItem {
  final int id;
  final String foodName;
  final int calories;
  final int healthScore;
  final String analyzedAt;

  const MealHistoryItem({
    required this.id,
    required this.foodName,
    required this.calories,
    required this.healthScore,
    required this.analyzedAt,
  });

  factory MealHistoryItem.fromJson(Map<String, dynamic> json) => MealHistoryItem(
    id: json['id'] as int,
    foodName: json['food_name'] as String,
    calories: (json['calories'] ?? 0) as int,
    healthScore: (json['health_score'] ?? 0) as int,
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

  factory ChatHistoryItem.fromJson(Map<String, dynamic> json) => ChatHistoryItem(
    id: json['id'] as int,
    role: json['role'] as String,
    content: json['content'] as String,
    isSafe: json['is_safe'] as bool? ?? true,
    createdAt: json['created_at'] as String,
  );
}
