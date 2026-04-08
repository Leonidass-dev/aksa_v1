import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
}

class UserProfileService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  /// Profil var mı kontrol et (onboarding atlandı mı?)
  static Future<bool> profileExists() async {
    if (_uid == null) return false;
    final doc = await _db.collection('users').doc(_uid).get();
    if (!doc.exists) return false;
    final data = doc.data()!;
    // age > 0 ise profil kurulmuş sayıyoruz
    return (data['age'] ?? 0) > 0;
  }

  /// Profili kaydet / güncelle
  static Future<void> saveProfile(UserProfile profile) async {
    await _db
        .collection('users')
        .doc(profile.uid)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  /// Profili oku
  static Future<UserProfile?> getProfile() async {
    if (_uid == null) return null;
    final doc = await _db.collection('users').doc(_uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromMap(_uid!, doc.data()!);
  }
}
