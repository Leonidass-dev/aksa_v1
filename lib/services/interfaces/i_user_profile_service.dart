import '../user_profile_service.dart' show UserProfile;

abstract class IUserProfileService {
  Future<bool> profileExists();
  Future<void> saveProfile(UserProfile profile);
  Future<UserProfile?> getProfile({bool force = false});
}
