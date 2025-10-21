import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/main.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/challenge_attempt_model.dart';
import 'package:dayverse_book/utils/challenge_check_utils.dart';
import 'package:dayverse_book/utils/challenge_progress_utils.dart';
import 'package:dayverse_book/model/challenge_attempt_model.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/service/reading_log_service.dart';

class ChallengeProvider extends ChangeNotifier {
  final List<Challenge> _allChallenges = [];
  final _firestore = FirebaseFirestore.instance;

  List<Challenge> get allChallenges => _allChallenges;

  /// ✅ Firestore에서 챌린지 로드
  Future<void> loadChallengesFromFirestore(String userId) async {
    _allChallenges.clear();

    // 1) 기본 챌린지 로드
    final baseJson = await rootBundle.loadString('assets/challenges.json');
    final List<dynamic> baseList = json.decode(baseJson);
    final baseChallenges = baseList.map((e) => Challenge.fromMap(e)).toList();

    // 2) 유저 챌린지 로드
    final snapshot = await _firestore
        .collection('users').doc(userId)
        .collection('challenges')
        .get();

    final userChallengesById = <String, Challenge>{};
    for (final doc in snapshot.docs) {
      final c = Challenge.fromMap(doc.data());
      userChallengesById[c.id] = c;
    }

    // 3) 병합: base 우선 + 유저 override
    final baseIds = <String>{};
    for (final base in baseChallenges) {
      baseIds.add(base.id);
      final override = userChallengesById[base.id];
      _allChallenges.add(override ?? base);
    }

    // ✅ 4) base에 없는 “유저 전용(커스텀)”도 추가
    for (final uc in userChallengesById.values) {
      if (!baseIds.contains(uc.id)) {
        _allChallenges.add(uc);
      }
    }

    notifyListeners();
  }

  Future<List<Challenge>> loadChallengeListFromAssets() async {
    final jsonString = await rootBundle.loadString('assets/challenges.json');
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((e) => Challenge.fromMap(e)).toList();
  }

