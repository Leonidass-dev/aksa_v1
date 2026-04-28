import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'interfaces/i_user_profile_service.dart';


/// Firestore users/{uid} dökümanında saklanan kullanıcı sağlık profili.
class UserProfile {
  final String uid;
  final String fullName;
  final String email;
  final int age;
  final double height; // cm
  final double weight; // kg
  final String gender; // 'M' | 'F' | 'O'
  final String? photoUrl;
  final String? bio;

  const UserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.age,
    required this.height,
    required this.weight,
    required this.gender,
    this.photoUrl,
    this.bio,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'fullName': fullName,
    'email': email,
    'age': age,
    'height': height,
    'weight': weight,
    'gender': gender,
    'photoUrl': photoUrl ?? '',
    'bio': bio ?? '',
    'updatedAt': FieldValue.serverTimestamp(),
  };

  factory UserProfile.fromMap(String uid, Map<String, dynamic> m) =>
      UserProfile(
        uid: uid,
        fullName: m['fullName'] ?? '',
        email: m['email'] ?? '',
        age: (m['age'] ?? 25) as int,
        height: (m['height'] ?? 170).toDouble(),
        weight: (m['weight'] ?? 70).toDouble(),
        gender: m['gender'] ?? 'M',
        photoUrl: m['photoUrl'] as String?,
        bio: m['bio'] as String?,
      );

  /// Profil tamamlama oranını hesaplar (0.0 - 1.0)
  double get completionRate {
    double score = 0;
    if (fullName.isNotEmpty && fullName != 'Kullanıcı') score += 0.2;
    if (age > 0) score += 0.2;
    if (height > 0) score += 0.2;
    if (weight > 0) score += 0.2;
    if (gender.isNotEmpty) score += 0.1;
    if (bio != null && bio!.isNotEmpty) score += 0.1;
    return score;
  }
}

class UserProfileServiceImpl implements IUserProfileService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  /// Profil var mı kontrol et (onboarding atlandı mı?)
  @override
  Future<bool> profileExists() async {
    if (_uid == null) return false;
    final doc = await _db.collection('users').doc(_uid).get();
    if (!doc.exists) return false;
    final data = doc.data()!;
    // age > 0 ise profil kurulmuş sayıyoruz
    return (data['age'] ?? 0) > 0;
  }

  /// Profili kaydet / güncelle
  @override
  Future<void> saveProfile(UserProfile profile) async {
    await _db
        .collection('users')
        .doc(profile.uid)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  /// Profili oku
  @override
  Future<UserProfile?> getProfile() async {
    if (_uid == null) return null;
    final doc = await _db.collection('users').doc(_uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromMap(_uid!, doc.data()!);
  }
}

/// Test edilebilir Statik Facade yapısı.
/// UI kodlarına dokunmadan arkaplandaki instance'ı mocklamaya izin verir.
class UserProfileService {
  static IUserProfileService _instance = UserProfileServiceImpl();

  @visibleForTesting
  static set instance(IUserProfileService mock) => _instance = mock;

  static Future<bool> profileExists() => _instance.profileExists();
  static Future<void> saveProfile(UserProfile profile) => _instance.saveProfile(profile);
  static Future<UserProfile?> getProfile() => _instance.getProfile();
}
