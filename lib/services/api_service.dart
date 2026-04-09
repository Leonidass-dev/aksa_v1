import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/health_entry.dart';
import '../models/api_models.dart';

// Re-export so existing `import 'api_service.dart'` importers still see model classes.
export '../models/api_models.dart';

/// FastAPI backend'e HTTP istekleri gönderen servis.
/// Tüm istekler Firebase token ile korunur.
class ApiService {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  // ── Firebase Token Helper ─────────────────────────────────────
  static Future<Map<String, String>> _authHeaders() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Tez Modül 2: Sensör Verisi Önişleme (Pipeline) ────────────
  static Future<bool> preprocessRawData({
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
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        debugPrint("ML Pipeline (Preprocessing) başarıyla tamamlandı.");
        return true;
      }
    } catch (e) {
      debugPrint('ML Pipeline hatası: $e');
    }
    return false;
  }

  // ── Yemek Fotoğrafı Analizi ──────────────────────────────────
  static Future<FoodAnalysisResult?> analyzeFoodImage(
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
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return FoodAnalysisResult.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Food analysis hatası: $e');
    }
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
        return AnomalyApiResult.fromJson(
          jsonDecode(utf8.decode(res.bodyBytes)),
        );
      }
    } catch (e) {
      debugPrint('Anomaly API hatası: $e');
    }
    return null;
  }

  // ── Egzersiz Planı Önerisi ─────────────────────────────────────
  static Future<ExerciseApiResult?> fetchExercisePlan(
    ExerciseApiRequest req,
  ) async {
    try {
      final headers = await _authHeaders();
      final res = await http.post(
        Uri.parse('$_baseUrl/exercise-plan'),
        headers: headers,
        body: jsonEncode(req.toJson()),
      );
      if (res.statusCode == 200) {
        return ExerciseApiResult.fromJson(
          jsonDecode(utf8.decode(res.bodyBytes)),
        );
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
    } catch (e) {
      debugPrint('Demo risk API hatası: $e');
    }
    return null;
  }

  // ── Risk Geçmişi ──────────────────────────────────────────────
  static Future<List<RiskHistoryItem>> fetchRiskHistory({
    int limit = 30,
  }) async {
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
  static Future<List<MealHistoryItem>> fetchMealHistory({
    int limit = 30,
  }) async {
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
  static Future<AssistantChatResponse?> sendAssistantMessage(
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
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        return AssistantChatResponse.fromJson(
          jsonDecode(utf8.decode(response.bodyBytes)),
        );
      }
    } catch (e) {
      debugPrint('Assistant API hatası: $e');
    }
    return null;
  }

  // ── Chat Geçmişi ──────────────────────────────────────────────
  static Future<List<ChatHistoryItem>> fetchChatHistory({
    int limit = 50,
  }) async {
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
  static Future<bool> syncHealthToBackend(HealthEntry entry) async {
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
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Health sync hatası: $e');
      return false;
    }
  }
}