  /// ✅ 챌린지 Firestore에 저장
  Future<void> saveChallengeToFirestore(String userId, Challenge challenge) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('challenges')
        .doc(challenge.id)
        .set(challenge.toMap());
  }

  /// ✅ 기본 챌린지 로드 (assets + 책 정보 연동)
  Future<void> loadChallengesFromAssets() async {
    final jsonString = await rootBundle.loadString('assets/challenges.json');
    final List<dynamic> jsonList = json.decode(jsonString);
    _allChallenges.clear();
    _allChallenges.addAll(jsonList.map((e) => Challenge.fromMap(e)).toList());
    notifyListeners();
  }

  /// ✅ 단일 챌린지인지 스테이지 챌린지인지 판별해서 필터링
  List<Challenge> get normalChallenges =>
      _allChallenges.where((c) => c.stageType == ChallengeStageType.single).toList();

  List<Challenge> get stageChallenges =>
      _allChallenges.where((c) => c.stageType == ChallengeStageType.staged).toList();

  /// ✅ 참여 중인 챌린지 (아카이브 제외)
  List<Challenge> get joinedChallenges {
    return _allChallenges.where((c) {
      if (c.isArchived) return false;          // ✅ 숨김 제거
      if (!c.isJoined) return false;

      // 🔁 반복 가능 챌린지인데 마지막 attempt 완료면 → 참여 중 아님
      if (c.isRepeatable) {
        final last = c.attempts.isNotEmpty ? c.attempts.last : null;
        if (last != null && last.isCompleted) return false;
      }
      return true;
    }).toList();
  }

  /// ✅ 완료된 챌린지 (아카이브 제외)
  List<Challenge> get completedChallenges =>
      _allChallenges.where((c) => !c.isArchived && c.isCompleted).toList();

  /// ✅ 아직 참여하지 않은 챌린지
  List<Challenge> get notJoinedChallenges {
    return _allChallenges.where((challenge) {
      // ✅ 아카이브는 모든 섹션에서 제외
      if (challenge.isArchived) return false;

      // ✅ 커스텀은 '참여하기' 섹션에 절대 노출 금지
      if (challenge.isCustom) return false;

      final attempts = challenge.attempts;

      // ✅ 이력 없음 → 참여 가능
      if (attempts.isEmpty) return true;

      final isStageBased = challenge.stageType == ChallengeStageType.staged;
      final lastAttempt = attempts.last;

      // ✅ [스테이지] 모든 스테이지 완료 → 참여 불가
      if (isStageBased) {
        final totalStages = challenge.stageDurations.length;
        final completedStages = attempts.where((a) => a.completed).length;
        if (completedStages >= totalStages) return false;

        // 진행 중이면 notJoined 아님
        final isCurrentlyRunning = !lastAttempt.completed && challenge.isJoined == false;
        if (isCurrentlyRunning) return false;

        // 다음 스테이지 대기 상태면 참여 가능
        return !challenge.isJoined;
      }

      // ✅ [반복 가능 단일] 완료 후 재참여 허용
      if (challenge.isRepeatable && lastAttempt.completed) return true;

      // ✅ [일반 단일] 이미 성공했으면 재참여 불가
      if (!challenge.isRepeatable && lastAttempt.completed) return false;

      return !challenge.isJoined;
    }).toList();
  }

  /// ✅ 챌린지 참여
  Future<void> joinChallenge({
    required Challenge challenge,
    required DateTime startDate,
    int? duration,
    List<BookModel>? participatingBooks,
    required String userId,
  }) async {
    final index = _allChallenges.indexWhere((c) => c.id == challenge.id);
    if (index == -1) return;

    List<ChallengeAttempt> updatedAttempts = [...challenge.attempts];

    final bool isStaged = challenge.stageType == ChallengeStageType.staged;
    final bool isRepeatableSingle = challenge.stageType == ChallengeStageType.single &&
        challenge.isRepeatable;

    final bool shouldCreateNewAttempt =
        updatedAttempts.isEmpty ||
            updatedAttempts.last.startDate != null && (
                isStaged ||                       // 스테이지 챌린지는 항상 새 attempt 필요
                    isRepeatableSingle && updatedAttempts.last.isCompleted // 단일 + 반복가능이면 완료된 후 새 attempt
            );

    if (shouldCreateNewAttempt) {
      int? currentStageIndex;

      if (isStaged) {
        // ✅ 수정된 로직: 완료된 스테이지 수를 기준으로 현재 도전 스테이지 결정
        final completed = challenge.attempts.where((a) => a.completed).length;
        currentStageIndex = completed;
      }

      final newAttempt = ChallengeAttempt(
        stageIndex: currentStageIndex,
        startDate: startDate,
        endDate: challenge.period == ChallengePeriod.periodBased ? challenge.endDate : null,
        selectedDuration: duration,
        participatedBooks: participatingBooks,
        completedBookIds: [],
      );

      updatedAttempts.add(newAttempt);
    } else {
      // 기존 참여 전 attempt 덮어쓰기
      final lastIndex = updatedAttempts.length - 1;
      updatedAttempts[lastIndex] = updatedAttempts[lastIndex].copyWith(
        startDate: startDate,
        selectedDuration: duration,
        participatedBooks: participatingBooks,
        completedBookIds: [],
      );
    }

    final updated = challenge.copyWith(
      isJoined: true,
      isCompleted: false,
      attempts: updatedAttempts,
      participatingBooks: participatingBooks,
    );

    _allChallenges[index] = updated;
    await saveChallengeToFirestore(userId, updated);
    notifyListeners();
  }

  /// ✅ 챌린지 포기
  Future<void> unjoinChallenge(Challenge challenge, String userId) async {
    final index = _allChallenges.indexWhere((c) => c.id == challenge.id);
    if (index == -1) return;

    final updated = challenge.copyWith(
      isJoined: false,
      isCompleted: false,
      attempts: [],
    );

    _allChallenges[index] = updated;
    await saveChallengeToFirestore(userId, updated);
    notifyListeners();
  }

  /// ✅ 챌린지 완료 처리
  Future<void> completeChallenge(Challenge challenge, String attemptId, String userId) async {
    final index = _allChallenges.indexWhere((c) => c.id == challenge.id);
    if (index == -1) return;

    final updatedAttempts = challenge.attempts.map((attempt) {
      if (attempt.attemptId == attemptId) {
        return attempt.copyWith(
          completed: true,
          endDate: DateTime.now(), // ✅ ✅ ✅ 여기 추가
        );
      }
      return attempt;
    }).toList();

    final isAllStagesDone = challenge.stageType == ChallengeStageType.staged &&
        updatedAttempts.length == challenge.stageDurations.length &&
        updatedAttempts.every((a) => a.completed);

    final updated = challenge.copyWith(
      attempts: updatedAttempts,
      isCompleted:
      challenge.stageType == ChallengeStageType.single ? true : isAllStagesDone,
    );

    _allChallenges[index] = updated;
    await saveChallengeToFirestore(userId, updated);
    notifyListeners();
  }

  /// ✅ 챌린지 수동 업데이트
  Future<void> updateChallenge(Challenge updated, String userId) async {
    final index = _allChallenges.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      _allChallenges[index] = updated;
      await saveChallengeToFirestore(userId, updated);
      notifyListeners();
    }
  }

  /// ✅ 다음 스테이지 생성
  Challenge? generateNextStageChallenge(Challenge current) {
    if (current.stageType != ChallengeStageType.staged) return null;
    if (current.isCompleted == true) return null;

    // ✅ 완료된 스테이지 수 기준으로 다음 스테이지 결정
    final completedStages = current.attempts.where((a) => a.completed).length;
    final nextStageIndex = completedStages;

    // ✅ 최대 스테이지 수 초과 방지
    if (nextStageIndex >= current.stageDurations.length) return null;

    // ✅ 중복 생성 방지
    final alreadyExists = current.attempts.any((a) => (a.stageIndex ?? -1) == nextStageIndex);
    if (alreadyExists) return null;

    final nextAttemptDuration = current.stageDurations[nextStageIndex];

    final newAttempt = ChallengeAttempt(
      stageIndex: nextStageIndex,
      selectedDuration: nextAttemptDuration,
      startDate: DateTime.now(),
    );

    return current.copyWith(
      isJoined: false,
      isCompleted: false,
      attempts: [
        ...current.attempts,
        newAttempt,
      ],
    );
  }

  /// ✅ 스테이지 챌린지에 다음 스테이지 참여
  Future<void> joinChallengeNextStage(Challenge challenge, String userId) async {
    final index = _allChallenges.indexWhere((c) => c.id == challenge.id);
    if (index == -1) {
      //debugPrint("🧨 joinChallengeNextStage: challenge not found: ${challenge.id}");
      return;
    }

    final next = generateNextStageChallenge(challenge);
    if (next == null) {
      //debugPrint("🧨 joinChallengeNextStage: no next stage available for ${challenge.id}");
      return;
    }

    //debugPrint("🚀 joinChallengeNextStage: next stage attempt created: stageIndex=${next.attempts.last.stageIndex}");

    _allChallenges[index] = next;
    await saveChallengeToFirestore(userId, next);

    //debugPrint("💾 joinChallengeNextStage: next stage saved to Firestore");

    notifyListeners();
  }

  /// ✅ 챌린지 초기화
  Future<void> resetChallenge(String challengeId, String userId) async {
    final index = _allChallenges.indexWhere((c) => c.id == challengeId);
    if (index == -1) return;

    final original = _allChallenges[index];
    final updated = original.copyWith(
      isJoined: false,
      isCompleted: false,
      attempts: [],
    );

    _allChallenges[index] = updated;
    await saveChallengeToFirestore(userId, updated);
    notifyListeners();
  }

  /// ✅ 챌린지 목표 수 반환
  int getTargetCount(Challenge challenge) {
    if (challenge.stageType == ChallengeStageType.staged) {
      final latest = challenge.attempts.isNotEmpty ? challenge.attempts.last : null;

      if (challenge.method == ChallengeMethod.countBased) {
        final duration = latest?.selectedDuration;
        if (duration == null || duration <= 0) {
          //debugPrint("🚨 [getTargetCount] 스테이지형 countBased인데 selectedDuration이 유효하지 않음: ${challenge.id}");
          return 999999;
        }
        return duration;
      } else if (challenge.method == ChallengeMethod.quantityBased) {
        return challenge.totalBooks ?? 0;
      } else if (challenge.method == ChallengeMethod.specificBooks) {
        return challenge.requiredBooks?.length ?? 0;
      }
    } else {
      switch (challenge.method) {
        case ChallengeMethod.countBased:
          final list = challenge.checkCountOptions;
          if (list == null || list.isEmpty) {
            //debugPrint("🚨 [getTargetCount] countBased인데 checkCountOptions가 null 또는 비어있음: ${challenge.id}");
            return 999999;
          }
          return list.first;
        case ChallengeMethod.quantityBased:
          return challenge.totalBooks ?? 0;
        case ChallengeMethod.specificBooks:
          return challenge.requiredBooks?.length ?? 0;
      }
    }

    return 0;
  }

  /// ✅ 챌린지 상태 갱신 (진행률/완료 여부 등)
  Future<void> refreshChallengeStatus(
      String challengeId, {
        required List<BookModel> savedBooks,
        required String userId,
      }) async {
    final index = _allChallenges.indexWhere((c) => c.id == challengeId);
    if (index == -1) return;

    final challenge = _allChallenges[index];
    final latestAttempt = challenge.attempts.isNotEmpty ? challenge.attempts.last : null;
    if (latestAttempt == null) return;

    final target = getTargetCount(challenge);
    if (target <= 0) {
      //debugPrint("🚨 [refreshChallengeStatus] target 값이 0 이하! challengeId: ${challenge.id}");
      return;
    }

    // ✅ 진행률 관련 record/attempt 갱신 로직은 그대로 유지
    ChallengeAttempt updatedAttempt = latestAttempt;

    if (challenge.method == ChallengeMethod.specificBooks) {
      final checkAction = getChallengeCheckActionType(challenge);
      if (checkAction == ChallengeCheckActionType.pageAuto) {
        final record = {
          ...(latestAttempt.recordData ?? {}),
          'savedBooks': savedBooks,
        };
        final completed = ChallengeProgressUtils.getCompletedCount(challenge, record);
        final target = ChallengeProgressUtils.getTargetCount(challenge, record);
        //debugPrint("📘 pageAuto 진행률: $completed / $target");

        // ✅ 기존엔 기록만 반영했는데 → 완료 도서 ID들도 반영해야 함
        final completedIds = ChallengeProgressUtils.getCompletedBookIdsForSpecificBooks(challenge, savedBooks);
        updatedAttempt = updatedAttempt.copyWith(completedBookIds: completedIds);
      } else {
        // 라이브러리 기반 자동 체크
        final requiredIds = challenge.requiredBooks?.map((b) => b.id).toSet() ?? {};
        final completedIds = savedBooks
            .where((b) => requiredIds.contains(b.id) && b.endDate != null)
            .map((b) => b.id)
            .toSet();
        updatedAttempt = updatedAttempt.copyWith(completedBookIds: completedIds.toList());
      }
    } else if (challenge.method == ChallengeMethod.quantityBased) {
      final completedBooks = savedBooks.where((b) => b.endDate != null).toList();
      if (challenge.period == ChallengePeriod.periodBased &&
          challenge.startDate != null &&
          challenge.endDate != null) {
        final inRangeBooks = completedBooks.where((b) {
          final d = b.endDate!;
          return d.isAfter(challenge.startDate!.subtract(const Duration(days: 1))) &&
              d.isBefore(challenge.endDate!.add(const Duration(days: 1)));
        }).toList();
        // ✅ 진행 상황만 갱신
        updatedAttempt = updatedAttempt.copyWith(completedBookIds: inRangeBooks.map((b) => b.id).toList());
      } else {
        updatedAttempt = updatedAttempt.copyWith(completedBookIds: completedBooks.map((b) => b.id).toList());
      }
    } else if (challenge.method == ChallengeMethod.countBased) {
      final checkAction = getChallengeCheckActionType(challenge);

      if (challenge.category == ChallengeCategory.routine &&
          challenge.method == ChallengeMethod.countBased &&
          checkAction == ChallengeCheckActionType.timerAuto) {
        final recordData = Map<String, dynamic>.from(latestAttempt.recordData ?? {});
        final dailyMap = (recordData['dailyMinutes'] as Map?)?.cast<String, dynamic>() ?? {};

        final now = DateTime.now();
        final todayKey = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

        // ✅ 오늘의 독서 시간 계산
        final todayMinutes = await ReadingLogService.getTodayTotalMinutes();
        dailyMap[todayKey] = todayMinutes;

        recordData['dailyMinutes'] = dailyMap;

        updatedAttempt = updatedAttempt.copyWith(recordData: recordData);
      } else if (checkAction == ChallengeCheckActionType.timerAuto) {
        final record = latestAttempt.recordData ?? {};
        updatedAttempt = updatedAttempt.copyWith(recordData: record);
      } else {
        final checkCount = latestAttempt.completedBookIds.length;
        //debugPrint("📘 countBased 진행: $checkCount / $target");
        // 완료 판단은 하지 않음
      }
    }

    final updatedChallenge = challenge.copyWith(
      attempts: [
        ...challenge.attempts.sublist(0, challenge.attempts.length - 1),
        updatedAttempt,
      ],
      // ✅ isCompleted 강제 false 또는 기존 값 유지
      isCompleted: challenge.isCompleted,
    );

    _allChallenges[index] = updatedChallenge;
    await saveChallengeToFirestore(userId, updatedChallenge);
    notifyListeners();
  }

  /// ✅ 모든 챌린지 상태 초기화 (기록 초기화/회원 탈퇴 등에서 사용)
  Future<void> clearChallengeStates({required String userId}) async {
    _allChallenges.clear();

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('challenges')
        .get();

    for (final doc in snapshot.docs) {
      final challenge = Challenge.fromMap(doc.data());
      final cleared = challenge.copyWith(
        isJoined: false,
        isCompleted: false,
        attempts: [],
      );
      _allChallenges.add(cleared);
      await saveChallengeToFirestore(userId, cleared);
    }

    notifyListeners();
  }

  /// ✅ 모든 챌린지 상태를 일괄 갱신
  Future<void> refreshAllStatuses({
    required List<BookModel> savedBooks,
    required String userId,
  }) async {
    for (final challenge in _allChallenges) {
      await refreshChallengeStatus(
        challenge.id,
        savedBooks: savedBooks,
        userId: userId,
      );
    }

    // ✅ 주기적 자동 만료 처리
    await sweepAndFailExpired(userId: userId);
  }

  /// ✅ 챌린지 완료 처리 (다음 스테이지 자동참여 제거)
  Future<void> markChallengeAsCompleted(String challengeId, String userId) async {
    final index = _allChallenges.indexWhere((c) => c.id == challengeId);
    if (index == -1) return;

    final current = _allChallenges[index];
    final latestAttempt = current.attempts.isNotEmpty ? current.attempts.last : null;
    if (latestAttempt == null || latestAttempt.completed) return;

    // ✅ 해당 시도 완료 처리
    final updatedAttempt = latestAttempt.copyWith(
      completed: true,
      endDate: DateTime.now(), // ✅ ✅ ✅ 여기도 추가
    );
    final updatedAttempts = [
      ...current.attempts.sublist(0, current.attempts.length - 1),
      updatedAttempt,
    ];

    // ✅ 스테이지 챌린지인지 확인하고 전체 완료 여부 판단
    bool isCompleted = false;
    if (current.stageType == ChallengeStageType.staged) {
      final totalStages = current.stageDurations.length;
      final completedStages = updatedAttempts.where((a) => a.completed).length;
      isCompleted = completedStages >= totalStages;
    } else {
      isCompleted = true;
    }

    // ✅ 중복 attempt 제거 (stageIndex 기준)
    final deduplicatedAttempts = <int, ChallengeAttempt>{};
    for (final attempt in updatedAttempts) {
      final idx = attempt.stageIndex ?? 0;
      deduplicatedAttempts[idx] = attempt;
    }

    final finalAttempts = deduplicatedAttempts.values.toList()
      ..sort((a, b) => (a.stageIndex ?? 0).compareTo(b.stageIndex ?? 0));

    final updatedChallenge = current.copyWith(
      attempts: finalAttempts,
      isCompleted: isCompleted,
      isJoined: false,
    );

    _allChallenges[index] = updatedChallenge;
    await saveChallengeToFirestore(userId, updatedChallenge);

    // ✅ 다음 스테이지 attempt 추가: 마지막 스테이지가 아닐 경우에만
    if (current.stageType == ChallengeStageType.staged &&
        !isCompleted &&
        updatedAttempt.stageIndex != null &&
        updatedAttempt.stageIndex! < current.stageDurations.length - 1) {
      final nextStage = generateNextStageChallenge(updatedChallenge);
      if (nextStage != null) {
        _allChallenges[index] = nextStage;
        await saveChallengeToFirestore(userId, nextStage);
      }
    }

    notifyListeners();
  }

  bool _isExpiredAttempt(ChallengeAttempt a) {
    if (a.endDate == null) return false;
    final now = DateTime.now();
    final end = DateTime(a.endDate!.year, a.endDate!.month, a.endDate!.day, 23, 59, 59);
    return now.isAfter(end);
  }

  /// ✅ 기한 지난 커스텀 챌린지를 자동 실패 처리
  Future<void> sweepAndFailExpired({
    required String userId,
  }) async {
    for (final c in _allChallenges) {
      if (!c.isCustom) continue;
      if (c.isArchived) continue;
      if (!c.isJoined) continue;
      if (c.attempts.isEmpty) continue;

      final last = c.attempts.last;
      // 이미 완료(성공/실패)라면 스킵
      if (last.completed == true) continue;

      // ✅ 기한이 지났으면 자동 실패 처리
      if (_isExpiredAttempt(last)) {
        await markChallengeAsFailed(c.id, userId);
      }
    }
  }

  Challenge? findChallengeById(String id) {
    try {
      final challenge = _allChallenges.firstWhere((c) => c.id == id);
      final attemptsLog = challenge.attempts
          .map((a) => "(${a.stageIndex}, completed: ${a.completed})")
          .join(', ');
      //debugPrint("🔍 findChallengeById($id) → attempts: [$attemptsLog]");
      return challenge;
    } catch (_) {
      //debugPrint("❌ findChallengeById($id) → not found");
      return null;
    }
  }

  Future<void> initialize(User user, List<BookModel> books) async {
    await loadChallengesFromFirestore(user.uid);
    for (final challenge in _allChallenges) {
      await refreshChallengeStatus(
        challenge.id,
        userId: user.uid,
        savedBooks: books,
      );
    }

    // ✅ 기한 지난 커스텀 챌린지 자동 실패 처리
    await sweepAndFailExpired(userId: user.uid);
  }

  void syncBookPageReadToChallenge(String bookId, int pageRead, String userId) {
    for (int i = 0; i < _allChallenges.length; i++) {
      final challenge = _allChallenges[i];

      if (getChallengeCheckActionType(challenge) == ChallengeCheckActionType.pageAuto &&
          challenge.attempts.isNotEmpty) {
        final attempt = challenge.attempts.last;
        final record = attempt.recordData ?? <String, dynamic>{};
        final bookReadPages = (record['bookReadPages'] as Map?)?.cast<String, dynamic>() ?? {};

        final isUserDefined = challenge.specificBookMode == SpecificBookMode.userDefined &&
            (attempt.participatedBooks?.any((b) => b.id == bookId) ?? false);

        final isSystemDefined = challenge.specificBookMode == SpecificBookMode.systemDefined &&
            (challenge.requiredBooks?.any((b) => b.id == bookId) ?? false);

        if (isUserDefined || isSystemDefined) {
          bookReadPages[bookId] = pageRead;
          record['bookReadPages'] = bookReadPages;

          final updatedAttempt = attempt.copyWith(recordData: record);
          final updatedAttempts = [
            ...challenge.attempts.sublist(0, challenge.attempts.length - 1),
            updatedAttempt,
          ];
          final updatedChallenge = challenge.copyWith(attempts: updatedAttempts);

          _allChallenges[i] = updatedChallenge;
          notifyListeners();

          // ✅ 추가: 자동으로 챌린지 상태 갱신
          refreshChallengeStatus(
            challenge.id,
            savedBooks: _getCurrentSavedBooks(), // 이 함수는 Provider에서 List<BookModel> 불러오는 함수로 구현되어야 함
            userId: userId,
          );
        }
      }
    }
  }

  List<BookModel> _getCurrentSavedBooks() {
    final context = navigatorKey.currentContext;
    if (context == null) return [];
    try {
      return Provider.of<SavedBooksProvider>(context, listen: false).savedBooks;
    } catch (_) {
      return [];
    }
  }

  void syncPageReadFromBooks(List<BookModel> savedBooks) {
    for (int i = 0; i < _allChallenges.length; i++) {
      final challenge = _allChallenges[i];
      if (getChallengeCheckActionType(challenge) != ChallengeCheckActionType.pageAuto) continue;
      if (challenge.attempts.isEmpty) continue;

      final attempt = challenge.attempts.last;
      final record = attempt.recordData ?? <String, dynamic>{};
      final bookReadPages = <String, dynamic>{};

      final isUserDefined = challenge.specificBookMode == SpecificBookMode.userDefined;
      final isSystemDefined = challenge.specificBookMode == SpecificBookMode.systemDefined;

      if (isUserDefined) {
        final books = attempt.participatedBooks ?? [];
        for (final b in books) {
          final match = savedBooks.where((sb) => sb.id == b.id).toList();
          if (match.isNotEmpty) {
            bookReadPages[b.id] = match.first.pageRead;
          }
        }
      } else if (isSystemDefined) {
        final requiredIds = challenge.requiredBooks?.map((b) => b.id).toList() ?? [];

        for (final id in requiredIds) {
          final match = savedBooks.where((sb) => sb.id == id).toList();
          if (match.isNotEmpty) {
            bookReadPages[id] = match.first.pageRead;
          }
        }
      }

      record['bookReadPages'] = bookReadPages;

      final updatedAttempt = attempt.copyWith(recordData: record);
      final updatedAttempts = [
        ...challenge.attempts.sublist(0, challenge.attempts.length - 1),
        updatedAttempt,
      ];
      final updatedChallenge = challenge.copyWith(attempts: updatedAttempts);
      _allChallenges[i] = updatedChallenge;
    }

    notifyListeners();
  }

  /// ✅ 챌린지 실패 처리
  Future<void> markChallengeAsFailed(String challengeId, String userId) async {
    final index = _allChallenges.indexWhere((c) => c.id == challengeId);
    if (index == -1) return;

    final current = _allChallenges[index];
    final latestAttempt = current.attempts.isNotEmpty ? current.attempts.last : null;
    if (latestAttempt == null || latestAttempt.completed) return;

    // 이미 실패로 표시된 경우 무시
    if (latestAttempt.isSuccessful == false) return;

    // 1) latest attempt 실패 마킹
    final updatedAttempt = latestAttempt.copyWith(
      completed: true,
      isSuccessful: false,
      endDate: DateTime.now(),
    );

    final updatedAttempts = [
      ...current.attempts.sublist(0, current.attempts.length - 1),
      updatedAttempt,
    ];

    // 2) 커스텀은 실패 즉시 아카이브(+ 미참여 처리)
    if (current.isCustom) {
      final archived = current.copyWith(
        attempts: updatedAttempts,
        isCompleted: true,     // 실패도 완료 상태로 마감
        isJoined: false,
        isArchived: true,      // ✅ 핵심: 숨김 처리
      );

      _allChallenges[index] = archived;
      await saveChallengeToFirestore(userId, archived);
      notifyListeners();
      return;
    }

    // 3) 기본/시스템 챌린지는 기존 규칙 유지
    final updatedChallenge = current.copyWith(
      attempts: updatedAttempts,
      isCompleted: true,
    );

    _allChallenges[index] = updatedChallenge;
    await saveChallengeToFirestore(userId, updatedChallenge);
    notifyListeners();
  }

  /// ✅ 챌린지 포기하기 (스테이지 챌린지에서 마지막 스테이지만 제거)
  Future<void> forfeitLatestStage(String challengeId, String userId) async {
    final index = _allChallenges.indexWhere((c) => c.id == challengeId);
    if (index == -1) return;

    final current = _allChallenges[index];
    if (current.stageType != ChallengeStageType.staged) return;

    // ❗️ 스테이지가 1개뿐이면 → 완전 포기로 처리
    if (current.attempts.length <= 1) {
      await unjoinChallenge(current, userId);
      return;
    }

    final updatedAttempts = current.attempts.sublist(0, current.attempts.length - 1);

    final updated = current.copyWith(
      attempts: updatedAttempts,
      isJoined: false,
      isCompleted: false,
    );

    _allChallenges[index] = updated;
    await saveChallengeToFirestore(userId, updated);
    notifyListeners();
  }

  /// ✅ 사용자 챌린지 리셋
  Future<void> resetChallengeForUser(String challengeId, String userId) async {
    try {
      // 1. Firestore에서 삭제
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('challenges')
          .doc(challengeId)
          .delete();

      // 2. 로컬에서 제거
      _allChallenges.removeWhere((c) => c.id == challengeId);

      // 3. 기본 챌린지를 다시 불러와서 추가
      final baseJson = await rootBundle.loadString('assets/challenges.json');
      final List<dynamic> baseList = json.decode(baseJson);
      final baseChallenge = baseList
          .map((e) => Challenge.fromMap(e))
          .firstWhere((c) => c.id == challengeId);

      _allChallenges.add(baseChallenge);

      notifyListeners();
    } catch (e) {
      //debugPrint("🔥 챌린지 삭제 실패: $e");
    }
  }

  /// ✅ 사용자 커스텀 챌린지 추가 + 자동참여
  Future<void> addCustomChallenge({
    required String userId,
    required Challenge custom,
  }) async {
    final books = List<BookModel>.from(custom.participatingBooks ?? const []);

    // 화면에서 고른 기간(Challenge 객체엔 null로 저장할 거라 여기서만 사용)
    final DateTime start = custom.startDate ?? DateTime.now();
    final DateTime? endInput = custom.endDate;
    final int selectedDays = endInput != null
        ? endInput.difference(DateTime(start.year, start.month, start.day)).inDays + 1
        : 7;

    final firstAttempt = ChallengeAttempt(
      stageIndex: null,
      startDate: start,
      endDate: start.add(Duration(days: selectedDays - 1)),
      selectedDuration: selectedDays,           // ✅ 핵심
      participatedBooks: books,
      completedBookIds: const [],
    );

    final normalized = custom.copyWith(
      isCustom: true,
      category: ChallengeCategory.growth,
      method: ChallengeMethod.specificBooks,
      period: ChallengePeriod.daysBased,
      checkMode: ChallengeCheckMode.auto,
      specificBookMode: SpecificBookMode.userDefined,
      forceBookSelection: true,

      requiredBooks: books,
      participatingBooks: books,
      requiredPages: custom.requiredPages ?? 1,  // ✅ 페이지 입력 기반 강제

      isJoined: true,
      isCompleted: false,
      attempts: [firstAttempt],

      // Own This와 동일하게 챌린지 레벨 기간은 null
      startDate: null,
      endDate: null,

      durationOptions: [selectedDays],   // ✅ fallback 대비

    );

    final idx = _allChallenges.indexWhere((c) => c.id == normalized.id);
    if (idx >= 0) {
      _allChallenges[idx] = normalized;
    } else {
      _allChallenges.add(normalized);
    }

    await saveChallengeToFirestore(userId, normalized);

    try {
      await refreshChallengeStatus(
        normalized.id,
        savedBooks: _getCurrentSavedBooks(),
        userId: userId,
      );
    } catch (_) {}

    notifyListeners();
  }

  /// ✅ 사용자 커스텀 챌린지 완전 삭제
  Future<void> deleteCustomChallenge(String challengeId, String userId) async {
    // Firestore에서 제거
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('challenges')
          .doc(challengeId)
          .delete();
    } catch (_) {
      // 네트워크 이슈일 수 있으니 조용히 무시하거나 로그만 남겨도 OK
    }

    // 메모리에서도 제거
    _allChallenges.removeWhere((c) => c.id == challengeId);
    notifyListeners();
  }

  /// ✅ '포기하기' 공통 엔트리 (여기 하나만 쓰면 됨)
  Future<void> giveUpChallenge(Challenge challenge, String userId) async {
    if (challenge.isCustom == true) {
      // 🔥 사용자 커스텀은 포기 = 삭제
      await deleteCustomChallenge(challenge.id, userId);
      return;
    }

    // 기본/스테이지 챌린지는 기존 규칙 유지
    if (challenge.stageType == ChallengeStageType.staged) {
      await forfeitLatestStage(challenge.id, userId);
    } else {
      await unjoinChallenge(challenge, userId);
    }
  }

  String _normalizeTitle(String s) =>
      s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  /// 사용자의 활성(custom && !archived) 커스텀 챌린지만 중복 검사
  bool hasDuplicateCustomTitle(String title) {
    final norm = _normalizeTitle(title);
    return _allChallenges.any((c) =>
    c.isCustom && !c.isArchived && _normalizeTitle(c.title) == norm);
  }

  /// 자동 유니크 타이틀 제안
  String suggestUniqueCustomTitle(String base) {
    if (!hasDuplicateCustomTitle(base)) return base;
    int n = 2;
    while (hasDuplicateCustomTitle("$base ($n)")) {
      n++;
    }
    return "$base ($n)";
  }


}
