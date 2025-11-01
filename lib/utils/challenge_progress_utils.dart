import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/main.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/utils/book_pool_loader.dart';
import 'package:dayverse_book/model/challenge_attempt_model.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/utils/challenge_check_utils.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';

class ChallengeProgressUtils {
  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  /// ✅ 공통: 타겟 책 목록 해석 (override > participating > required)
  static List<BookModel> _resolveTargetBooks(Challenge challenge, List<BookModel>? override) {
    if (override != null && override.isNotEmpty) return override;
    if ((challenge.participatingBooks ?? []).isNotEmpty) return challenge.participatingBooks!;
    return challenge.requiredBooks ?? const [];
  }

  /// ✅ 공통: 책 식별 키 통일 (id > isbn)
  static String? _keyForBook(BookModel b) {
    if (b.id.isNotEmpty) return b.id;
    final isbn = b.isbn;
    if (isbn != null && isbn.isNotEmpty) return isbn;
    return null;
  }

  /// ✅ 챌린지 완료 여부 (override-aware)
  static bool isChallengeCompleted(
      Challenge challenge,
      dynamic recordDataOrSavedBooks, {
        List<BookModel>? targetBooksOverride,
      }) {
    final checkAction = getChallengeCheckActionType(challenge);

    // 1) 루틴형 + 스테이지형 + 타이머 기반
    if (challenge.category == ChallengeCategory.routine &&
        challenge.method == ChallengeMethod.countBased &&
        checkAction == ChallengeCheckActionType.timerAuto) {
      final attempt = challenge.attempts.isNotEmpty ? challenge.attempts.last : null;
      if (attempt == null) return false;

      final record = attempt.recordData ?? {};
      final dailyMinutes = (record['dailyMinutes'] as Map?)?.cast<String, dynamic>() ?? {};
      final requiredMinutes = challenge.requiredMinutes ?? 0;
      final selectedDuration = attempt.selectedDuration ?? 1;

      final start = DateTime(attempt.startDate.year, attempt.startDate.month, attempt.startDate.day);
      final end = start.add(Duration(days: selectedDuration - 1));

      final count = dailyMinutes.entries.where((entry) {
        final key = entry.key; // e.g. '2025-07-12'
        final minutes = int.tryParse(entry.value.toString()) ?? 0;
        try {
          final date = DateTime.parse(key);
          return !date.isBefore(start) && !date.isAfter(end) && minutes >= requiredMinutes;
        } catch (_) {
          return false;
        }
      }).length;

      final target = getTargetCount(challenge, recordDataOrSavedBooks,
          targetBooksOverride: targetBooksOverride);
      return count >= target && target > 0;
    }

    // 2) 스테이지형 성장 챌린지
    if (challenge.stageType == ChallengeStageType.staged) {
      final attempt = challenge.attempts.isNotEmpty ? challenge.attempts.last : null;
      final currentStageIndex = attempt?.stageIndex ?? 0;
      final isFinalStage = currentStageIndex >= (challenge.stageDurations?.length ?? 0) - 1;
      final isCurrentStageCompleted =
      _isCurrentStageCompleted(challenge, recordDataOrSavedBooks, targetBooksOverride: targetBooksOverride);
      return isFinalStage && isCurrentStageCompleted;
    }

    // 3) 일반 챌린지
    dynamic enriched = recordDataOrSavedBooks;

    // pageAuto 인데 savedBooks가 없다면 강제 주입
    if (checkAction == ChallengeCheckActionType.pageAuto) {
      if (enriched is Map<String, dynamic>) {
        if (enriched['savedBooks'] == null || enriched['savedBooks'] is! List<BookModel>) {
          final context = navigatorKey.currentContext;
          if (context != null) {
            final savedBooks = Provider.of<SavedBooksProvider>(context, listen: false).savedBooks;
            enriched = {
              ...enriched,
              'savedBooks': savedBooks,
            };
          }
        }
      }
    }

    final completed =
    getCompletedCount(challenge, enriched, targetBooksOverride: targetBooksOverride);
    final target =
    getTargetCount(challenge, enriched, targetBooksOverride: targetBooksOverride);
    return completed >= target && target > 0;
  }

  /// ✅ 진행률 (0.0 ~ 1.0) (override-aware)
  static double getProgress(
      Challenge challenge,
      dynamic recordDataOrSavedBooks, {
        List<BookModel>? targetBooksOverride,
      }) {
    final completed =
    getCompletedCount(challenge, recordDataOrSavedBooks, targetBooksOverride: targetBooksOverride);
    final target =
    getTargetCount(challenge, recordDataOrSavedBooks, targetBooksOverride: targetBooksOverride);
    if (target <= 0) return 0.0;
    return (completed / target).clamp(0.0, 1.0);
  }

