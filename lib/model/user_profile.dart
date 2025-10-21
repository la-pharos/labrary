import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  final String nickname;
  final String instagramId;
  final String bio;
  final bool isPremium;
  final Timestamp createdAt;
  final int? dailyReadingMinutes;
  final String? profileImageUrl;

  UserProfile({
    required this.uid,
    required this.email,
    required this.nickname,
    required this.instagramId,
    required this.bio,
    required this.isPremium,
    required this.createdAt,
    this.dailyReadingMinutes,
    this.profileImageUrl,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      email: data['email'] ?? '',
      nickname: data['nickname'] ?? '',
      instagramId: data['instagramId'] ?? '',
      bio: data['bio'] ?? '',
      isPremium: data['isPremium'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      dailyReadingMinutes: data['dailyReadingMinutes'],
      profileImageUrl: data['profileImageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'nickname': nickname,
      'instagramId': instagramId,
      'bio': bio,
      'isPremium': isPremium,
      'createdAt': createdAt,
      'dailyReadingMinutes': dailyReadingMinutes ?? 0,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
    };
  }
}
