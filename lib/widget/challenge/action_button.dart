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

  // ✅ 선택: OngoingScreen에서 계산해 둔 타겟 도서 주입(풀/참여/구버전 포함)
  final List<BookModel>? targetBooksOverride;

  const ActionButton({
    super.key,
    required this.challenge,
    required this.record,
    this.targetBooksOverride, // ← optional
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    final buttonWidth = screenWidth * 0.9;
    final paddingVertical = screenWidth * 0.045;
    final fontSize = screenWidth * 0.045;

    DateTime strip(DateTime d) => DateTime(d.year, d.month, d.day);

    final now = DateTime.now();
    final today = strip(now);

    final attempt = challenge.attempts.isNotEmpty
        ? challenge.attempts.last
        : null;

    // 오늘 성공 여부(기존 로직 유지)
    final isTodaySuccess = checkRoutineDateChecked(
      challenge: challenge,
      date: today,
      recordDataOrSavedBooks: record,
    );

    // ---- 도전 가능 윈도우 계산 (모든 챌린지 공통) ----
    DateTime? start = attempt?.startDate;
    DateTime? end;

    // daysBased: attempt.selectedDuration 우선
    if (start != null && (attempt?.selectedDuration != null)) {
      start = strip(start.toLocal());
      end = start.add(Duration(days: attempt!.selectedDuration! - 1));
    } else {
      // attempt.endDate가 있으면 그것을 사용
      if (attempt?.endDate != null) {
        start = strip((attempt!.startDate).toLocal());
        end = strip((attempt.endDate!).toLocal());
      } else {
        // periodBased 등 challenge 레벨 기간이 있을 때
        if (challenge.startDate != null)
          start = strip(challenge.startDate!.toLocal());
        if (challenge.endDate != null)
          end = strip(challenge.endDate!.toLocal());
      }
    }

    final bool isBeforeStart = (start != null) && today.isBefore(start);
    final bool isAfterEnd = (end != null) && today.isAfter(end);

    // ---- 비활성 조건: 시작 전 / 종료 후 / 오늘 이미 성공 ----
    final bool isDisabled = isBeforeStart || isAfterEnd || isTodaySuccess;

    final String buttonText = isBeforeStart
        ? "도전 시작 전이에요 💪"
        : isAfterEnd
        ? "도전 기간이 끝났어요"
        : isTodaySuccess
        ? "오늘은 이미 성공 ✨"
        : "오늘의 도전 시작하기";

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: screenWidth * 0.1),
        child: SizedBox(
          width: buttonWidth,
          child: ElevatedButton(
            onPressed: isDisabled ? null : () =>
                _handleNavigateToReading(context),
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

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  bool isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _handleNavigateToReading(BuildContext context) {
    final savedBooks = context
        .read<SavedBooksProvider>()
        .savedBooks;

    final isUserDefined = challenge.method == ChallengeMethod.specificBooks &&
        challenge.specificBookMode == SpecificBookMode.userDefined &&
        challenge.stageType == ChallengeStageType.single &&
        getChallengeCheckActionType(challenge) ==
            ChallengeCheckActionType.pageAuto;

    if (isUserDefined &&
        challenge.participatingBooks != null &&
        challenge.participatingBooks!.isNotEmpty) {
      final selectedBook = challenge.participatingBooks!.first;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ReadingIntroScreen(
                challenge: challenge,
                initialBook: selectedBook,
                // (필요 없다면 생략 가능)
                candidateBooksOverride: targetBooksOverride, // ← 전달만
              ),
        ),
      );
      return;
    }

    final isAdminDefinedPageAuto = challenge.method == ChallengeMethod.specificBooks &&
        challenge.specificBookMode == SpecificBookMode.systemDefined &&
        getChallengeCheckActionType(challenge) == ChallengeCheckActionType.pageAuto;

    // 시스템 지정 + 페이지연동: 후보 목록을 화면에 넘겨주기만(선택 UI는 Intro에서)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingIntroScreen(
          challenge: challenge,
          initialBook: null,
          // ✅ 풀에서 해석된 목록이 있다면 넘겨줌(ReadingIntroScreen에서 없으면 무시해도 됨)
          candidateBooksOverride: targetBooksOverride,
        ),
      ),
    );
  }
}