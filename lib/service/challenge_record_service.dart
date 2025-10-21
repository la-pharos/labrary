import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/challenge_attempt_model.dart';
import 'package:dayverse_book/model/book_model.dart';

class ChallengeRecordService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// ✅ 초기 기록 저장
  static Future<void> saveInitialRecord(
      Challenge challenge, {
        int? selectedDuration,
        Map<String, dynamic>? additionalFields,
      }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('challengeRecords')
        .doc(challenge.id);

    final resolvedDuration = selectedDuration ??
        (challenge.checkCountOptions?.isNotEmpty == true
            ? challenge.checkCountOptions!.first
            : 5); // fallback

    final booksAsModel = challenge.participatingBooks ?? [];

    final now = DateTime.now();
    final initialAttempt = ChallengeAttempt(
      startDate: challenge.startDate ?? now,
      endDate: challenge.endDate,
      completedBookIds: [],
      completed: false,
      isSuccessful: false,
      stageIndex: challenge.stageType != ChallengeStageType.single ? 0 : null,
      selectedDuration: resolvedDuration,
      participatedBooks: booksAsModel, // ✅ BookModel 리스트 그대로 사용
    );

    final initialData = {
      'isJoined': true,
      'countChecks': {},
      'specificBookChecks': {},
      'routineChecks': {},
      'dailyMinutes': {},
      'pageCounts': {},
      'bookReadPages': {},
      'completedCount': 0,
      'participatingBooks': booksAsModel.map((b) => b.toMap()).toList(), // ✅ Firebase 저장용
      'attempts': [initialAttempt.toMap()],
      'startDate': challenge.startDate?.toIso8601String(),
      'endDate': challenge.endDate?.toIso8601String(),
      'routineStartDate': (challenge.startDate ?? now).toIso8601String(),
      'selectedDuration': resolvedDuration,
      'targetCheckCount': resolvedDuration,
      if (initialAttempt.stageIndex != null) 'stageIndex': initialAttempt.stageIndex,
      if (additionalFields != null) ...additionalFields,
    };

    debugPrint('[SAVE] Initial record for ${challenge.title}: $initialData');
    await docRef.set(initialData, SetOptions(merge: true));
  }

  /// ✅ 루틴 체크 + dailyMinutes 저장
  static Future<void> saveRoutineCheck(
      String challengeId,
      DateTime date,
      bool isChecked, {
        int minutes = 0,
      }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final dateKey = _formatDate(date);

    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('challengeRecords')
        .doc(challengeId);

    final snapshot = await docRef.get();
    final data = snapshot.data() ?? {};

    final routineChecks = Map<String, dynamic>.from(data['routineChecks'] ?? {});
    final dailyMinutes = Map<String, dynamic>.from(data['dailyMinutes'] ?? {});
    int completedCount = (data['completedCount'] as int?) ?? 0;

    final alreadyChecked = routineChecks[dateKey] == true;
    routineChecks[dateKey] = isChecked;
    dailyMinutes[dateKey] = minutes;

    if (isChecked && !alreadyChecked) {
      completedCount += 1;
    }

    final updatedData = {
      'routineChecks': routineChecks,
      'dailyMinutes': dailyMinutes,
      'completedCount': completedCount,
    };

    await docRef.set(updatedData, SetOptions(merge: true));
    debugPrint("[SAVE] Routine check → $dateKey | isChecked=$isChecked | minutes=$minutes");
  }

  static Future<Map<String, dynamic>> fetchChallengeRecord(String challengeId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {};
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('challengeRecords')
        .doc(challengeId)
        .get();
    return Map<String, dynamic>.from(doc.data() ?? {});
  }

  static Future<void> saveCountCheck(
      String challengeId,
      DateTime date,
      bool isChecked,
      ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final dateKey = _formatDate(date);
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('challengeRecords')
        .doc(challengeId)
        .set({
      'countChecks': {dateKey: isChecked},
    }, SetOptions(merge: true));
  }

  static Future<void> saveSpecificBookCheck(
      String challengeId,
      String bookId,
      bool isChecked,
      ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('challengeRecords')
        .doc(challengeId)
        .set({
      'specificBookChecks.$bookId': isChecked,
    }, SetOptions(merge: true));
  }

  static Future<void> savePageCount(
      String challengeId,
      DateTime date,
      int pageCount,
      ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final dateKey = _formatDate(date);
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('challengeRecords')
        .doc(challengeId);

    final snapshot = await docRef.get();
    final data = snapshot.data() ?? {};
    final pageCounts = Map<String, int>.from(data['pageCounts'] ?? {});
    pageCounts[dateKey] = pageCount;

    await docRef.set({'pageCounts': pageCounts}, SetOptions(merge: true));
  }

  static Future<void> incrementCompletedCount(String challengeId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('challengeRecords')
        .doc(challengeId);

    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      final current = snapshot.data()?['completedCount'] ?? 0;
      tx.set(docRef, {'completedCount': current + 1}, SetOptions(merge: true));
    });
  }

  static Future<void> saveBookReadPages(
      String challengeId,
      String bookId,
      int pageCount,
      ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('challengeRecords')
        .doc(challengeId);

    final snapshot = await docRef.get();
    final data = snapshot.data() ?? {};
    final pages = Map<String, int>.from(data['bookReadPages'] ?? {});
    pages[bookId] = pageCount;

    await docRef.set({'bookReadPages': pages}, SetOptions(merge: true));
  }

  static Future<void> updateChallengeRecord(String challengeId, Map<String, dynamic> updatedFields) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('challengeRecords')
        .doc(challengeId)
        .set(updatedFields, SetOptions(merge: true));
  }

  static Future<void> saveChallengeRecord(String challengeId, Map<String, dynamic> recordData) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('challengeRecords')
        .doc(challengeId)
        .set(recordData, SetOptions(merge: true));
  }

  static Future<void> deleteChallengeRecord(String challengeId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('challengeRecords')
        .doc(challengeId)
        .delete();
  }

  static String _formatDate(DateTime date) =>
      "${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}";

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  static Future<void> saveChallengeRecordToAttempt(String challengeId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('challengeRecords')
        .doc(challengeId);

    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final attempts = data['attempts'] as List? ?? [];
    if (attempts.isEmpty) return;

    final lastAttemptRaw = Map<String, dynamic>.from(attempts.last);
    lastAttemptRaw['recordData'] = {
      'routineChecks': data['routineChecks'] ?? {},
      'countChecks': data['countChecks'] ?? {},
      'bookReadPages': data['bookReadPages'] ?? {},
      'dailyMinutes': data['dailyMinutes'] ?? {},
      'pageCounts': data['pageCounts'] ?? {},
    };

    attempts[attempts.length - 1] = lastAttemptRaw;

    await docRef.set({'attempts': attempts}, SetOptions(merge: true));
  }

}
