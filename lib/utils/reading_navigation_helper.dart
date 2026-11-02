import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/provider/reading_timer_provider.dart';
import 'package:dayverse_book/screen/reading_intro_screen.dart';
import 'package:dayverse_book/screen/reading_running_screen.dart';

class ReadingNavigationHelper {
  static Future<void> goToReadingEntry(
      BuildContext context, {
        Challenge? challenge,
        BookModel? initialBook,
        List<BookModel>? candidateBooksOverride,
      }) async {
    final timerProvider =
    Provider.of<ReadingTimerProvider>(context, listen: false);

    // ✅ 현재 진행 중인 타이머가 있으면 무조건 기존 타이머 화면으로 복귀
    if (timerProvider.hasActiveSession && timerProvider.currentBook != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReadingRunningScreen(
            book: timerProvider.currentBook!,
          ),
        ),
      );
      return;
    }

    // ✅ 진행 중인 타이머가 없으면 새 독서 진입
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingIntroScreen(
          challenge: challenge,
          initialBook: initialBook,
          candidateBooksOverride: candidateBooksOverride,
        ),
      ),
    );
  }
}