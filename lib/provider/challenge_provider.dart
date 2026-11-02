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
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/service/reading_log_service.dart';
import 'package:dayverse_book/model/challenge_group_invitation_model.dart';
import 'package:dayverse_book/service/recurring_challenge_factory.dart';

class ChallengeProvider extends ChangeNotifier {
  final List<Challenge> _allChallenges = [];
  final _firestore = FirebaseFirestore.instance;

  // =====================================================
// 자동 스테이지 실패 안내
//
// 앱 초기화 중 실패가 발생해도
// ChallengeScreen에 들어왔을 때 한 번 안내할 수 있도록 유지
// =====================================================

  String? _pendingFailedStageChallengeId;
  String? _pendingFailedStageChallengeTitle;
  int? _pendingFailedStageIndex;

  bool get hasPendingStageFailure =>
      _pendingFailedStageChallengeId != null;

  /// 실패 안내 정보를 한 번 꺼내고 제거한다.
  Map<String, dynamic>? consumePendingStageFailure() {
    if (_pendingFailedStageChallengeId == null) {
      return null;
    }

    final result = <String, dynamic>{
      'challengeId':
      _pendingFailedStageChallengeId,
      'challengeTitle':
      _pendingFailedStageChallengeTitle ?? '',
      'stageIndex':
      _pendingFailedStageIndex ?? 0,
    };

    _pendingFailedStageChallengeId =
    null;
    _pendingFailedStageChallengeTitle =
    null;
    _pendingFailedStageIndex =
    null;

    return result;
  }

  List<Challenge> get allChallenges => _allChallenges;

  // 새 정기 챌린지는 저장하지 않고 메모리에 생성한다.
  // 실제 참여할 때 joinChallenge가 사용자 문서에 저장한다.
  // 기존 월/주 기록은 ID별로 그대로 유지한다.
  bool ensureRecurringChallengesCurrent({DateTime? now}) {
    final date = now ?? DateTime.now();
    // 10월은 별도로 추가한 검증용 JSON이 있으므로 중복 생성 방지.
    if (date.isBefore(DateTime(2026, 10, 26))) return false;

    final generated = RecurringChallengeFactory.current(date);
    final existingIds = _allChallenges.map((c) => c.id).toSet();
    var changed = false;
    for (final challenge in generated) {
      if (existingIds.add(challenge.id)) {
        _allChallenges.add(challenge);
        changed = true;
      }
    }
    if (changed) notifyListeners();
    return changed;
  }

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

    // ✅ 4) base에 없는 유저 기록(완료된 과거 정기 챌린지 포함)도 유지
    for (final uc in userChallengesById.values) {
      if (!baseIds.contains(uc.id)) {
        _allChallenges.add(uc);
      }
    }

