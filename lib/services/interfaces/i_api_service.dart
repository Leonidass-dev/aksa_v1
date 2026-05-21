import '../api_service.dart' show FoodAnalysisResult, DietPlanResult, AnomalyApiResult, ExerciseApiRequest, ExerciseApiResult, RiskApiRequest, RiskApiResult, RiskHistoryItem, MealHistoryItem, AssistantChatResponse, ChatHistoryItem, MoodAdviceResponse;
import '../health_service.dart' show HealthEntry;
import '../user_profile_service.dart' show UserProfile;

abstract class IApiService {
  Future<bool> preprocessRawData({
    required List<Map<String, dynamic>> heartRateData,
    required List<Map<String, dynamic>> stepsData,
  });

  Future<FoodAnalysisResult?> analyzeFoodImage(List<int> imageBytes);

  Future<DietPlanResult?> getDietPlan();

  Future<AnomalyApiResult?> checkAnomalies({
    required List<Map<String, dynamic>> history,
    required Map<String, dynamic> today,
  });

  Future<ExerciseApiResult?> fetchExercisePlan(ExerciseApiRequest req);
  Future<bool> sendExerciseFeedback(String feedback);

  Future<RiskApiResult?> fetchRiskScore(RiskApiRequest req);

  Future<RiskApiResult?> fetchDemoRiskScore();

  Future<List<RiskHistoryItem>> fetchRiskHistory({int limit = 7});

  Future<List<MealHistoryItem>> fetchMealHistory({int limit = 10});

  Future<AssistantChatResponse?> sendAssistantMessage(String message);

  Future<MoodAdviceResponse?> fetchMoodAdvice(String mood);

  Future<List<ChatHistoryItem>> fetchChatHistory({int limit = 50});

  Future<bool> clearChatHistory();

  Future<bool> syncHealthToBackend(HealthEntry entry);

  Future<bool> syncProfileToBackend(UserProfile profile);

  Future<bool> deleteUserFromBackend();

  Future<FoodAnalysisResult?> saveManualFood(String foodName, String portion);
}
