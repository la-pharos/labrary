import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/main.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/challenge_attempt_model.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/utils/challenge_check_utils.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';

class ChallengeProgressUtils {
  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  /// ✅ 챌린지 완료 여부
  static bool isChallengeCompleted(Challenge challenge, dynamic recordDataOrSavedBooks) {
    final checkAction = getChallengeCheckActionType(challenge);
    //debugPrint("[CHECK ✅] isChallengeCompleted() 호출: ${challenge.id}");
    //debugPrint("├─ checkAction: $checkAction");
    //debugPrint("├─ category: ${challenge.category}, method: ${challenge.method}, stageType: ${challenge.stageType}");

    // 1. ✅ 루틴형 + 스테이지형 + 타이머 기반 (5번 챌린지)
    if (challenge.category == ChallengeCategory.routine &&
        challenge.method == ChallengeMethod.countBased &&
        checkAction == ChallengeCheckActionType.timerAuto) {
      final attempt = challenge.attempts.isNotEmpty ? challenge.attempts.last : null;
      if (attempt == null) {
        //debugPrint("❌ [완료 판정 실패] attempt 없음");
        return false;
      }

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
          final date = DateTime.parse(key); // 정확히 yyyy-MM-dd 포맷으로 parsing
          return !date.isBefore(start) &&
              !date.isAfter(end) &&
              minutes >= requiredMinutes;
        } catch (e) {
          //debugPrint("❌ 날짜 파싱 실패: $key");
          return false;
        }
      }).length;

      final target = getTargetCount(challenge, recordDataOrSavedBooks);
      //debugPrint("✅ [루틴형 타이머] $count / $target");
      return count >= target && target > 0;
    }

    // 2. ✅ 스테이지형 성장 챌린지 (4번)
    if (challenge.stageType == ChallengeStageType.staged) {
      final attempt = challenge.attempts.isNotEmpty ? challenge.attempts.last : null;
      final currentStageIndex = attempt?.stageIndex ?? 0;
      final isFinalStage = currentStageIndex >= (challenge.stageDurations?.length ?? 0) - 1;
      final isCurrentStageCompleted = _isCurrentStageCompleted(challenge, recordDataOrSavedBooks);

      //debugPrint("✅ [스테이지형] currentStage: $currentStageIndex, final: $isFinalStage, complete: $isCurrentStageCompleted");
      return isFinalStage && isCurrentStageCompleted;
    }

    // 3. ✅ 일반 챌린지 (1, 2, 3번)
    dynamic enriched = recordDataOrSavedBooks;

    // isChallengeCompleted 내부
    //debugPrint("📥 [isChallengeCompleted] 전달된 recordDataOrSavedBooks: ${recordDataOrSavedBooks.runtimeType}");
    if (recordDataOrSavedBooks is Map) {
      //debugPrint("📥 Map keys: ${(recordDataOrSavedBooks as Map).keys.toList()}");
    }

    // 3-1. pageAuto 인데 savedBooks가 없다면 무조건 넣어줌 (ChallengeDetailScreen → ChallengeOngoingScreen → utils 일관 보장)
    if (checkAction == ChallengeCheckActionType.pageAuto) {
      if (enriched is Map<String, dynamic>) {
        if (enriched['savedBooks'] == null || enriched['savedBooks'] is! List<BookModel>) {
          //debugPrint("⚠️ [pageAuto] savedBooks 누락됨 → 강제로 넣음");
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
    //debugPrint("📥 [isChallengeCompleted] 전달된 recordDataOrSavedBooks: ${recordDataOrSavedBooks.runtimeType}");

    // 4. ✅ 완료 수 계산
    final completed = getCompletedCount(challenge, enriched);
    final target = getTargetCount(challenge, enriched);

    //debugPrint("✅ [일반 챌린지 완료 확인] completed: $completed / $target");
    return completed >= target && target > 0;
  }

  /// ✅ 진행률 (0.0 ~ 1.0)
  static double getProgress(Challenge challenge, dynamic recordDataOrSavedBooks) {
    final completed = getCompletedCount(challenge, recordDataOrSavedBooks);
    final target = getTargetCount(challenge, recordDataOrSavedBooks);
    if (target <= 0) return 0.0;
    return (completed / target).clamp(0.0, 1.0);
  }

  /// ✅ 완료 수
  static int getCompletedCount(Challenge challenge, dynamic data) {
    final action = getChallengeCheckActionType(challenge);
    //debugPrint("📊 getCompletedCount() 호출 → action: $action, dataType: ${data.runtimeType}");

    // ✅ 스테이지 챌린지일 경우 현재 attempt 기준으로 data 갱신
    if (challenge.stageType == ChallengeStageType.staged && challenge.attempts.isNotEmpty) {
      final attempt = challenge.attempts.last;
      data = attempt.recordData ?? {};
    }

    if (data is Map) {
      //debugPrint("📊 getCompletedCount data keys: ${data.keys.toList()}");
    }

    switch (action) {
      case ChallengeCheckActionType.libraryAuto:
        if (data is List<BookModel>) {
          return _getQuantityBasedCompletedCount(challenge, data);
        } else if (data is Map && data['savedBooks'] is List) {
          final raw = data['savedBooks'];
          final books = raw.map((e) {
            if (e is BookModel) return e;
            if (e is Map) return BookModel.fromMap(e.cast<String, dynamic>());
            return null;
          }).whereType<BookModel>().toList();

          //debugPrint("📘 libraryAuto 진행률: ${books.length}권 완료 중");
          return _getQuantityBasedCompletedCount(challenge, books);
        }
        return 0;

      case ChallengeCheckActionType.pageAuto:
        if (data is Map) {
          final raw = data['savedBooks'];

          if (raw is List) {
            final books = raw.map((e) {
              if (e is BookModel) return e;
              if (e is Map) return BookModel.fromMap(e.cast<String, dynamic>());
              return null;
            }).whereType<BookModel>().toList();

            //debugPrint("📘 pageAuto 진행률 (from savedBooks): ${_getSpecificBooksPageProgressFromBooks(challenge, books)} / ${getTargetCount(challenge, data)}");
            return _getSpecificBooksPageProgressFromBooks(challenge, books);
          }

          //debugPrint("⚠️ savedBooks 누락 or 잘못된 타입 → record 기반으로 진행");
          return _getSpecificBooksPageProgressFromRecord(challenge, data.cast<String, dynamic>());
        } else if (data is List<BookModel>) {
          //debugPrint("📘 pageAuto 진행률 (direct List<BookModel>): ${_getSpecificBooksPageProgressFromBooks(challenge, data)} / ${getTargetCount(challenge, data)}");
          return _getSpecificBooksPageProgressFromBooks(challenge, data);
        }

        //debugPrint("❌ pageAuto 진행 실패: data 타입 불일치");
        return 0;

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

  static int getTargetCount(Challenge challenge, dynamic recordDataOrSavedBooks) {
    //debugPrint("🔍 [getTargetCount] challenge.id: ${challenge.id}, method: ${challenge.method}, specificBookMode: ${challenge.specificBookMode}");

    // ✅ 스테이지 챌린지일 경우, 현재 attempt 기준으로 값 분기
    if (challenge.stageType == ChallengeStageType.staged && challenge.attempts.isNotEmpty) {
      final attempt = challenge.attempts.last;
      final stageIndex = attempt.stageIndex ?? 0;

      if (challenge.stageDurations != null && stageIndex < challenge.stageDurations!.length) {
        final stageTarget = challenge.stageDurations![stageIndex];
        //debugPrint("📌 [getTargetCount] stage-based → duration: $stageTarget");
        return stageTarget;
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
      if (challenge.specificBookMode == SpecificBookMode.systemDefined) {
        final length = challenge.requiredBooks?.length ?? 0;
        //debugPrint("📌 [getTargetCount] systemDefined → requiredBooks: $length");
        return length;
      } else {
        Map<String, dynamic> pages = {};

        if (recordDataOrSavedBooks is Map<String, dynamic>) {
          if (recordDataOrSavedBooks['bookReadPages'] is Map) {
            pages = Map<String, dynamic>.from(recordDataOrSavedBooks['bookReadPages']);
          } else if (recordDataOrSavedBooks['recordData'] is Map &&
              recordDataOrSavedBooks['recordData']['bookReadPages'] is Map) {
            pages = Map<String, dynamic>.from(recordDataOrSavedBooks['recordData']['bookReadPages']);
          }
        }

        //debugPrint("📌 [getTargetCount] userDefined → bookReadPages keys: ${pages.keys.toList()}");
        final fallback = challenge.participatingBooks?.length ?? 0;
        //debugPrint("📌 [getTargetCount] fallback participatingBooks.length: $fallback");

        return pages.isNotEmpty ? pages.keys.length : fallback;
      }
    }

    if (challenge.method == ChallengeMethod.quantityBased) {
      final total = challenge.totalBooks ?? 0;
      //debugPrint("📌 [getTargetCount] quantityBased → totalBooks: $total");
      return total;
    }

    //debugPrint("❗ [getTargetCount] fallback default → 1");
    return 1;
  }

  static int _getSpecificBooksPageProgressFromRecord(Challenge challenge, Map<String, dynamic> data) {
    // ✅ 1. 먼저 savedBooks가 있는지 확인하고 바로 위임
    final savedBooks = data['savedBooks'];
    if (savedBooks is List<BookModel>) {
      return _getSpecificBooksPageProgressFromBooks(challenge, savedBooks);
    }

    // ✅ 2. 없으면 기존 로직 실행
    final readPages = (data['bookReadPages'] as Map?)?.cast<String, dynamic>() ?? {};
    int count = 0;
    const threshold = 1.0;

    if (challenge.specificBookMode == SpecificBookMode.systemDefined) {
      for (final b in challenge.requiredBooks ?? []) {
        final id = b.id;
        final total = b.pageCount;
        final read = int.tryParse(readPages[id]?.toString() ?? '');
        if (id.isNotEmpty && total != null && read != null && read >= (total * threshold).floor()) {
          count++;
        }
      }
    } else {
      for (final b in challenge.participatingBooks ?? []) {
        final id = b.id;
        final total = b.pageCount ?? 0;
        final read = int.tryParse(readPages[id]?.toString() ?? '');
        if (id.isNotEmpty && total > 0 && read != null && read >= (total * threshold).floor()) {
          count++;
        }
      }
    }

    return count;
  }

  static int _getSpecificBooksPageProgressFromBooks(Challenge challenge, List<BookModel> books) {
    int count = 0;
    const threshold = 1.0;

    if (challenge.specificBookMode == SpecificBookMode.systemDefined) {
      for (final b in challenge.requiredBooks ?? []) {
        final id = b.id;
        final total = b.pageCount;
        final matched = books.firstWhere(
              (bk) => bk.id == id,
          orElse: () => BookModel(id: id, title: '제목 없음', author: '작자 미상'),
        );
        final read = matched.pageRead ?? 0;

        if (id.isNotEmpty && total != null && read >= (total * threshold).floor()) {
          count++;
        }
      }
    } else {
      for (final b in challenge.participatingBooks ?? []) {
        final id = b.id;
        final total = b.pageCount ?? 0;
        final matched = books.firstWhere(
              (bk) => bk.id == id,
          orElse: () => BookModel(id: id, title: '제목 없음', author: '작자 미상'),
        );
        final read = matched.pageRead ?? 0;

        if (id.isNotEmpty && total > 0 && read >= (total * threshold).floor()) {
          count++;
        }
      }
    }

    return count;
  }

  static List<String> getCompletedBookIdsForSpecificBooks(Challenge challenge, List<BookModel> books) {
    final List<String> completedIds = [];
    const threshold = 1.0;

    if (challenge.specificBookMode == SpecificBookMode.systemDefined) {
      for (final b in challenge.requiredBooks ?? []) {
        final matched = books.firstWhere((bk) => bk.id == b.id, orElse: () => BookModel(id: b.id, title: '', author: ''));
        final read = matched.pageRead ?? 0;
        final total = b.pageCount;
        if (total != null && read >= (total * threshold).floor()) {
          completedIds.add(b.id);
        }
      }
    } else {
      for (final b in challenge.participatingBooks ?? []) {
        final matched = books.firstWhere((bk) => bk.id == b.id, orElse: () => BookModel(id: b.id, title: '', author: ''));
        final read = matched.pageRead ?? 0;
        final total = b.pageCount ?? 0;
        if (total > 0 && read >= (total * threshold).floor()) {
          completedIds.add(b.id);
        }
      }
    }

    return completedIds;
  }

  /// ✅ quantityBased 완료 책 수
  static int _getQuantityBasedCompletedCount(Challenge challenge, List<BookModel> savedBooks) {
    final start = challenge.startDate;
    final end = challenge.endDate;
    return savedBooks.where((book) {
      final date = book.readDate;
      return book.category == 'done' &&
          date != null &&
          start != null &&
          end != null &&
          !date.isBefore(start) &&
          !date.isAfter(end);
    }).length;
  }

  /// ✅ specificBooks pageAuto
  static int _getSpecificBooksPageProgress(Challenge challenge, Map<String, dynamic> data) {
    final readPages = (data['bookReadPages'] as Map?)?.cast<String, dynamic>() ?? {};
    final savedBooks = data['savedBooks'] as List<BookModel>? ?? [];

    int count = 0;

    if (challenge.specificBookMode == SpecificBookMode.systemDefined) {
      for (final b in challenge.requiredBooks ?? []) {
        final id = b.id;
        final total = b.pageCount ?? 0;

        final book = savedBooks.firstWhere((sb) => sb.id == id, orElse: () => BookModel(id: id, title: '', author: ''));
        final savedRead = book.pageRead ?? 0;
        final recordRead = int.tryParse(readPages[id]?.toString() ?? '') ?? 0;
        final read = savedRead > 0 ? savedRead : recordRead;

        if (id.isNotEmpty && total > 0 && read >= total) count++;
      }
    } else {
      for (final b in challenge.participatingBooks ?? []) {
        final id = b.id;
        final total = b.pageCount ?? 0;

        final book = savedBooks.firstWhere((sb) => sb.id == id, orElse: () => BookModel(id: id, title: '', author: ''));
        final savedRead = book.pageRead ?? 0;
        final recordRead = int.tryParse(readPages[id]?.toString() ?? '') ?? 0;
        final read = savedRead > 0 ? savedRead : recordRead;

        if (read >= total && total > 0) count++;
      }
    }

    return count;
  }

  /// ✅ timerAuto 완료 일수
  static int _getTimerCompletedCount(Challenge challenge, Map<String, dynamic> data) {
    Map<String, dynamic> rawMinutes = {};

    if (data['recordData'] is Map &&
        data['recordData']['dailyMinutes'] is Map) {
      rawMinutes = Map<String, dynamic>.from(data['recordData']['dailyMinutes']);
    } else if (data['dailyMinutes'] is Map) {
      rawMinutes = Map<String, dynamic>.from(data['dailyMinutes']);
    }

    final required = challenge.requiredMinutes ?? 0;
    final minutesMap = rawMinutes.map((k, v) => MapEntry(k, int.tryParse(v.toString()) ?? 0));

    // ✅ 현재 attempt의 startDate 기준으로 이후 날짜만 카운트
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

  /// ✅ 현재 스테이지 완료 여부
  static bool _isCurrentStageCompleted(Challenge challenge, dynamic recordDataOrSavedBooks) {
    final completed = getCompletedCount(challenge, recordDataOrSavedBooks);
    final target = getTargetCount(challenge, recordDataOrSavedBooks);
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

  /// ✅ 챌린지 실패 여부
  static bool isChallengeFailed(Challenge challenge, dynamic recordDataOrSavedBooks) {
    final attempt = challenge.attempts.isNotEmpty ? challenge.attempts.last : null;
    if (attempt == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 스테이지 챌린지
    if (challenge.stageType == ChallengeStageType.staged) {
      final stageIndex = attempt.stageIndex ?? 0;
      final duration = (challenge.stageDurations != null && stageIndex < challenge.stageDurations!.length)
          ? challenge.stageDurations![stageIndex]
          : null;

      final startDate = attempt.startDate;
      if (startDate == null || duration == null) return false;

      final endDate = startDate.add(Duration(days: duration - 1));
      final isExpired = today.isAfter(endDate);
      final isIncomplete = !_isCurrentStageCompleted(challenge, recordDataOrSavedBooks);

      //("❌ [isChallengeFailed] 스테이지 챌린지 → 종료일: $endDate, 오늘: $today, 만료: $isExpired, 미완료: $isIncomplete");

      return isExpired && isIncomplete;
    }

    // 일반 챌린지
    final startDate = attempt.startDate ?? challenge.startDate;
    final endDate = challenge.endDate ??
        (challenge.period == ChallengePeriod.daysBased && attempt.selectedDuration != null
            ? startDate?.add(Duration(days: attempt.selectedDuration! - 1))
            : null);

    if (startDate == null || endDate == null) return false;

    final isExpired = today.isAfter(endDate);
    final completed = getCompletedCount(challenge, recordDataOrSavedBooks);
    final target = getTargetCount(challenge, recordDataOrSavedBooks);

    final isIncomplete = completed < target;

    //debugPrint("❌ [isChallengeFailed] 일반 챌린지 → 종료일: $endDate, 오늘: $today, 만료: $isExpired, 완료: $completed/$target");

    return isExpired && isIncomplete;
  }

}