  /// ✅ 완료 수 (override-aware)
  static int getCompletedCount(
      Challenge challenge,
      dynamic data, {
        List<BookModel>? targetBooksOverride,
      }) {
    final action = getChallengeCheckActionType(challenge);

    // 스테이지 챌린지는 현재 attempt 기준 data 갱신
    if (challenge.stageType == ChallengeStageType.staged && challenge.attempts.isNotEmpty) {
      final attempt = challenge.attempts.last;
      data = attempt.recordData ?? {};
    }

    switch (action) {
      case ChallengeCheckActionType.libraryAuto:
        {
          // 라이브러리에서 완료된 책이면서, 타겟(override/participating/required)에 포함된 것만 카운트
          List<BookModel> libBooks = const [];
          if (data is List<BookModel>) {
            libBooks = data;
          } else if (data is Map && data['savedBooks'] is List) {
            final raw = data['savedBooks'];
            libBooks = raw.map((e) {
              if (e is BookModel) return e;
              if (e is Map) return BookModel.fromMap(e.cast<String, dynamic>());
              return null;
            }).whereType<BookModel>().toList();
          }
          final targets = _resolveTargetBooks(challenge, targetBooksOverride);
          return _getQuantityBasedCompletedCountFiltered(challenge, libBooks, targets);
        }

      case ChallengeCheckActionType.pageAuto:
        {
          // 지정도서의 페이지 100% 기준 완료 권수 (타겟 목록만)
          if (data is Map) {
            final raw = data['savedBooks'];
            if (raw is List) {
              final saved = raw.map((e) {
                if (e is BookModel) return e;
                if (e is Map) return BookModel.fromMap(e.cast<String, dynamic>());
                return null;
              }).whereType<BookModel>().toList();
              final targets = _resolveTargetBooks(challenge, targetBooksOverride);
              return _getSpecificBooksPageProgressFromBooks(challenge, saved, targets);
            }
            // savedBooks가 없으면 record 기반
            final targets = _resolveTargetBooks(challenge, targetBooksOverride);
            return _getSpecificBooksPageProgressFromRecord(challenge, data.cast<String, dynamic>(), targets);
          } else if (data is List<BookModel>) {
            final targets = _resolveTargetBooks(challenge, targetBooksOverride);
            return _getSpecificBooksPageProgressFromBooks(challenge, data, targets);
          }
          return 0;
        }

      case ChallengeCheckActionType.timerAuto:
        if (data is Map<String, dynamic>) {
          return _getTimerCompletedCount(challenge, data);
        }
        return 0;

      case ChallengeCheckActionType.manual:
        if (data is Map<String, dynamic>) {
          return _getManualCompletedCount(challenge, data);
        }
        return 0;

      case ChallengeCheckActionType.none:
      default:
        return 0;
    }
  }

  /// ✅ 목표 수 (override-aware)
  static int getTargetCount(
      Challenge challenge,
      dynamic recordDataOrSavedBooks, {
        List<BookModel>? targetBooksOverride,
      }) {
    // 스테이지 챌린지: 각 스테이지의 duration을 목표로 사용
    if (challenge.stageType == ChallengeStageType.staged && challenge.attempts.isNotEmpty) {
      final attempt = challenge.attempts.last;
      final stageIndex = attempt.stageIndex ?? 0;
      if (challenge.stageDurations != null && stageIndex < challenge.stageDurations!.length) {
        return challenge.stageDurations![stageIndex];
      }
    }

    if (challenge.method == ChallengeMethod.countBased) {
      final fallback = (challenge.checkCountOptions != null && challenge.checkCountOptions!.isNotEmpty)
          ? challenge.checkCountOptions!.first
          : 1;
      final count = recordDataOrSavedBooks is Map<String, dynamic>
          ? int.tryParse(recordDataOrSavedBooks['selectedDuration']?.toString() ?? '') ?? fallback
          : fallback;
      return count;
    }

    if (challenge.method == ChallengeMethod.specificBooks) {
      final targets = _resolveTargetBooks(challenge, targetBooksOverride);

      if (challenge.specificBookMode == SpecificBookMode.systemDefined) {
        // 시스템 지정이면 풀/requiredBooks 길이가 목표
        return targets.length;
      } else {
        // 사용자 지정이면, record의 bookReadPages keys 또는 participating/targets 길이
        Map<String, dynamic> pages = {};
        if (recordDataOrSavedBooks is Map<String, dynamic>) {
          if (recordDataOrSavedBooks['bookReadPages'] is Map) {
            pages = Map<String, dynamic>.from(recordDataOrSavedBooks['bookReadPages']);
          } else if (recordDataOrSavedBooks['recordData'] is Map &&
              recordDataOrSavedBooks['recordData']['bookReadPages'] is Map) {
            pages = Map<String, dynamic>.from(recordDataOrSavedBooks['recordData']['bookReadPages']);
          }
        }
        if (pages.isNotEmpty) return pages.keys.length;
        if ((challenge.participatingBooks ?? []).isNotEmpty) return challenge.participatingBooks!.length;
        return targets.length; // 마지막 fallback: targets
      }
    }

    if (challenge.method == ChallengeMethod.quantityBased) {
      // 권수 도전은 명시 totalBooks 사용
      return challenge.totalBooks ?? 0;
    }

    return 1;
  }