    // ✅ 5) 현재 주간 1개 + 월간 2개 (이미 저장된 ID는 중복하지 않음)
    ensureRecurringChallengesCurrent();
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
    ensureRecurringChallengesCurrent();
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
      if (c.isRepeatable && c.stageType != ChallengeStageType.staged) {
        final last = c.attempts.isNotEmpty ? c.attempts.last : null;
        if (last != null && last.isCompleted) return false;
      }
      return true;
    }).toList();
  }

  /// ✅ 완료된 챌린지
  /// 가장 최근 달성한 순서로 정렬
  List<Challenge> get completedChallenges {
    final completed =
    _allChallenges.where((c) {
      if (c.isArchived) {
        return false;
      }

      if (c.stageType ==
          ChallengeStageType.staged) {
        return c.isFinalStageCompleted;
      }

      return c.attempts.any(
            (a) =>
        a.completed &&
            a.isSuccessful,
      );
    }).toList();

    // =====================================================
    // 각 챌린지의 가장 최근 성공 시각
    // =====================================================

    DateTime latestSuccessfulCompletedAt(
        Challenge challenge,
        ) {
      DateTime? latest;

      for (final attempt
      in challenge.attempts) {
        if (!attempt.completed ||
            !attempt.isSuccessful) {
          continue;
        }

        final completedAt =
            attempt.completedAt;

        if (completedAt == null) {
          continue;
        }

        if (latest == null ||
            completedAt.isAfter(latest)) {
          latest = completedAt;
        }
      }

      // completedAt이 없는 옛 데이터는 맨 뒤로
      return latest ??
          DateTime.fromMillisecondsSinceEpoch(
            0,
          );
    }

    // =====================================================
    // 최근 달성순
    // =====================================================

    completed.sort(
          (a, b) =>
          latestSuccessfulCompletedAt(b)
              .compareTo(
            latestSuccessfulCompletedAt(a),
          ),
    );

    return completed;
  }

  /// ✅ 기간 한정 챌린지가 현재 참여 가능한 기간인지 확인
  bool _isChallengeAvailableNow(
      Challenge challenge,
      ) {
    // 기간형이 아니면 날짜 제한 없음
    if (challenge.period !=
        ChallengePeriod.periodBased) {
      return true;
    }

    final now =
    DateTime.now();

    // 시작일 이전
    if (challenge.startDate != null &&
        now.isBefore(
          challenge.startDate!,
        )) {
      return false;
    }

    // 종료일 이후
    if (challenge.endDate != null &&
        now.isAfter(
          challenge.endDate!,
        )) {
      return false;
    }

    return true;
  }

  /// ✅ 아직 참여하지 않은 챌린지
  List<Challenge> get notJoinedChallenges {
    return _allChallenges.where((challenge) {
      // ✅ 아카이브된 챌린지는 모든 목록에서 제외
      if (challenge.isArchived) {
        return false;
      }

      // ✅ 사용자 커스텀 챌린지는
      // '참여하기' 목록에 노출하지 않음
      if (challenge.isCustom) {
        return false;
      }

      // ✅ 기간 한정 챌린지는
      // 시작 전 / 종료 후 참여하기 목록에서 숨김
      if (!_isChallengeAvailableNow(
        challenge,
      )) {
        return false;
      }

      // ✅ 현재 참여 중인 챌린지는 목록에서 제외
      if (challenge.isJoined) {
        return false;
      }

      final attempts =
          challenge.attempts;

      // ✅ 참여 이력이 전혀 없으면 바로 참여 가능
      if (attempts.isEmpty) {
        return true;
      }

      final isStageBased =
          challenge.stageType ==
              ChallengeStageType.staged;

      final lastAttempt =
          attempts.last;

      // ✅ 스테이지형 챌린지 처리
      if (isStageBased) {
        final totalStages =
            challenge.stageDurations.length;

        final successfulStageIndexes =
        attempts
            .where(
              (a) =>
          a.completed == true &&
              a.isSuccessful == true &&
              a.stageIndex != null,
        )
            .map(
              (a) =>
          a.stageIndex!,
        )
            .toSet();

        final completedStages =
            successfulStageIndexes.length;

        if (completedStages >=
            totalStages) {
          return false;
        }

        if (challenge.isJoined) {
          return false;
        }

        return true;
      }

      // ✅ 반복 가능한 단일 챌린지는 완료 후 다시 참여 가능
      if (challenge.isRepeatable &&
          lastAttempt.completed) {
        return true;
      }

      // ✅ 반복 불가능한 단일 챌린지는
      // 성공한 이력이 있을 때만 재참여 불가
      if (!challenge.isRepeatable &&
          attempts.any(
                (a) => a.completed && a.isSuccessful,
          )) {
        return false;
      }

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
            (updatedAttempts.last.startDate != null &&
                (isStaged ||
                    updatedAttempts.last.completed));

    if (shouldCreateNewAttempt) {
      int? currentStageIndex;

      if (isStaged) {
        final successfulStageIndexes = challenge.attempts
            .where((a) =>
        a.completed == true &&
            a.isSuccessful == true &&
            a.stageIndex != null)
            .map((a) => a.stageIndex!)
            .toSet();

        final maxIndex = challenge.stageDurations.length - 1;
        currentStageIndex = successfulStageIndexes.length.clamp(0, maxIndex);
      }

      final int? resolvedDuration =
      isStaged && currentStageIndex != null
          ? challenge.stageDurations[currentStageIndex]
          : duration;

      DateTime? attemptEndDate;

      if (challenge.period == ChallengePeriod.periodBased) {
        attemptEndDate = challenge.endDate;
      } else if (challenge.period == ChallengePeriod.daysBased &&
          resolvedDuration != null &&
          resolvedDuration > 0) {
        final startDay = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        );

        attemptEndDate = startDay.add(
          Duration(days: resolvedDuration - 1),
        );
      }

      final isRecurring = challenge.imageUrl == 'recurring://weekly' ||
          challenge.imageUrl == 'recurring://monthly';
      final newAttempt = ChallengeAttempt(
        stageIndex: currentStageIndex,
        // 정기 챌린지는 참여일이 아닌 정해진 기간 처음부터 집계
        startDate: isRecurring ? (challenge.startDate ?? startDate) : startDate,
        endDate: attemptEndDate,
        selectedDuration: resolvedDuration,
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

    // 기간 누적시간 챌린지는 참여 전에 읽은 이번 주 기록도 즉시 불러온다.
    if (updated.method == ChallengeMethod.timeBased &&
        updated.checkMode == ChallengeCheckMode.auto) {
      await refreshChallengeStatus(
        updated.id,
        savedBooks: _getCurrentSavedBooks(),
        userId: userId,
        notify: false,
      );
    }
    notifyListeners();
  }

  /// ✅ 친구 초대를 통한 챌린지 참여
  ///
  /// - 시스템 챌린지: 현재 사용자의 기존 Challenge를 기반으로 참여
  /// - 커스텀 챌린지: 초대한 사용자의 Challenge 정의를
  ///   현재 사용자에게 복제한 뒤 참여
  ///
  /// 초대한 사람과 동일한:
  /// - 시작일
  /// - 기간
  /// - 선택 도서
  ///
  /// 를 사용한다.
  ///
  /// 스테이지 챌린지는 현재 함께 도전 미지원.
  Future<Challenge> joinChallengeFromInvitation({
    required Challenge challenge,
    required ChallengeGroupInvitationModel invitation,
    required String userId,
  }) async {
    if (challenge.stageType ==
        ChallengeStageType.staged) {
      throw StateError(
        '스테이지 챌린지는 친구와 함께 도전할 수 없습니다.',
      );
    }

    if (challenge.id !=
        invitation.challengeId) {
      throw StateError(
        '챌린지 초대 정보가 일치하지 않습니다.',
      );
    }

    // =====================================================
    // 1. 현재 사용자에게 이미 존재하는 Challenge 확인
    // =====================================================

    final existingIndex =
    _allChallenges.indexWhere(
          (c) => c.id == challenge.id,
    );

    Challenge baseChallenge;

    if (existingIndex >= 0) {
      // 시스템 챌린지거나
      // 이미 현재 사용자에게 저장되어 있는 챌린지
      baseChallenge =
      _allChallenges[existingIndex];

      // 이미 진행 중인 동일 챌린지가 있으면
      // 초대 설정으로 덮어쓰지 않는다.
      if (baseChallenge.isJoined &&
          baseChallenge.attempts.isNotEmpty &&
          !baseChallenge.attempts.last.completed) {
        throw StateError(
          '이미 진행 중인 챌린지입니다.',
        );
      }
    } else {
      // =====================================================
      // 2. 커스텀 챌린지
      //
      // 초대한 사람의 Challenge 정의만 복사하고
      // 그 사람의 참여 기록(attempts)은 절대 복사하지 않는다.
      // =====================================================

      final baseMap =
      Map<String, dynamic>.from(
        challenge.toMap(),
      );

      baseMap['attempts'] =
      <Map<String, dynamic>>[];

      baseMap['isJoined'] =
      false;

      baseMap['isCompleted'] =
      false;

      baseMap['isArchived'] =
      false;

      baseMap['participatingBooks'] =
          invitation.participatingBooks
              .map(
                (book) => book.toMap(),
          )
              .toList();

      baseChallenge =
          Challenge.fromMap(
            baseMap,
          );
    }

    // =====================================================
    // 3. 초대 설정으로 현재 사용자의 새 Attempt 생성
    // =====================================================

    final List<BookModel>?
    participatingBooks =
    baseChallenge.method ==
        ChallengeMethod.specificBooks &&
        baseChallenge.specificBookMode ==
            SpecificBookMode.userDefined
        ? List<BookModel>.from(
      invitation.participatingBooks,
    )
        : null;

    final newAttempt =
    ChallengeAttempt(
      stageIndex:
      null,

      startDate:
      invitation.startDate,

      // 초대 그룹에 저장된 endDate를 그대로 사용
      endDate:
      invitation.endDate,

      selectedDuration:
      invitation.selectedDuration,

      participatedBooks:
      participatingBooks,

      completedBookIds:
      const [],
    );

    // =====================================================
    // 4. 기존 이력은 현재 사용자의 것만 유지
    // =====================================================

    final updatedAttempts =
    <ChallengeAttempt>[
      ...baseChallenge.attempts,
      newAttempt,
    ];

    final updatedChallenge =
    baseChallenge.copyWith(
      isJoined:
      true,

      isCompleted:
      false,

      attempts:
      updatedAttempts,

      participatingBooks:
      participatingBooks,
    );

    // =====================================================
    // 5. Provider에 등록 또는 교체
    // =====================================================

    if (existingIndex >= 0) {
      _allChallenges[existingIndex] =
          updatedChallenge;
    } else {
      // 커스텀 챌린지는 상대방에게 처음 생기는 것
      _allChallenges.add(
        updatedChallenge,
      );
    }

    // =====================================================
    // 6. 현재 사용자 Firestore에 저장
    // =====================================================

    await saveChallengeToFirestore(
      userId,
      updatedChallenge,
    );

    if (updatedChallenge.method == ChallengeMethod.timeBased &&
        updatedChallenge.checkMode == ChallengeCheckMode.auto) {
      await refreshChallengeStatus(
        updatedChallenge.id,
        savedBooks: _getCurrentSavedBooks(),
        userId: userId,
        notify: false,
      );
    }
    notifyListeners();

    return _allChallenges.firstWhere((c) => c.id == updatedChallenge.id);
  }

  /// ✅ 챌린지 포기
  Future<void> unjoinChallenge(Challenge challenge, String userId) async {
    final index = _allChallenges.indexWhere((c) => c.id == challenge.id);
    if (index == -1) return;

    final attempts = [...challenge.attempts];

    if (attempts.isNotEmpty) {
      final last = attempts.last;

      // 진행 중 attempt만 실패 처리
      if (!last.completed) {
        attempts[attempts.length - 1] = last.copyWith(
          completed: true,
          isSuccessful: false,
          endDate: DateTime.now(),
        );
      }
    }

    final updated = challenge.copyWith(
      isJoined: false,
      isCompleted: attempts.any((a) => a.completed && a.isSuccessful),
      attempts: attempts,
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
    if (current.isCompleted) return null;

    final successfulStageIndexes = current.attempts
        .where((a) =>
    a.completed == true &&
        a.isSuccessful == true &&
        a.stageIndex != null)
        .map((a) => a.stageIndex!)
        .toSet();
    final nextStageIndex = successfulStageIndexes.length;

    if (nextStageIndex >= current.stageDurations.length) return null;

    final alreadyExists = current.attempts.any(
          (a) => (a.stageIndex ?? -1) == nextStageIndex,
    );
    if (alreadyExists) return null;

    final nextAttempt = ChallengeAttempt(
      stageIndex: nextStageIndex,
      selectedDuration: current.stageDurations[nextStageIndex],
      startDate: DateTime.now(),
      completedBookIds: const [],
    );

    return current.copyWith(
      isJoined: true,
      isCompleted: false,
      attempts: [
        ...current.attempts,
        nextAttempt,
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
    if (challenge.method == ChallengeMethod.timeBased) {
      return challenge.requiredMinutes ?? 0;
    }
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
        case ChallengeMethod.timeBased:
          return challenge.requiredMinutes ?? 0;
      }
    }

    return 0;
  }

  /// ✅ 10 Minutes Habit
  /// 현재 스테이지에서 이미 지나간 날짜 중
  /// 하루라도 필수 독서시간을 채우지 못했는지 확인
  Future<bool> _hasFailedDaily10MinStage(
      Challenge challenge,
      ChallengeAttempt attempt,
      ) async {
    // 이 챌린지에만 적용
    if (challenge.id !=
        'daily_10min_habit') {
      return false;
    }

    if (challenge.stageType !=
        ChallengeStageType.staged) {
      return false;
    }

    if (!challenge.isJoined) {
      return false;
    }

    if (attempt.completed) {
      return false;
    }

    final requiredMinutes =
        challenge.requiredMinutes ?? 0;

    if (requiredMinutes <= 0) {
      return false;
    }

    // 현재 스테이지의 기간
    int? stageDuration =
        attempt.selectedDuration;

    if (stageDuration == null ||
        stageDuration <= 0) {
      final stageIndex =
          attempt.stageIndex;

      if (stageIndex != null &&
          stageIndex >= 0 &&
          stageIndex <
              challenge.stageDurations.length) {
        stageDuration =
        challenge.stageDurations[
        stageIndex
        ];
      }
    }

    if (stageDuration == null ||
        stageDuration <= 0) {
      return false;
    }

    // 시간 제거 → 날짜 단위로 비교
    final startDay =
    DateTime(
      attempt.startDate.year,
      attempt.startDate.month,
      attempt.startDate.day,
    );

    final now =
    DateTime.now();

    final today =
    DateTime(
      now.year,
      now.month,
      now.day,
    );

    // 시작 당일에는 아직 하루가 끝나지 않았으므로
    // 실패 판정하지 않는다.
    if (!today.isAfter(
      startDay,
    )) {
      return false;
    }

    final yesterday =
    today.subtract(
      const Duration(days: 1),
    );

    // 현재 스테이지의 마지막 날짜
    final stageLastDay =
    startDay.add(
      Duration(
        days: stageDuration - 1,
      ),
    );

    // 어제와 스테이지 마지막 날 중
    // 더 이른 날짜까지만 검사
    final lastDayToCheck =
    yesterday.isBefore(
      stageLastDay,
    )
        ? yesterday
        : stageLastDay;

    // 실제 Firestore 독서 타이머 기록 기준
    final dailyMinutes =
    await ReadingLogService
        .getTotalReadingMinutesByDate();

    DateTime cursor =
        startDay;

    while (!cursor.isAfter(
      lastDayToCheck,
    )) {
      final key =
          '${cursor.year}-'
          '${cursor.month.toString().padLeft(2, '0')}-'
          '${cursor.day.toString().padLeft(2, '0')}';

      final minutes =
          dailyMinutes[key] ?? 0;

      debugPrint(
        '📅 10 Minutes Habit 검사: '
            'date=$key, '
            'minutes=$minutes, '
            'required=$requiredMinutes',
      );

      // 지나간 하루라도 10분 미만이면
      // 현재 스테이지 실패
      if (minutes <
          requiredMinutes) {
        debugPrint(
          '❌ 10 Minutes Habit 스테이지 실패: '
              'stageIndex=${attempt.stageIndex}, '
              'failedDate=$key, '
              'minutes=$minutes',
        );

        return true;
      }

      cursor =
          cursor.add(
            const Duration(days: 1),
          );
    }

    return false;
  }

  /// ✅ 챌린지 상태 갱신
  ///
  /// - 실제 상태가 변경된 경우에만 Firestore 저장
  /// - [todayMinutesOverride]가 전달되면
  ///   timerAuto 챌린지마다 독서 로그를 다시 조회하지 않음
  /// - [notify]가 false이면 개별 갱신마다 notifyListeners 하지 않음
  Future<void> refreshChallengeStatus(
      String challengeId, {
        required List<BookModel> savedBooks,
        required String userId,
        int? todayMinutesOverride,
        bool notify = true,
      }) async {
    final index = _allChallenges.indexWhere(
          (c) => c.id == challengeId,
    );

    if (index == -1) return;

    final challenge = _allChallenges[index];

    final latestAttempt =
    challenge.attempts.isNotEmpty
        ? challenge.attempts.last
        : null;

    if (latestAttempt == null || !challenge.isJoined) {
      return;
    }

    // ✅ 완료된 Attempt는 진행률 재갱신 방지
    if (latestAttempt.completed) {
      return;
    }

    // 신규 누적시간 방식은 참여 중인 챌린지만 업데이트한다.
    if (challenge.method == ChallengeMethod.timeBased &&
        !challenge.isJoined) {
      return;
    }

// =====================================================
// 10 Minutes Habit
//
// 이미 완전히 지나간 날짜 중
// 하루라도 10분을 채우지 못했다면
// 현재 스테이지만 실패 처리
// =====================================================

    if (challenge.id ==
        'daily_10min_habit' &&
        challenge.stageType ==
            ChallengeStageType.staged &&
        challenge.isJoined &&
        !latestAttempt.completed) {
      final hasFailedStage =
      await _hasFailedDaily10MinStage(
        challenge,
        latestAttempt,
      );

      if (hasFailedStage) {
        // 실패 처리 전에 현재 스테이지 정보를 기억
        _pendingFailedStageChallengeId =
            challenge.id;

        _pendingFailedStageChallengeTitle =
            challenge.title;

        _pendingFailedStageIndex =
            latestAttempt.stageIndex ?? 0;

        await markChallengeAsFailed(
          challenge.id,
          userId,
        );

        // 현재 Attempt는 실패 처리되며 제거되므로
        // 여기서 반드시 종료
        return;
      }
    }

    final target =
    getTargetCount(
      challenge,
    );

    if (target <= 0) {
      return;
    }

    ChallengeAttempt updatedAttempt =
        latestAttempt;

    bool hasChanged = false;

    // =====================================================
    // 특정 책 기반
    // =====================================================

    if (challenge.method ==
        ChallengeMethod.specificBooks) {
      final checkAction =
      getChallengeCheckActionType(
        challenge,
      );

      if (checkAction ==
          ChallengeCheckActionType.pageAuto) {
        final record = {
          ...(latestAttempt.recordData ?? {}),
          'savedBooks': savedBooks,
        };

        final completedIds =
        ChallengeProgressUtils
            .getCompletedBookIdsForSpecificBooks(
          challenge,
          savedBooks,
        );

        if (!_sameStringList(
          latestAttempt.completedBookIds,
          completedIds,
        )) {
          updatedAttempt =
              updatedAttempt.copyWith(
                completedBookIds: completedIds,
              );

          hasChanged = true;
        }
      } else {
        final requiredIds =
            challenge.requiredBooks
                ?.map((b) => b.id)
                .toSet() ??
                <String>{};

        final completedIds = savedBooks
            .where(
              (b) =>
          requiredIds.contains(b.id) &&
              b.endDate != null,
        )
            .map((b) => b.id)
            .toList();

        if (!_sameStringList(
          latestAttempt.completedBookIds,
          completedIds,
        )) {
          updatedAttempt =
              updatedAttempt.copyWith(
                completedBookIds: completedIds,
              );

          hasChanged = true;
        }
      }
    }

    // =====================================================
    // 완독 권수 기반
    // =====================================================

    else if (challenge.method ==
        ChallengeMethod.quantityBased) {
      final completedBooks = savedBooks
          .where(
            (b) => b.endDate != null,
      )
          .toList();

      List<String> completedIds;

      if (challenge.period ==
          ChallengePeriod.periodBased &&
          challenge.startDate != null &&
          challenge.endDate != null) {
        completedIds = completedBooks
            .where((b) {
          final date = b.endDate!;

          return date.isAfter(
            challenge.startDate!.subtract(
              const Duration(days: 1),
            ),
          ) &&
              date.isBefore(
                challenge.endDate!.add(
                  const Duration(days: 1),
                ),
              );
        })
            .map((b) => b.id)
            .toList();
      } else {
        completedIds =
            completedBooks.map((b) => b.id).toList();
      }

      if (!_sameStringList(
        latestAttempt.completedBookIds,
        completedIds,
      )) {
        updatedAttempt =
            updatedAttempt.copyWith(
              completedBookIds: completedIds,
            );

        hasChanged = true;
      }
    }

    // =====================================================
    // 기간 누적 독서시간: 주간 시작일부터 모든 타이머 기록 인정
    // =====================================================
    else if (challenge.method == ChallengeMethod.timeBased &&
        challenge.checkMode == ChallengeCheckMode.auto) {
      final sourceMinutes = await ReadingLogService.getTotalReadingMinutesByDate();
      final recordData = Map<String, dynamic>.from(latestAttempt.recordData ?? {});
      final dailyMap = <String, dynamic>{};
      // 주간 해당 날짜만 저장해 Firestore 문서가 불필요하게 커지지 않도록 한다.
      final from = challenge.startDate ?? latestAttempt.startDate;
      final to = challenge.endDate ?? latestAttempt.endDate;
      for (final entry in sourceMinutes.entries) {
        final date = DateTime.tryParse(entry.key);
        if (date == null || to == null) continue;
        final day = DateTime(date.year, date.month, date.day);
        if (day.isBefore(DateTime(from.year, from.month, from.day)) ||
            day.isAfter(DateTime(to.year, to.month, to.day))) continue;
        dailyMap[entry.key] = entry.value;
      }
      final oldMap = Map<String, dynamic>.from(
        (recordData['dailyMinutes'] as Map?) ?? {},
      );
      if (!mapEquals(oldMap, dailyMap)) {
        recordData['dailyMinutes'] = dailyMap;
        updatedAttempt = updatedAttempt.copyWith(recordData: recordData);
        hasChanged = true;
      }
    }

    // =====================================================
    // 횟수 / 루틴 기반
    // =====================================================

    else if (challenge.method ==
        ChallengeMethod.countBased) {
      final checkAction =
      getChallengeCheckActionType(
        challenge,
      );

      if (challenge.category ==
          ChallengeCategory.routine &&
          checkAction ==
              ChallengeCheckActionType.timerAuto) {
        final recordData =
        Map<String, dynamic>.from(
          latestAttempt.recordData ?? {},
        );

        final dailyMap =
        Map<String, dynamic>.from(
          (recordData['dailyMinutes'] as Map?) ??
              {},
        );

        final now = DateTime.now();

        final todayKey =
            '${now.year}-'
            '${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}';

        // refreshAllStatuses()에서 한 번 조회한 값을 재사용.
        // 개별 호출일 경우에만 직접 조회.
        final todayMinutes =
            todayMinutesOverride ??
                await ReadingLogService
                    .getTodayTotalMinutes();

        final previousTodayMinutes =
            (dailyMap[todayKey] as num?)
                ?.toInt() ??
                0;

        if (previousTodayMinutes !=
            todayMinutes) {
          dailyMap[todayKey] =
              todayMinutes;

          recordData['dailyMinutes'] =
              dailyMap;

          updatedAttempt =
              updatedAttempt.copyWith(
                recordData: recordData,
              );

          hasChanged = true;
        }
      }

      // 다른 timerAuto / 수동 countBased는
      // 여기서 변경할 데이터가 없으므로 저장하지 않는다.
    }

    // =====================================================
    // 변경 없으면 여기서 종료
    // =====================================================

    if (!hasChanged) {
      // 기존 저장된 시간/권수만으로 이미 목표를 채운 경우도 완료 반영.
      if (challenge.isJoined &&
          (challenge.method == ChallengeMethod.timeBased ||
              challenge.method == ChallengeMethod.quantityBased) &&
          !_isExpiredAttempt(latestAttempt, challenge: challenge) &&
          ChallengeProgressUtils.isChallengeCompleted(
            challenge,
            challenge.method == ChallengeMethod.timeBased
                ? (latestAttempt.recordData ?? <String, dynamic>{})
                : savedBooks,
          )) {
        await markChallengeAsCompleted(challenge.id, userId);
      }
      return;
    }

    final updatedChallenge =
    challenge.copyWith(
      attempts: [
        ...challenge.attempts.sublist(
          0,
          challenge.attempts.length - 1,
        ),
        updatedAttempt,
      ],
      isCompleted:
      challenge.isCompleted,
    );

    _allChallenges[index] =
        updatedChallenge;

    await saveChallengeToFirestore(
      userId,
      updatedChallenge,
    );

    // 누적 시간 또는 월간 권수 목표 달성 시 자동 완료.
    if (updatedChallenge.isJoined &&
        (updatedChallenge.method == ChallengeMethod.timeBased ||
            updatedChallenge.method == ChallengeMethod.quantityBased) &&
        !_isExpiredAttempt(updatedAttempt, challenge: updatedChallenge) &&
        ChallengeProgressUtils.isChallengeCompleted(
          updatedChallenge,
          updatedChallenge.method == ChallengeMethod.timeBased
              ? (updatedAttempt.recordData ?? <String, dynamic>{})
              : savedBooks,
        )) {
      await markChallengeAsCompleted(updatedChallenge.id, userId);
      return;
    }
    if (notify) notifyListeners();
  }

  bool _sameStringList(
      List<String> a,
      List<String> b,
      ) {
    if (a.length != b.length) {
      return false;
    }

    return setEquals(
      a.toSet(),
      b.toSet(),
    );
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

  /// ✅ 모든 챌린지 상태 일괄 갱신
  Future<void> refreshAllStatuses({
    required List<BookModel> savedBooks,
    required String userId,
  }) async {
    // 새 주/달에 앱을 계속 켜둔 경우, 다음 갱신 시 자동 추가
    ensureRecurringChallengesCurrent();
    // =====================================================
    // timerAuto 루틴이 실제로 존재하는지 먼저 확인
    // =====================================================

    final needsTodayMinutes =
    _allChallenges.any((challenge) {
      if (challenge.attempts.isEmpty) {
        return false;
      }

      if (challenge.category !=
          ChallengeCategory.routine) {
        return false;
      }

      if (challenge.method !=
          ChallengeMethod.countBased) {
        return false;
      }

      return getChallengeCheckActionType(
        challenge,
      ) ==
          ChallengeCheckActionType.timerAuto;
    });

    // =====================================================
    // 오늘 독서시간은 최대 한 번만 조회
    // =====================================================

    int? todayMinutes;

    if (needsTodayMinutes) {
      todayMinutes =
      await ReadingLogService
          .getTodayTotalMinutes();
    }

    // =====================================================
    // 개별 challenge 갱신
    //
    // 개별 notify는 막고 마지막에 한 번만 notify
    // =====================================================

    for (final challenge
    in List<Challenge>.from(
      _allChallenges,
    )) {
      await refreshChallengeStatus(
        challenge.id,
        savedBooks: savedBooks,
        userId: userId,
        todayMinutesOverride:
        todayMinutes,
        notify: false,
      );
    }

    // =====================================================
    // 기한 만료 처리
    // =====================================================

    await sweepAndFailExpired(
      userId: userId,
    );

    // 화면 갱신도 마지막에 한 번
    notifyListeners();
  }

  /// ✅ 챌린지 완료 처리 (다음 스테이지 자동참여 제거)
  Future<void> markChallengeAsCompleted(String challengeId, String userId) async {
    final index = _allChallenges.indexWhere((c) => c.id == challengeId);
    if (index == -1) return;

    final current = _allChallenges[index];
    final latestAttempt = current.attempts.isNotEmpty ? current.attempts.last : null;
    if (latestAttempt == null || latestAttempt.completed) return;

    // ✅ 기간이 만료된 단일 챌린지는 성공 처리 불가
    if (!current.isCustom &&
        current.stageType == ChallengeStageType.single &&
        (current.period == ChallengePeriod.daysBased ||
            current.period == ChallengePeriod.periodBased) &&
        _isExpiredAttempt(
          latestAttempt,
          challenge: current,
        )) {
      await markChallengeAsFailed(
        challengeId,
        userId,
      );
      return;
    }

    final updatedAttempt = latestAttempt.copyWith(
      completed: true,
      isSuccessful: true,
      completedAt: latestAttempt.completedAt ?? DateTime.now(),
    );

    final updatedAttempts = [
      ...current.attempts.sublist(0, current.attempts.length - 1),
      updatedAttempt,
    ];

    bool isCompleted = false;
    bool isJoined = false;

    if (current.stageType == ChallengeStageType.staged) {
      final totalStages = current.stageDurations.length;
      final successfulStageIndexes = updatedAttempts
          .where((a) =>
      a.completed == true &&
          a.isSuccessful == true &&
          a.stageIndex != null)
          .map((a) => a.stageIndex!)
          .toSet();

      isCompleted = successfulStageIndexes.length >= totalStages;

      // ✅ 중요:
      // 스테이지 챌린지는 현재 스테이지 완료 후 자동 참여되면 안 되므로
      // 마지막 스테이지 완료 여부와 상관없이 일단 joined=false
      isJoined = false;
    } else {
      isCompleted = updatedAttempts.any((a) => a.completed && a.isSuccessful);      isJoined = false;
    }

    final updatedChallenge = current.copyWith(
      attempts: updatedAttempts,
      isCompleted: isCompleted,
      isJoined: isJoined,
    );

    _allChallenges[index] = updatedChallenge;
    await saveChallengeToFirestore(userId, updatedChallenge);
    notifyListeners();
  }

  bool _isExpiredAttempt(
      ChallengeAttempt attempt, {
        Challenge? challenge,
      }) {
    DateTime? endDate = attempt.endDate;

    // 기존 daysBased 참여 기록 중
    // endDate가 저장되지 않은 경우 보완
    if (endDate == null &&
        challenge != null &&
        challenge.period == ChallengePeriod.daysBased) {
      int? duration = attempt.selectedDuration;

      // 기존 기록에 선택 기간도 없다면
      // 단일 선택 기간에 한해 설정값 사용
      final durationOptions = challenge.durationOptions;

      if ((duration == null || duration <= 0) &&
          durationOptions != null &&
          durationOptions.length == 1) {
        duration = durationOptions.first;
      }

      if (duration != null && duration > 0) {
        final startDay = DateTime(
          attempt.startDate.year,
          attempt.startDate.month,
          attempt.startDate.day,
        );

        endDate = startDay.add(
          Duration(days: duration - 1),
        );
      }
    }

    if (endDate == null) {
      return false;
    }

    final now = DateTime.now();

    // 도전 마지막 날 23:59:59.999까지 허용
    final expiryBoundary = DateTime(
      endDate.year,
      endDate.month,
      endDate.day + 1,
    );

    return !now.isBefore(expiryBoundary);
  }

  /// ✅ 기한이 지난 챌린지 자동 실패 처리
  ///
  /// 처리 대상:
  /// - 사용자 커스텀 챌린지
  /// - periodBased 기본 챌린지
  /// - daysBased 단일 기본 챌린지
  ///
  /// 스테이지 챌린지는 기존 실패 처리 방식 유지
  /// 이미 완료된 Attempt는 다시 처리하지 않음
  Future<void> sweepAndFailExpired({
    required String userId,
  }) async {
    final challenges = List<Challenge>.from(
      _allChallenges,
    );

    for (final challenge in challenges) {
      if (challenge.isArchived) {
        continue;
      }

      if (!challenge.isJoined) {
        continue;
      }

      if (challenge.attempts.isEmpty) {
        continue;
      }

      final lastAttempt = challenge.attempts.last;

      // 이미 성공 또는 실패로 종료된 기록 제외
      if (lastAttempt.completed) {
        continue;
      }

      // ==============================================
      // 커스텀 챌린지
      // ==============================================
      if (challenge.isCustom) {
        if (_isExpiredAttempt(
          lastAttempt,
          challenge: challenge,
        )) {
          await markChallengeAsFailed(
            challenge.id,
            userId,
          );
        }

        continue;
      }

      // ==============================================
      // 스테이지 챌린지는 기존 처리 유지
      // ==============================================
      if (challenge.stageType ==
          ChallengeStageType.staged) {
        continue;
      }

      // ==============================================
      // 기본 단일 챌린지
      // periodBased / daysBased
      // ==============================================
      final shouldCheckExpiry =
          challenge.period == ChallengePeriod.periodBased ||
              challenge.period == ChallengePeriod.daysBased;

      if (!shouldCheckExpiry) {
        continue;
      }

      if (_isExpiredAttempt(
        lastAttempt,
        challenge: challenge,
      )) {
        await markChallengeAsFailed(
          challenge.id,
          userId,
        );
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

  Future<void> initialize(
      User user,
      List<BookModel> books,
      ) async {
    await loadChallengesFromFirestore(
      user.uid,
    );

    await refreshAllStatuses(
      savedBooks: books,
      userId: user.uid,
    );
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

    // 커스텀 챌린지는 기존 규칙 유지
    if (current.isCustom) {
      final failedAttempt = latestAttempt.copyWith(
        completed: true,
        isSuccessful: false,
        endDate: DateTime.now(),
      );

      final updatedAttempts = [
        ...current.attempts.sublist(0, current.attempts.length - 1),
        failedAttempt,
      ];

      final archived = current.copyWith(
        attempts: updatedAttempts,
        isCompleted: true,
        isJoined: false,
        isArchived: true,
      );

      _allChallenges[index] = archived;
      await saveChallengeToFirestore(userId, archived);
      notifyListeners();
      return;
    }

    // ✅ 스테이지 챌린지는 "직전 스테이지 유지"가 핵심
    if (current.stageType == ChallengeStageType.staged) {
      // 마지막(실패한) attempt 제거
      final rolledBackAttempts =
      current.attempts.sublist(0, current.attempts.length - 1);

      // 직전 스테이지가 남아 있으면 그 상태로 복귀, 없으면 초기 상태
      final updatedChallenge = current.copyWith(
        attempts: rolledBackAttempts,
        isJoined: false,
        isCompleted: false,
      );

      _allChallenges[index] = updatedChallenge;
      await saveChallengeToFirestore(userId, updatedChallenge);
      notifyListeners();
      return;
    }

    // 일반 단일 챌린지는 기존 실패 마감 구조 유지
    final failedAttempt = latestAttempt.copyWith(
      completed: true,
      isSuccessful: false,
      endDate: DateTime.now(),
    );

    final updatedAttempts = [
      ...current.attempts.sublist(0, current.attempts.length - 1),
      failedAttempt,
    ];

    final updatedChallenge = current.copyWith(
      attempts: updatedAttempts,
      isCompleted: true,
      isJoined: false,
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

  /// 로그아웃 시 메모리에 남아 있는 이전 계정의 챌린지 데이터만 제거
  void clearLocalData() {
    _allChallenges.clear();
    notifyListeners();
  }
}
