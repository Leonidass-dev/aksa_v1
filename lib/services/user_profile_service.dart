import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'interfaces/i_user_profile_service.dart';
import 'api_service.dart';


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
  final List<String>? allergies;
  final String? dietPreference;

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
    this.allergies,
    this.dietPreference,
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
    'allergies': allergies ?? [],
    'dietPreference': dietPreference ?? '',
    'updatedAt': FieldValue.serverTimestamp(),
  };

  factory UserProfile.fromMap(String uid, Map<String, dynamic> m) {
    List<String>? parsedAllergies;
    if (m['allergies'] is String) {
      parsedAllergies = (m['allergies'] as String)
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (m['allergies'] is List) {
      parsedAllergies = (m['allergies'] as List).map((e) => e.toString()).toList();
    }

    return UserProfile(
      uid: uid,
      fullName: m['fullName'] ?? '',
      email: m['email'] ?? '',
      age: (m['age'] as num?)?.toInt() ?? 25,
      height: (m['height'] as num?)?.toDouble() ?? 170.0,
      weight: (m['weight'] ?? 70).toDouble(),
      gender: m['gender'] ?? 'M',
      photoUrl: m['photoUrl'] as String?,
      bio: m['bio'] as String?,
      allergies: parsedAllergies,
      dietPreference: m['dietPreference'] as String?,
    );
  }

  UserProfile copyWith({
    String? uid,
    String? fullName,
    String? email,
    int? age,
    double? height,
    double? weight,
    String? gender,
    String? photoUrl,
    String? bio,
    List<String>? allergies,
    String? dietPreference,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      age: age ?? this.age,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      gender: gender ?? this.gender,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      allergies: allergies ?? this.allergies,
      dietPreference: dietPreference ?? this.dietPreference,
    );
  }

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
    final uid = _uid;
    if (uid == null) return false;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return false;
    final data = doc.data();
    if (data == null) return false;
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
        
    // Profile güncellendiğinde backend'e de (PostgreSQL) senkronize et
    await ApiService.syncProfileToBackend(profile);
  }

  /// Profili oku
  @override
  Future<UserProfile?> getProfile() async {
    final uid = _uid;
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return UserProfile.fromMap(uid, data);
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