  /// ✅ record 기반 pageAuto (override-aware)
  static int _getSpecificBooksPageProgressFromRecord(
      Challenge challenge,
      Map<String, dynamic> data,
      List<BookModel> targetBooks,
      ) {
    // savedBooks 있으면 books 경로로 위임 (정확도↑)
    final savedBooks = data['savedBooks'];
    if (savedBooks is List<BookModel>) {
      return _getSpecificBooksPageProgressFromBooks(challenge, savedBooks, targetBooks);
    }

    // 없으면 recordData의 readPages로 계산
    final readPages = (data['bookReadPages'] as Map?)?.cast<String, dynamic>() ?? {};
    int count = 0;
    const threshold = 1.0;

    for (final t in targetBooks) {
      final key = _keyForBook(t);
      final total = t.pageCount ?? 0;
      if (key == null || total <= 0) continue;

      final read = int.tryParse(readPages[key]?.toString() ?? '') ?? 0;
      if (read >= (total * threshold).floor()) count++;
    }
    return count;
  }

  /// ✅ books 기반 pageAuto (override-aware)
  static int _getSpecificBooksPageProgressFromBooks(
      Challenge challenge,
      List<BookModel> savedBooks,
      List<BookModel> targetBooks,
      ) {
    int count = 0;
    const threshold = 1.0;

    // savedBooks를 키 맵으로 만들어 빠르게 매칭
    final savedMap = <String, BookModel>{};
    for (final sb in savedBooks) {
      final k = _keyForBook(sb);
      if (k != null) savedMap[k] = sb;
    }

    for (final t in targetBooks) {
      final k = _keyForBook(t);
      if (k == null) continue;

      final total = (t.pageCount ?? savedMap[k]?.pageCount) ?? 0;
      final read = savedMap[k]?.pageRead ?? 0;
      if (total > 0 && read >= (total * threshold).floor()) count++;
    }
    return count;
  }

  /// ✅ override-aware: 완료된 책 id 목록
  static List<String> getCompletedBookIdsForSpecificBooks(
      Challenge challenge,
      List<BookModel> savedBooks, {
        List<BookModel>? targetBooksOverride,
      }) {
    final List<String> completedIds = [];
    const threshold = 1.0;

    final targets = _resolveTargetBooks(challenge, targetBooksOverride);

    // 빠른 조회용 맵 (키는 id>isbn)
    final savedMap = <String, BookModel>{};
    for (final sb in savedBooks) {
      final k = _keyForBook(sb);
      if (k != null) savedMap[k] = sb;
    }

    for (final t in targets) {
      final k = _keyForBook(t);
      if (k == null) continue;

      final total = (t.pageCount ?? savedMap[k]?.pageCount) ?? 0;
      final read = savedMap[k]?.pageRead ?? 0;
      if (total > 0 && read >= (total * threshold).floor()) {
        // ✅ 반환은 항상 challenge에서 쓰는 기준 id
        completedIds.add(t.id);
      }
    }
    return completedIds;
  }

  /// ✅ quantityBased: 타겟에 포함된 ‘완독(done)’만 카운트 (기간 포함)
  static int _getQuantityBasedCompletedCountFiltered(
      Challenge challenge,
      List<BookModel> savedBooks,
      List<BookModel> targetBooks,
      ) {
    final start = challenge.startDate;
    final end = challenge.endDate;

    // 타겟 키셋
    final targetKeys = targetBooks
        .map(_keyForBook)
        .whereType<String>()
        .toSet();

    return savedBooks.where((book) {
      if (book.category != 'done') return false;
      final date = book.readDate;
      if (start != null && end != null) {
        if (date == null) return false;
        if (date.isBefore(start) || date.isAfter(end)) return false;
      }
      final k = _keyForBook(book);
      // 타겟이 비어있으면 전체, 비어있지 않으면 타겟에 포함된 것만
      return targetKeys.isEmpty ? true : (k != null && targetKeys.contains(k));
    }).length;
  }

