import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/user_profile.dart';
import 'package:dayverse_book/service/reading_log_service.dart';

class UserService {
  final _firestore = FirebaseFirestore.instance;

  /// ✅ Firebase Storage의 기본 프로필 이미지 URL
  static const String defaultProfileImageUrl =
      'https://firebasestorage.googleapis.com/v0/b/la-pharos.firebasestorage.app/o/profile_images%2Fprofile_default.png?alt=media&token=1f0cbfc9-e6ea-45b7-a5e4-2a8d1efc709f';

  /// 초기 회원가입 시 Firestore에 저장
  Future<void> createUser(User firebaseUser) async {
    final userProfile = UserProfile(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      nickname: '',
      instagramId: '',
      bio: '',
      isPremium: false,
      createdAt: Timestamp.now(),
      dailyReadingMinutes: 0,
      profileImageUrl: defaultProfileImageUrl, // ✅ 기본 이미지 등록
    );

    await _firestore.collection('users').doc(firebaseUser.uid).set(userProfile.toMap());
  }

  /// Firestore에서 불러오기
  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserProfile.fromMap(uid, doc.data()!);
    } else {
      return null;
    }
  }

  /// 사용자 정보 업데이트
  Future<void> updateUserProfile(String uid, Map<String, dynamic> updates) async {
    await _firestore.collection('users').doc(uid).update(updates);
  }
}
