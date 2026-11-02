
import 'package:flutter/material.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/model/challenge_attempt_model.dart';

/// ✅ 체크 동작 방식 구분
enum ChallengeCheckActionType {
  timerAuto,   // ⏱ 타이머 자동 체크
  pageAuto,    // 📖 페이지 자동 체크
  libraryAuto, // 📚 서재 연동 자동 체크
  manual,      // ✅ 수동 체크
  none,        // ❌ 체크 없음
}

/// ✅ 챌린지에 따라 체크 방식 분기
ChallengeCheckActionType getChallengeCheckActionType(
    Challenge challenge,
    ) {
  // ✅ 수동 체크
  if (challenge.checkMode == ChallengeCheckMode.manual) {
    return ChallengeCheckActionType.manual;
  }

  // ✅ 기간 누적 독서시간 기반
  // 주간 챌린지 등에서 사용
  if (challenge.method == ChallengeMethod.timeBased) {
    return ChallengeCheckActionType.timerAuto;
  }

  // ✅ 페이지 자동 체크
  // 지정도서 + 페이지수 설정
  final isPageAuto =
      challenge.method == ChallengeMethod.specificBooks &&
          (challenge.requiredPages ?? 0) > 0;

  if (isPageAuto) {
    return ChallengeCheckActionType.pageAuto;
  }

  // ✅ 서재 자동 체크
  // 지정도서 + 페이지 없음 또는 권수 기반
  final isLibraryAuto =
      (challenge.method == ChallengeMethod.specificBooks &&
          (challenge.requiredPages == null ||
              challenge.requiredPages == 0)) ||
          challenge.method == ChallengeMethod.quantityBased;

  if (isLibraryAuto) {
    return ChallengeCheckActionType.libraryAuto;
  }

  // ✅ 기존 타이머 자동 체크
  // 하루 N분 독서 등의 루틴형 챌린지
  if ((challenge.requiredMinutes ?? 0) > 0) {
    return ChallengeCheckActionType.timerAuto;
  }

  // ✅ 해당 없음
  return ChallengeCheckActionType.none;
}

/// ✅ 시간대 제한 확인 유틸
bool isWithinAllowedTime(Challenge challenge) {
  if (challenge.allowedStartTime == null ||
      challenge.allowedEndTime == null) {
    return true;
  }

  try {
    final now = TimeOfDay.now();
    final start = challenge.allowedStartTime!;
    final end = challenge.allowedEndTime!;

    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    return nowMinutes >= startMinutes &&
        nowMinutes <= endMinutes;
  } catch (e) {
    debugPrint('[ERROR] isWithinAllowedTime: $e');
    return true;
  }
}

/// ✅ 루틴형 챌린지에서 특정 날짜 체크 여부
bool checkRoutineDateChecked({
  required Challenge challenge,
  required DateTime date,
  required dynamic recordDataOrSavedBooks,
  ChallengeAttempt? attemptOverride,
}) {
  final checkType = getChallengeCheckActionType(challenge);

  final attempt = attemptOverride ??
      (challenge.attempts.isNotEmpty
          ? challenge.attempts.last
          : null);

  final dateOnly = DateTime(
    date.year,
    date.month,
    date.day,
  );

  final dateStr =
      '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  // =====================================================
  // ✅ Attempt 기간 확인
  // =====================================================

  if (attempt != null) {
    // timeBased는 참여일이 아니라 챌린지 시작일 기준
    final effectiveStart =
    challenge.method == ChallengeMethod.timeBased
        ? (challenge.startDate ?? attempt.startDate)
        : attempt.startDate;

    final start = DateTime(
      effectiveStart.year,
      effectiveStart.month,
      effectiveStart.day,
    );

    DateTime? effectiveEnd;

    if (challenge.method == ChallengeMethod.timeBased) {
      effectiveEnd = challenge.endDate ?? attempt.endDate;
    } else if (attempt.selectedDuration != null &&
        attempt.selectedDuration! > 0) {
      effectiveEnd = start.add(
        Duration(days: attempt.selectedDuration! - 1),
      );
    } else {
      effectiveEnd = attempt.endDate;
    }

    final end = effectiveEnd == null
        ? null
        : DateTime(
      effectiveEnd.year,
      effectiveEnd.month,
      effectiveEnd.day,
    );

    if (dateOnly.isBefore(start)) return false;
    if (end != null && dateOnly.isAfter(end)) {
      return false;
    }
  }

  // =====================================================
  // ✅ 체크 방식별 처리
  // =====================================================

  switch (checkType) {
    case ChallengeCheckActionType.manual:
      if (recordDataOrSavedBooks is Map<String, dynamic>) {
        return recordDataOrSavedBooks[dateStr] == true;
      }
      return false;

    case ChallengeCheckActionType.timerAuto:
      if (recordDataOrSavedBooks is Map<String, dynamic>) {
        Map<String, dynamic> dailyMinutes = {};

        if (recordDataOrSavedBooks['recordData'] is Map &&
            recordDataOrSavedBooks['recordData']['dailyMinutes']
            is Map) {
          dailyMinutes = Map<String, dynamic>.from(
            recordDataOrSavedBooks['recordData']
            ['dailyMinutes'],
          );
        } else if (recordDataOrSavedBooks['dailyMinutes']
        is Map) {
          dailyMinutes = Map<String, dynamic>.from(
            recordDataOrSavedBooks['dailyMinutes'],
          );
        }

        final minutes = int.tryParse(
          dailyMinutes[dateStr]?.toString() ?? '0',
        ) ??
            0;

        // ✅ 기간 누적형은 하루 60분 달성 여부를
        // 판단하지 않는다.
        //
        // 날짜별 독서 기록이 있는지만 확인하며,
        // 전체 목표 달성 여부는
        // ChallengeProgressUtils에서 판단한다.
        if (challenge.method == ChallengeMethod.timeBased) {
          return minutes > 0;
        }

        // ✅ 기존 일일 타이머 챌린지
        final requiredMinutes =
            challenge.requiredMinutes ?? 0;

        if (requiredMinutes <= 0) return false;

        return minutes >= requiredMinutes;
      }

      return false;

    case ChallengeCheckActionType.pageAuto:
      if (recordDataOrSavedBooks is Map<String, dynamic>) {
        final pages = recordDataOrSavedBooks[dateStr];

        return pages != null &&
            pages is int &&
            pages >= (challenge.requiredPages ?? 0);
      }

      return false;

    case ChallengeCheckActionType.libraryAuto:
      if (recordDataOrSavedBooks is List<BookModel>) {
        for (final book in recordDataOrSavedBooks) {
          final readingDates = book.readingDates ?? [];

          if (readingDates.any(
                (d) => isSameDate(d, date),
          )) {
            return true;
          }
        }
      }

      return false;

    case ChallengeCheckActionType.none:
      return false;
  }
}

/// ✅ 가장 최근 Attempt의 recordData 반환
Map<String, dynamic> getChallengeRecordData(
    Challenge challenge,
    ) {
  if (challenge.attempts.isEmpty) {
    return {};
  }

  final latestAttempt = challenge.attempts.last;

  return latestAttempt.recordData ?? {};
}

/// ✅ 같은 날짜인지 확인
bool isSameDate(DateTime a, DateTime b) {
  return a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;
}
