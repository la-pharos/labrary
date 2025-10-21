import 'package:flutter/material.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/book_model.dart';

/// ✅ 체크 동작 방식 구분
enum ChallengeCheckActionType {
  timerAuto,      // ⏱ 타이머 자동 체크
  pageAuto,       // 📖 페이지 자동 체크
  libraryAuto,    // 📚 서재 연동 자동 체크
  manual,         // ✅ 수동 체크
  none,           // ❌ 체크 없음
}

/// ✅ 챌린지에 따라 체크 방식 분기 (통합된 ChallengeModel 기준)
ChallengeCheckActionType getChallengeCheckActionType(Challenge challenge) {
  // ✅ 수동 체크
  if (challenge.checkMode == ChallengeCheckMode.manual) {
    return ChallengeCheckActionType.manual;
  }

  // ✅ 페이지 자동 체크 (지정도서 + 페이지수 설정)
  final isPageAuto = challenge.method == ChallengeMethod.specificBooks &&
      (challenge.requiredPages ?? 0) > 0;

  if (isPageAuto) return ChallengeCheckActionType.pageAuto;

  // ✅ 서재 자동 체크 (지정도서 + 페이지 없음 or 권수 기반)
  final isLibraryAuto = (challenge.method == ChallengeMethod.specificBooks &&
      (challenge.requiredPages == null || challenge.requiredPages == 0)) ||
      challenge.method == ChallengeMethod.quantityBased;

  if (isLibraryAuto) return ChallengeCheckActionType.libraryAuto;

  // ✅ 타이머 자동 체크 (시간 기준)
  if ((challenge.requiredMinutes ?? 0) > 0) {
    return ChallengeCheckActionType.timerAuto;
  }

  // ✅ 해당 없음
  return ChallengeCheckActionType.none;
}

/// ✅ 시간대 제한 확인 유틸
bool isWithinAllowedTime(Challenge challenge) {
  if (challenge.allowedStartTime == null || challenge.allowedEndTime == null) return true;

  try {
    final now = TimeOfDay.now();
    final start = challenge.allowedStartTime!;
    final end = challenge.allowedEndTime!;

    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
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
}) {
  final checkType = getChallengeCheckActionType(challenge);
  final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  switch (checkType) {
    case ChallengeCheckActionType.manual:
      if (recordDataOrSavedBooks is Map<String, dynamic>) {
        return recordDataOrSavedBooks[dateStr] == true;
      }
      return false;

    case ChallengeCheckActionType.timerAuto:
      if (recordDataOrSavedBooks is Map<String, dynamic>) {
        Map<String, dynamic> dailyMinutes = {};

        // ⛏ 구조별 분기
        if (recordDataOrSavedBooks['recordData'] is Map &&
            recordDataOrSavedBooks['recordData']['dailyMinutes'] is Map) {
          dailyMinutes = Map<String, dynamic>.from(
              recordDataOrSavedBooks['recordData']['dailyMinutes']);
        } else if (recordDataOrSavedBooks['dailyMinutes'] is Map) {
          dailyMinutes = Map<String, dynamic>.from(
              recordDataOrSavedBooks['dailyMinutes']);
        }

        final minutes = int.tryParse(dailyMinutes[dateStr]?.toString() ?? '0') ?? 0;
        return minutes >= (challenge.requiredMinutes ?? 0);
      }
      return false;

    case ChallengeCheckActionType.pageAuto:
      if (recordDataOrSavedBooks is Map<String, dynamic>) {
        final pages = recordDataOrSavedBooks[dateStr];
        return pages != null && pages is int && pages >= (challenge.requiredPages ?? 0);
      }
      return false;

    case ChallengeCheckActionType.libraryAuto:
      if (recordDataOrSavedBooks is List<BookModel>) {
        for (final book in recordDataOrSavedBooks) {
          final readingDates = book.readingDates ?? [];
          if (readingDates.any((d) => isSameDate(d, date))) {
            return true;
          }
        }
      }
      return false;

    default:
      return false;
  }
}

/// ✅ 가장 최근 attempt의 recordData 반환
Map<String, dynamic> getChallengeRecordData(Challenge challenge) {
  if (challenge.attempts.isEmpty) return {};
  final latestAttempt = challenge.attempts.last;
  return latestAttempt.recordData ?? {};
}

bool isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