  /// ✅ timerAuto 완료 일수
  static int _getTimerCompletedCount(Challenge challenge, Map<String, dynamic> data) {
    Map<String, dynamic> rawMinutes = {};

    if (data['recordData'] is Map && data['recordData']['dailyMinutes'] is Map) {
      rawMinutes = Map<String, dynamic>.from(data['recordData']['dailyMinutes']);
    } else if (data['dailyMinutes'] is Map) {
      rawMinutes = Map<String, dynamic>.from(data['dailyMinutes']);
    }

    final required = challenge.requiredMinutes ?? 0;
    final minutesMap = rawMinutes.map((k, v) => MapEntry(k, int.tryParse(v.toString()) ?? 0));

    final attempt = challenge.attempts.isNotEmpty ? challenge.attempts.last : null;
    final startDate = attempt?.startDate;
    if (startDate == null) return 0;

    return minutesMap.entries.where((entry) {
      final parsedDate = DateTime.tryParse(entry.key);
      if (parsedDate == null) return false;
      return !parsedDate.isBefore(DateTime(startDate.year, startDate.month, startDate.day)) &&
          entry.value >= required;
    }).length;
  }

  /// ✅ manual 체크 완료
  static int _getManualCompletedCount(Challenge challenge, Map<String, dynamic> data) {
    final routine = (data['routineChecks'] as Map?)?.cast<String, bool>() ?? {};
    final count = (data['countChecks'] as Map?)?.cast<String, bool>() ?? {};
    return challenge.method == ChallengeMethod.countBased
        ? count.values.where((v) => v).length
        : routine.values.where((v) => v).length;
  }

  /// ✅ 현재 스테이지 완료 여부 (override-aware)
  static bool _isCurrentStageCompleted(
      Challenge challenge,
      dynamic recordDataOrSavedBooks, {
        List<BookModel>? targetBooksOverride,
      }) {
    final completed =
    getCompletedCount(challenge, recordDataOrSavedBooks, targetBooksOverride: targetBooksOverride);
    final target =
    getTargetCount(challenge, recordDataOrSavedBooks, targetBooksOverride: targetBooksOverride);
    return completed >= target && target > 0;
  }

  /// ✅ 남은 일수 계산
  static int calculateRemainingDays(Challenge challenge) {
    if (challenge.endDate == null) return 0;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final endDate = DateTime(
      challenge.endDate!.year,
      challenge.endDate!.month,
      challenge.endDate!.day,
    );
    final diff = endDate.difference(todayDate).inDays;
    return diff >= 0 ? diff + 1 : 0;
  }

  /// ✅ 챌린지 실패 여부 (override-aware)
  static bool isChallengeFailed(
      Challenge challenge,
      dynamic recordDataOrSavedBooks, {
        List<BookModel>? targetBooksOverride,
      }) {
    final attempt = challenge.attempts.isNotEmpty ? challenge.attempts.last : null;
    if (attempt == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (challenge.stageType == ChallengeStageType.staged) {
      final stageIndex = attempt.stageIndex ?? 0;
      final duration = (challenge.stageDurations != null && stageIndex < challenge.stageDurations!.length)
          ? challenge.stageDurations![stageIndex]
          : null;

      final startDate = attempt.startDate;
      if (startDate == null || duration == null) return false;

      final endDate = startDate.add(Duration(days: duration - 1));
      final isExpired = today.isAfter(endDate);
      final isIncomplete = !_isCurrentStageCompleted(
        challenge,
        recordDataOrSavedBooks,
        targetBooksOverride: targetBooksOverride,
      );

      return isExpired && isIncomplete;
    }

    final startDate = attempt.startDate ?? challenge.startDate;
    final endDate = challenge.endDate ??
        (challenge.period == ChallengePeriod.daysBased && attempt.selectedDuration != null
            ? startDate?.add(Duration(days: attempt.selectedDuration! - 1))
            : null);

    if (startDate == null || endDate == null) return false;

    final isExpired = today.isAfter(endDate);
    final completed =
    getCompletedCount(challenge, recordDataOrSavedBooks, targetBooksOverride: targetBooksOverride);
    final target =
    getTargetCount(challenge, recordDataOrSavedBooks, targetBooksOverride: targetBooksOverride);

    final isIncomplete = completed < target;
    return isExpired && isIncomplete;
  }
}
