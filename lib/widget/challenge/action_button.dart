import 'package:flutter/material.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/screen/reading_intro_screen.dart';
import 'package:dayverse_book/utils/challenge_check_utils.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';

class ActionButton extends StatelessWidget {
  final Challenge challenge;
  final dynamic record;

  /// ✅ OngoingScreen에서 계산해 둔 타겟 도서(풀/참여/구버전 포함)
  final List<BookModel>? targetBooksOverride;

  const ActionButton({
    super.key,
    required this.challenge,
    required this.record,
    this.targetBooksOverride,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = screenWidth * 0.9;
    final paddingVertical = screenWidth * 0.045;
    final fontSize = screenWidth * 0.045;

    DateTime strip(DateTime d) => DateTime(d.year, d.month, d.day);

    // ✅ 로컬 기준 오늘(시간 제거)
    final today = strip(DateTime.now().toLocal());

    final attempt = challenge.attempts.isNotEmpty ? challenge.attempts.last : null;

    // ✅ 루틴형만 "오늘 성공" 체크 적용
    final bool isRoutine = challenge.category == ChallengeCategory.routine;
    final bool isTodaySuccess = isRoutine
        ? checkRoutineDateChecked(
      challenge: challenge,
      date: today,
      recordDataOrSavedBooks: record,
    )
        : false;

    // ---- 도전 가능 윈도우 계산 (start/end는 무조건 로컬 + strip) ----
    DateTime? start;
    DateTime? end;

    if (attempt != null) {
      // attempt 기반이 1순위
      start = strip(attempt.startDate.toLocal());

      // daysBased: selectedDuration이 있으면 end 계산
      if (attempt.selectedDuration != null) {
        end = start.add(Duration(days: attempt.selectedDuration! - 1));
      } else if (attempt.endDate != null) {
        // periodBased에서 attempt에 endDate가 있으면 사용
        end = strip(attempt.endDate!.toLocal());
      }
    }

    // attempt 기반으로 못 채우면 challenge 레벨 날짜 사용(있을 때만)
    start ??= (challenge.startDate != null) ? strip(challenge.startDate!.toLocal()) : null;
    end ??= (challenge.endDate != null) ? strip(challenge.endDate!.toLocal()) : null;

    final bool isBeforeStart = (start != null) && today.isBefore(start!);
    final bool isAfterEnd = (end != null) && today.isAfter(end!);

    // ✅ 비활성 조건:
    // - 시작 전/종료 후: 공통
    // - 오늘 이미 성공: 루틴형만
    final bool isDisabled = isBeforeStart || isAfterEnd || (isRoutine && isTodaySuccess);

    final String buttonText = isBeforeStart
        ? "도전 시작 전이에요 💪"
        : isAfterEnd
        ? "도전 기간이 끝났어요"
        : (isRoutine && isTodaySuccess)
        ? "오늘은 이미 성공 ✨"
        : "오늘의 도전 시작하기";

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: screenWidth * 0.1),
        child: SizedBox(
          width: buttonWidth,
          child: ElevatedButton(
            onPressed: isDisabled ? null : () => _handleNavigateToReading(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              disabledBackgroundColor: Colors.redAccent.withOpacity(0.5),
              padding: EdgeInsets.symmetric(vertical: paddingVertical),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              buttonText,
              style: TextStyle(
                fontSize: fontSize,
                fontFamily: 'kopub',
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleNavigateToReading(BuildContext context) {
    // savedBooks는 현재 여기서 직접 쓰진 않지만,
    // 이후 타입별 분기 확장 시 필요할 수 있어 유지.
    context.read<SavedBooksProvider>().savedBooks;

    final checkType = getChallengeCheckActionType(challenge);

    // ✅ 단일 + 사용자 지정도서 + 페이지연동: 이미 선택된 책이 있으면 자동 선택
    final isUserDefinedSinglePageAuto =
        challenge.stageType == ChallengeStageType.single &&
            challenge.method == ChallengeMethod.specificBooks &&
            challenge.specificBookMode == SpecificBookMode.userDefined &&
            checkType == ChallengeCheckActionType.pageAuto;

    if (isUserDefinedSinglePageAuto &&
        (challenge.participatingBooks?.isNotEmpty ?? false)) {
      final selectedBook = challenge.participatingBooks!.first;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReadingIntroScreen(
            challenge: challenge,
            initialBook: selectedBook,
            candidateBooksOverride: targetBooksOverride,
          ),
        ),
      );
      return;
    }

    // ✅ 그 외(운영자 지정 페이지연동 포함): Intro에서 선택/진입 처리
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingIntroScreen(
          challenge: challenge,
          initialBook: null,
          candidateBooksOverride: targetBooksOverride,
        ),
      ),
    );
  }
}