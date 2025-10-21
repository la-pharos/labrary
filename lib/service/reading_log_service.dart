import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ✅ 독서 기록 관리 서비스
/// - Firestore의 'users/{uid}/readingTimerLogs'에서 기록 관리
/// - 오늘의 총 독서시간, 날짜별 총 독서시간, 전체 누적 독서시간 계산 포함
class ReadingLogService {
  /// ✅ 타이머 기록 저장
  /// - 개별 독서 세션 저장 (1분 이상만)
  /// - 저장 시 전체 누적 독서시간(totalReadingMinutes) 갱신
  static Future<void> saveTimerLog({
    required String bookId,
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    required int durationMinutes,
  }) async {
    if (durationMinutes < 1) {
      print("⏹ durationMinutes < 1 → 기록 저장 안함");
      return;
    }

    String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      try {
        final anonCredential = await FirebaseAuth.instance.signInAnonymously();
        uid = anonCredential.user?.uid;
        print("✅ 익명 로그인 자동 수행: $uid");
      } catch (e) {
        print('❌ 익명 로그인 실패: $e');
        return;
      }
    }

    // ✅ 필드 정제
    final cleanTitle = title.replaceAll('.', '').replaceAll('\$', '').trim();
    final cleanBookId = bookId.trim();

    if (cleanBookId.isEmpty || cleanTitle.isEmpty) {
      print("❌ bookId 또는 title이 비어 있음. 저장 중단");
      return;
    }

    // ✅ 최종 로그 객체 구성
    final log = {
      'bookId': cleanBookId,
      'title': cleanTitle,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'durationMinutes': durationMinutes,
      'createdAt': FieldValue.serverTimestamp(),
    };

    print('[DEBUG🔥] saveTimerLog(): $log');

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      // ✅ 문서 존재 확인 후 없으면 초기화 (익명 사용자 포함)
      final userSnapshot = await userRef.get();
      if (!userSnapshot.exists) {
        await userRef.set({'totalReadingMinutes': 0});
        print('[DEBUG] 사용자 문서 없음 → 새로 생성');
      }

      // 🔥 기록 저장
      await userRef.collection('readingTimerLogs').add(log);

      // 🔥 누적 시간 업데이트
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        final data = snapshot.data() ?? {};

        int prevTotal = 0;
        try {
          prevTotal = (data['totalReadingMinutes'] ?? 0) is int
              ? data['totalReadingMinutes']
              : int.tryParse(data['totalReadingMinutes'].toString()) ?? 0;
        } catch (_) {
          print("❌ totalReadingMinutes 타입 변환 실패, 기본값 0 사용");
        }

        final newTotal = prevTotal + durationMinutes;
        print("[DEBUG] 업데이트할 totalReadingMinutes: $newTotal");

        transaction.update(userRef, {
          'totalReadingMinutes': newTotal,
        });
      });
    } catch (e) {
      print('[❌ ERROR] Firestore 저장 중 예외 발생: $e');
    }
  }

  /// ✅ 전체 누적 독서시간 조회
  static Future<int> getTotalReadingMinutes() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;

    final snapshot = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return (snapshot.data()?['totalReadingMinutes'] ?? 0) as int;
  }

  /// ✅ 오늘의 총 독서시간 조회 (오늘 날짜만 합산)
  static Future<int> getTodayTotalMinutes() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    print('[DEBUG🔥] getTodayTotalMinutes(): start=$start, end=$end');

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('readingTimerLogs')
        .where('startTime', isGreaterThanOrEqualTo: start) // ✅ 수정
        .where('startTime', isLessThan: end)               // ✅ 수정
        .get();

    int totalMinutes = 0;
    for (var doc in snapshot.docs) {
      final minutes = (doc.data()['durationMinutes'] ?? 0) as int;
      print('[DEBUG🔥] getTodayTotalMinutes() - Found log: ${doc.data()}');
      totalMinutes += minutes;
    }

    print('[DEBUG🔥] getTodayTotalMinutes(): totalMinutes=$totalMinutes');
    return totalMinutes;
  }

  /// ✅ 날짜별 총 독서시간 (yyyy-MM-dd 형식 key)
  static Future<Map<String, int>> getTotalReadingMinutesByDate() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('readingTimerLogs')
        .get();

    final Map<String, int> dailyMinutes = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = data['startTime'];

      DateTime? startTime;
      if (timestamp is Timestamp) {
        startTime = timestamp.toDate();
      } else if (timestamp is String) {
        startTime = DateTime.tryParse(timestamp);
      }

      final duration = (data['durationMinutes'] ?? 0) as int;
      if (startTime != null) {
        final dateKey = "${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')}";
        dailyMinutes[dateKey] = (dailyMinutes[dateKey] ?? 0) + duration;
      }
    }
    return dailyMinutes;
  }

  /// ✅ 특정 날짜의 타이머 기록 조회
  static Future<List<Map<String, dynamic>>> getTimerLogsForDate(DateTime date) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('readingTimerLogs')
        .where('startTime', isGreaterThanOrEqualTo: start) // ✅ FIXED
        .where('startTime', isLessThan: end)               // ✅ FIXED
        .orderBy('startTime', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['recordId'] = doc.id;
      return data;
    }).toList();
  }

  /// ✅ 특정 책의 독서 기록 조회
  static Future<List<Map<String, dynamic>>> getTimerLogsForBook(String bookId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('readingTimerLogs')
        .where('bookId', isEqualTo: bookId)
        .orderBy('startTime', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['recordId'] = doc.id;
      return data;
    }).toList();
  }

  /// ✅ 타이머 기록 삭제
  static Future<void> deleteTimerLog(String recordId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('readingTimerLogs');

    final snapshot = await collection.where(FieldPath.documentId, isEqualTo: recordId).get();
    if (snapshot.docs.isNotEmpty) {
      await snapshot.docs.first.reference.delete();
    }
  }
}
