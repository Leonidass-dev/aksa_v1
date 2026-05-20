import 'package:aksa_v1/utils/app_logger.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/health_entry.dart';
import '../models/api_models.dart';

import 'interfaces/i_api_service.dart';

// Re-export so existing `import 'api_service.dart'` importers still see model classes.
export '../models/api_models.dart';

/// FastAPI backend'e HTTP istekleri gönderen servis.
/// Tüm istekler Firebase token ile korunur.
class ApiServiceImpl implements IApiService {
  final String _baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.42:8000/api',  // Lokal geliştirme (fiziksel cihaz)
  );

  // ── Firebase Token Helper ─────────────────────────────────────
  Future<Map<String, String>> _authHeaders() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Tez Modül 2: Sensör Verisi Önişleme (Pipeline) ────────────
  @override
  Future<bool> preprocessRawData({
    required List<Map<String, dynamic>> heartRateData,
    required List<Map<String, dynamic>> stepsData,
  }) async {
    try {
      final headers = await _authHeaders();
      final body = jsonEncode({
        'heart_rate_data': heartRateData,
        'steps_data': stepsData,
      });

      final response = await http
          .post(
            Uri.parse('$_baseUrl/preprocess-sensor-data'),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        AppLogger.debug("ML Pipeline (Preprocessing) başarıyla tamamlandı.");
        return true;
      }
    } catch (e) {
      AppLogger.error('ML Pipeline hatası: $e');
    }
    return false;
  }

  // ── Yemek Fotoğrafı Analizi ──────────────────────────────────
  @override
  Future<FoodAnalysisResult?> analyzeFoodImage(
    List<int> imageBytes,
  ) async {
    try {
      final base64Image = base64Encode(imageBytes);
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/analyze-food'),
            headers: headers,
            body: jsonEncode({'image_base64': base64Image}),
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        return FoodAnalysisResult.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      AppLogger.error('Food analysis hatası: $e');
    }
    return null;
  }

  @override
  Future<FoodAnalysisResult?> saveManualFood(String foodName, String portion) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/manual'),
            headers: headers,
            body: jsonEncode({
              'food_name': foodName,
              'portion': portion,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return FoodAnalysisResult.fromJson(data);
      }
    } catch (e) {
      AppLogger.error('Manual food save hatası: $e');
    }
    return null;
  }

  // ── M5: Diyet Planı Önerisi (Yapay Zeka Yeni Modül) ────────────
  @override
  Future<DietPlanResult?> getDietPlan() async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(
        Uri.parse('$_baseUrl/diet-plan'),
        headers: headers,
      ).timeout(const Duration(seconds: 60));
      
      if (res.statusCode == 200) {
        return DietPlanResult.fromJson(
          jsonDecode(utf8.decode(res.bodyBytes)),
        );
      }
    } catch (e) {
      AppLogger.error('Diet plan API hatası: $e');
    }
    return null;
  }

  // ── Anomali Tespiti ────────────────────────────────────────────
  @override
  Future<AnomalyApiResult?> checkAnomalies({
    required List<Map<String, dynamic>> history,  // Backend list[DailySnapshotRequest] bekliyor
    required Map<String, dynamic> today,
  }) async {
    try {
      final headers = await _authHeaders();
      final res = await http.post(
        Uri.parse('$_baseUrl/anomaly-check'),
        headers: headers,
        body: jsonEncode({'history': history, 'today': today}),
      ).timeout(const Duration(seconds: 60));
      if (res.statusCode == 200) {
        return AnomalyApiResult.fromJson(
          jsonDecode(utf8.decode(res.bodyBytes)),
        );
      }
    } catch (e) {
      AppLogger.error('Anomaly API hatası: $e');
    }
    return null;
  }

  // ── Egzersiz Planı Önerisi ─────────────────────────────────────
  @override
  Future<ExerciseApiResult?> fetchExercisePlan(
    ExerciseApiRequest req,
  ) async {
    try {
      final headers = await _authHeaders();
      final res = await http.post(
        Uri.parse('$_baseUrl/exercise-plan'),
        headers: headers,
        body: jsonEncode(req.toJson()),
      ).timeout(const Duration(seconds: 60));
      if (res.statusCode == 200) {
        return ExerciseApiResult.fromJson(
          jsonDecode(utf8.decode(res.bodyBytes)),
        );
      }
    } catch (e) {
      AppLogger.error('Exercise API hatası: $e');
    }
    return null;
  }

  // ── Egzersiz Geri Bildirimi (Tez M6 Feedback Loop) ─────────────
  @override
  Future<bool> sendExerciseFeedback(String feedback) async {
    try {
      final headers = await _authHeaders();
      final res = await http.post(
        Uri.parse('$_baseUrl/exercise-plan/feedback'),
        headers: headers,
        body: jsonEncode({'feedback': feedback}),
      ).timeout(const Duration(seconds: 60));
      if (res.statusCode == 200) {
        return true;
      }
    } catch (e) {
      AppLogger.error('Exercise Feedback API hatası: $e');
    }
    return false;
  }

  // ── Risk Skoru ────────────────────────────────────────────────
  @override
  Future<RiskApiResult?> fetchRiskScore(RiskApiRequest req) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/risk-score'),
            headers: headers,
            body: jsonEncode(req.toJson()),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return RiskApiResult.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      // Backend erişilemiyorsa null dön → ekranlar demo veriyi kullanır
    }
    return null;
  }

  /// Bağlantı testi — demo endpoint'i çağırır.
  @override
  Future<RiskApiResult?> fetchDemoRiskScore() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/risk-score/demo'))
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        return RiskApiResult.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      AppLogger.error('Demo risk API hatası: $e');
    }
    return null;
  }

  // ── Risk Geçmişi ──────────────────────────────────────────────
  @override
  Future<List<RiskHistoryItem>> fetchRiskHistory({
    int limit = 30,
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(
            Uri.parse('$_baseUrl/risk-history?limit=$limit'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final list = jsonDecode(utf8.decode(response.bodyBytes)) as List;
        return list.map((e) => RiskHistoryItem.fromJson(e)).toList();
      }
    } catch (e) {
      AppLogger.error('Risk history hatası: $e');
    }
    return [];
  }

  // ── Yemek Geçmişi ────────────────────────────────────────────
  @override
  Future<List<MealHistoryItem>> fetchMealHistory({
    int limit = 30,
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(
            Uri.parse('$_baseUrl/meal-history?limit=$limit'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final list = jsonDecode(utf8.decode(response.bodyBytes)) as List;
        return list.map((e) => MealHistoryItem.fromJson(e)).toList();
      }
    } catch (e) {
      AppLogger.error('Meal history hatası: $e');
    }
    return [];
  }

  // ── AI Asistan Chat ────────────────────────────────────────────
  @override
  Future<AssistantChatResponse?> sendAssistantMessage(
    String message,
  ) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/assistant/chat'),
            headers: headers,
            body: jsonEncode({'message': message}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return AssistantChatResponse.fromJson(
          jsonDecode(utf8.decode(response.bodyBytes)),
        );
      }
    } catch (e) {
      AppLogger.error('Assistant API hatası: $e');
    }
    return null;
  }

  // ── Anlık Ruh Hali (Mood) Tavsiyesi ────────────────────────────────────
  @override
  Future<MoodAdviceResponse?> fetchMoodAdvice(String mood) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/assistant/mood-advice'),
            headers: headers,
            body: jsonEncode({'mood': mood}),
          )
          .timeout(const Duration(seconds: 15)); // Hızlı cevap bekliyoruz

      if (response.statusCode == 200) {
        return MoodAdviceResponse.fromJson(
          jsonDecode(utf8.decode(response.bodyBytes)),
        );
      }
    } catch (e) {
      AppLogger.error('Mood Advice API hatası: $e');
    }
    return null;
  }

  // ── Chat Geçmişi ──────────────────────────────────────────────
  @override
  Future<List<ChatHistoryItem>> fetchChatHistory({
    int limit = 50,
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(
            Uri.parse('$_baseUrl/assistant/history?limit=$limit'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final list = jsonDecode(utf8.decode(response.bodyBytes)) as List;
        return list.map((e) => ChatHistoryItem.fromJson(e)).toList();
      }
    } catch (e) {
      AppLogger.error('Chat history hatası: $e');
    }
    return [];
  }

  // ── Chat Geçmişi Temizle ──────────────────────────────────────────────
  @override
  Future<bool> clearChatHistory() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/assistant/history'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error('Chat history clear hatası: $e');
      return false;
    }
  }

  // ── Sağlık Verisi Backend Sync ────────────────────────────────
  @override
  Future<bool> syncHealthToBackend(HealthEntry entry) async {
    try {
      final headers = await _authHeaders();
      final body = {
        'record_date':
            '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}',
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
        'water_ml': entry.waterMl,
        'mood': entry.mood,
        'source': entry.source,
      };

      final response = await http
          .post(
            Uri.parse('$_baseUrl/health'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error('Health sync hatası: $e');
      return false;
    }
  }

  // ── Kullanıcı Profili Senkronizasyonu ────────────────────────────
  @override
  Future<bool> syncProfileToBackend(dynamic profile) async {
    try {
      final headers = await _authHeaders();
      final body = {
        'age': profile.age,
        'height': profile.height,
        'weight': profile.weight,
        'gender': profile.gender,
        'allergies': profile.allergies,
        'diet_preference': profile.dietPreference,
      };

      final response = await http
          .post(
            Uri.parse('$_baseUrl/user/profile'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error('Profile sync hatası: $e');
      return false;
    }
  }

  // ── Hesabı Sil (Backend) ───────────────────────────────────────
  @override
  Future<bool> deleteUserFromBackend() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/user'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error('Backend user delete hatası: $e');
      return false;
    }
  }
}

/// Test edilebilir Statik Facade yapısı.
class ApiService {
  static IApiService _instance = ApiServiceImpl();

  @visibleForTesting
  static set instance(IApiService mock) => _instance = mock;

  static Future<bool> preprocessRawData({
    required List<Map<String, dynamic>> heartRateData,
    required List<Map<String, dynamic>> stepsData,
  }) => _instance.preprocessRawData(heartRateData: heartRateData, stepsData: stepsData);

  static Future<FoodAnalysisResult?> analyzeFoodImage(List<int> imageBytes) => _instance.analyzeFoodImage(imageBytes);
  static Future<DietPlanResult?> getDietPlan() => _instance.getDietPlan();
  
  static Future<AnomalyApiResult?> checkAnomalies({
    required List<Map<String, dynamic>> history,
    required Map<String, dynamic> today,
  }) => _instance.checkAnomalies(history: history, today: today);

  static Future<ExerciseApiResult?> fetchExercisePlan(ExerciseApiRequest req) => _instance.fetchExercisePlan(req);
  static Future<bool> sendExerciseFeedback(String feedback) => _instance.sendExerciseFeedback(feedback);
  static Future<RiskApiResult?> fetchRiskScore(RiskApiRequest req) => _instance.fetchRiskScore(req);
  static Future<RiskApiResult?> fetchDemoRiskScore() => _instance.fetchDemoRiskScore();
  static Future<List<RiskHistoryItem>> fetchRiskHistory({int limit = 30}) => _instance.fetchRiskHistory(limit: limit);
  static Future<List<MealHistoryItem>> fetchMealHistory({int limit = 30}) => _instance.fetchMealHistory(limit: limit);
  static Future<AssistantChatResponse?> sendAssistantMessage(String message) => _instance.sendAssistantMessage(message);
  static Future<MoodAdviceResponse?> fetchMoodAdvice(String mood) => _instance.fetchMoodAdvice(mood);
  static Future<List<ChatHistoryItem>> fetchChatHistory({int limit = 50}) => _instance.fetchChatHistory(limit: limit);
  static Future<bool> clearChatHistory() => _instance.clearChatHistory();
  static Future<bool> syncHealthToBackend(HealthEntry entry) => _instance.syncHealthToBackend(entry);
  static Future<bool> syncProfileToBackend(dynamic profile) => _instance.syncProfileToBackend(profile);
  static Future<bool> deleteUserFromBackend() => _instance.deleteUserFromBackend();
  static Future<FoodAnalysisResult?> saveManualFood(String foodName, String portion) => _instance.saveManualFood(foodName, portion);
}
