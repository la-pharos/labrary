import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/widget/page_input_dialog.dart';
import 'package:dayverse_book/service/reading_log_service.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/provider/reading_timer_provider.dart';
import 'package:dayverse_book/widget/calendar_widget.dart';
import 'package:dayverse_book/main.dart';
import 'package:dayverse_book/provider/reading_stats_provider.dart';
import 'package:dayverse_book/provider/reading_stats_provider.dart';

class ReadingRunningScreen extends StatefulWidget {
  final BookModel book;

  const ReadingRunningScreen({super.key, required this.book});

  @override
  State<ReadingRunningScreen> createState() => _ReadingRunningScreenState();
}

class _ReadingRunningScreenState extends State<ReadingRunningScreen>
    with WidgetsBindingObserver {
  int _countdown = 3;
  bool _showCountdown = true;
  bool _isProcessing = false;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final timerProvider =
      Provider.of<ReadingTimerProvider>(context, listen: false);

      timerProvider.attachIfNeeded();

      if (timerProvider.isCurrentBook(widget.book.id)) {
        setState(() {
          _showCountdown = false;
        });
      } else if (!timerProvider.hasActiveSession) {
        _startCountdown();
      } else {
        setState(() {
          _showCountdown = false;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final timerProvider =
      Provider.of<ReadingTimerProvider>(context, listen: false);
      timerProvider.attachIfNeeded();
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 1) {
        timer.cancel();

        final timerProvider =
        Provider.of<ReadingTimerProvider>(context, listen: false);

        if (!timerProvider.hasActiveSession) {
          timerProvider.startSession(widget.book);
        }

        if (mounted) {
          setState(() {
            _showCountdown = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _countdown--;
          });
        }
      }
    });
  }

  void _goHome() {
    if (_showCountdown) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainScreen(initialTabIndex: 0)),
          (route) => false,
    );
  }

  Future<void> _stopTimer() async {
    setState(() => _isProcessing = true);

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final screenWidth =
            MediaQuery.of(dialogContext).size.width;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.07,
          ),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(
              screenWidth * 0.045,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF16483F),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.30),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                // HEADER
                Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            '독서를 마칠까요?',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'kopub',
                              fontSize:
                              screenWidth * 0.043,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),

                          SizedBox(
                            height:
                            screenWidth * 0.01,
                          ),

                          Text(
                            '지금까지 읽은 시간을 기록할 수 있어요.',
                            style: TextStyle(
                              color: Colors.white
                                  .withOpacity(0.50),
                              fontFamily: 'kopub',
                              fontSize:
                              screenWidth * 0.028,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    IconButton(
                      onPressed: () {
                        Navigator.of(dialogContext)
                            .pop('cancel');
                      },
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white54,
                        size:
                        screenWidth * 0.05,
                      ),
                    ),
                  ],
                ),

                SizedBox(
                  height:
                  screenWidth * 0.03,
                ),

                // INFO
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal:
                    screenWidth * 0.035,
                    vertical:
                    screenWidth * 0.03,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent
                        .withOpacity(0.06),
                    borderRadius:
                    BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.amberAccent
                          .withOpacity(0.14),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width:
                        screenWidth * 0.075,
                        height:
                        screenWidth * 0.075,
                        decoration: BoxDecoration(
                          color: Colors.amberAccent
                              .withOpacity(0.10),
                          borderRadius:
                          BorderRadius.circular(9),
                        ),
                        child: Icon(
                          Icons.schedule_rounded,
                          color:
                          Colors.amberAccent,
                          size:
                          screenWidth * 0.04,
                        ),
                      ),

                      SizedBox(
                        width:
                        screenWidth * 0.025,
                      ),

                      Expanded(
                        child: Text(
                          '1분 이상 독서한 기록만 저장돼요.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontFamily: 'kopub',
                            fontSize:
                            screenWidth * 0.028,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  height:
                  screenWidth * 0.035,
                ),

                // SAVE
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext)
                          .pop('save');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      Colors.amberAccent,
                      foregroundColor:
                      const Color(0xFF013328),
                      elevation: 0,
                      padding:
                      EdgeInsets.symmetric(
                        vertical:
                        screenWidth * 0.036,
                      ),
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      '기록 저장',
                      style: TextStyle(
                        fontFamily: 'kopub',
                        fontSize:
                        screenWidth * 0.032,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                SizedBox(
                  height:
                  screenWidth * 0.015,
                ),

                // DISCARD
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext)
                          .pop('discard');
                    },
                    style: TextButton.styleFrom(
                      foregroundColor:
                      Colors.white54,
                      padding:
                      EdgeInsets.symmetric(
                        vertical:
                        screenWidth * 0.025,
                      ),
                    ),
                    child: Text(
                      '기록 없이 종료',
                      style: TextStyle(
                        fontFamily: 'kopub',
                        fontSize:
                        screenWidth * 0.029,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == null || action == 'cancel') {
      setState(() => _isProcessing = false);
      return;
    }

    final timerProvider =
    Provider.of<ReadingTimerProvider>(context, listen: false);

    if (action == 'discard') {
      timerProvider.stopSession();

      if (!mounted) return;

      setState(() => _isProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("독서 기록 없이 타이머를 종료했습니다.",
          style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),),
          backgroundColor: Colors.amberAccent,
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.of(context).pop();
      return;
    }

    // 여기부터는 action == 'save'일 때만 실행
    final elapsedSeconds = timerProvider.elapsedSeconds;

    if (elapsedSeconds < 60) {
      timerProvider.stopSession();

      if (mounted) {
        setState(() => _isProcessing = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⏱ 1분 이상 독서해야 기록이 저장됩니다."),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.of(context).pop();
      }

      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => PageInputDialog(
        totalPages: widget.book.pageCount,
        initialPage: widget.book.pageRead,
      ),
    );

    // ✅ 페이지 입력 취소 시 세션 유지
    if (result == null) {
      setState(() => _isProcessing = false);
      return;
    }

    // ✅ 여기서 실제 종료
    final snapshot = timerProvider.stopSession();

    if (snapshot == null) {
      setState(() => _isProcessing = false);
      return;
    }

    final int? pageRead = result['page'] as int?;
    final bool isDone = result['done'] as bool;
    final String newCategory = isDone ? "done" : "reading";

    try {
      final booksProvider =
      Provider.of<SavedBooksProvider>(context, listen: false);

      await ReadingLogService.saveTimerLog(
        bookId: snapshot.book.id,
        title: snapshot.book.title,
        startTime: snapshot.startTime,
        endTime: snapshot.endTime,
        durationMinutes: snapshot.durationMinutes,
      );

      if (!mounted) return;

      await context
          .read<ReadingStatsProvider>()
          .refresh();

      if (!mounted) return;

      await booksProvider.addOrUpdateBook(
        snapshot.book.copyWith(
          category: newCategory,
          startDate: snapshot.book.startDate ?? snapshot.startTime,
          endDate: isDone ? DateTime.now() : null,
          readDate: isDone ? DateTime.now() : null,
          pageRead: pageRead ?? snapshot.book.pageRead,
        ),
      );

      final challengeProvider =
      Provider.of<ChallengeProvider>(context, listen: false);
      final savedBooks = booksProvider.savedBooks;
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

      await challengeProvider.refreshAllStatuses(
        savedBooks: savedBooks,
        userId: userId,
      );

      if (!mounted) return;

      setState(() => _isProcessing = false);

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (Navigator.of(ctx).canPop()) {
              Navigator.of(ctx).pop();
            }
          });

          return AlertDialog(
            backgroundColor: Colors.greenAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text("✨", style: TextStyle(fontSize: 36)),
                    SizedBox(height: 12),
                    Text(
                      "오늘도 독서 성공!\n꾸준함이 빛을 만듭니다 💪",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Kopub',
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text("응원합니다 🌟", textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          );
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ 독서 기록이 저장되었습니다."),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e, stack) {
      debugPrint('[❌ ERROR] Reading Timer 종료 중 예외 발생: $e');
      debugPrintStack(stackTrace: stack);

      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("오류가 발생했습니다: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _showCategoryAndDateDialog() async {
    final category = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "독서 기간 선택",
          style: TextStyle(
            fontFamily: 'kopub',
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: const Text(
          "책을 얼만큼 읽으셨나요?",
          style: TextStyle(
            fontFamily: 'kopub',
            color: Colors.white70,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop("done"),
            child: const Text("다 읽었어요!", style: TextStyle(color: Colors.amberAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop("reading"),
            child: const Text("계속 읽고 있어요!", style: TextStyle(color: Colors.amberAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text("취소", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (category == null) return null;

    DateTime? startDate;
    await showCalendarDialog(
      context: context,
      isStartDate: true,
      selectedDate: DateTime.now(),
      minDate: DateTime(2000),
      maxDate: DateTime.now(),
      onDatePicked: (picked) => startDate = picked,
    );
    if (startDate == null) return null;

    DateTime? endDate;
    if (category == "done") {
      await showCalendarDialog(
        context: context,
        isStartDate: false,
        selectedDate: DateTime.now(),
        minDate: startDate!,
        maxDate: DateTime.now(),
        onDatePicked: (picked) => endDate = picked,
      );
      if (endDate == null) return null;
    }

    return {
      "category": category,
      "startDate": startDate,
      "endDate": endDate,
    };
  }

  String _formatTime(int seconds) {
    final d = Duration(seconds: seconds);
    final hh = d.inHours.toString().padLeft(2, '0');
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$hh:$mm:$ss";
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Consumer<ReadingTimerProvider>(
      builder: (context, timerProvider, child) {
        final bool hasOwnActiveSession =
        timerProvider.isCurrentBook(widget.book.id);

        final bool hasAnotherBookSession =
            timerProvider.hasActiveSession && !hasOwnActiveSession;

        final int seconds = hasOwnActiveSession ? timerProvider.elapsedSeconds : 0;
        final bool isPaused = hasOwnActiveSession ? timerProvider.isPaused : false;

        return Scaffold(
          backgroundColor: const Color(0xFF0A1D27),
          body: Stack(
            children: [
              SizedBox(
                height: screenHeight,
                width: screenWidth,
                child: Image.asset(
                  'assets/image/dive_in.jpg',
                  fit: BoxFit.cover,
                ),
              ),

              SafeArea(
                child: Stack(
                  children: [
                    if (!_showCountdown)
                      Positioned(
                        top: screenWidth * 0.03,
                        right: screenWidth * 0.04,
                        child: _buildHomeButton(screenWidth),
                      ),

                    Center(
                      child: hasAnotherBookSession
                          ? _buildAnotherSessionWarning(screenWidth, timerProvider)
                          : _showCountdown
                          ? Text(
                        '$_countdown',
                        style: const TextStyle(
                          fontSize: 100,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                          : _buildTimerContent(
                        screenWidth: screenWidth,
                        seconds: seconds,
                        isPaused: isPaused,
                        onPauseToggle: timerProvider.togglePause,
                      ),
                    ),
                  ],
                ),
              ),

              if (_isProcessing)
                Container(
                  color: Colors.black45,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.amberAccent,
                      strokeWidth: 4,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHomeButton(
      double screenWidth,
      ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _goHome,
        customBorder:
        const CircleBorder(),
        child: Container(
          width:
          screenWidth * 0.12,
          height:
          screenWidth * 0.12,
          decoration: BoxDecoration(
            color: Colors.black
                .withOpacity(0.35),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white
                  .withOpacity(0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withOpacity(0.22),
                blurRadius: 14,
                offset:
                const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.home_rounded,
            color: Colors.white,
            size:
            screenWidth * 0.055,
          ),
        ),
      ),
    );
  }

  Widget _buildAnotherSessionWarning(
      double screenWidth,
      ReadingTimerProvider timerProvider,
      ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.menu_book_rounded,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            '이미 다른 책의 독서 타이머가 진행 중이에요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.bold,
              fontFamily: 'kopub',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            timerProvider.currentBook?.title ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: screenWidth * 0.038,
              fontFamily: 'kopub',
            ),
          ),
          const SizedBox(height: 24),
          _buildTimerButton(
            text: '홈으로 이동',
            icon: Icons.home_rounded,
            screenWidth: screenWidth,
            onPressed: _goHome,
            type: _TimerButtonType.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildTimerContent({
    required double screenWidth,
    required int seconds,
    required bool isPaused,
    required VoidCallback onPauseToggle,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _formatTime(seconds),
          style: TextStyle(
            fontSize: screenWidth * 0.15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 40),
        _buildControlButtons(
          screenWidth: screenWidth,
          isPaused: isPaused,
          onPauseToggle: onPauseToggle,
        ),
      ],
    );
  }

  Widget _buildControlButtons({
    required double screenWidth,
    required bool isPaused,
    required VoidCallback onPauseToggle,
  }) {
    if (!isPaused) {
      return _buildTimerButton(
        text: '일시정지',
        icon:
        Icons.pause_rounded,
        screenWidth:
        screenWidth,
        onPressed:
        onPauseToggle,
        type:
        _TimerButtonType.secondary,
      );
    }

    return Row(
      mainAxisAlignment:
      MainAxisAlignment.center,
      children: [
        _buildTimerButton(
          text: '계속',
          icon:
          Icons.play_arrow_rounded,
          screenWidth:
          screenWidth,
          onPressed:
          onPauseToggle,
          type:
          _TimerButtonType.primary,
        ),

        SizedBox(
          width:
          screenWidth * 0.035,
        ),

        _buildTimerButton(
          text: '종료',
          icon:
          Icons.stop_rounded,
          screenWidth:
          screenWidth,
          onPressed:
          _stopTimer,
          type:
          _TimerButtonType.danger,
        ),
      ],
    );
  }

  Widget _buildTimerButton({
    required String text,
    required IconData icon,
    required double screenWidth,
    required VoidCallback onPressed,
    required _TimerButtonType type,
  }) {
    Color backgroundColor;
    Color foregroundColor;
    Color borderColor;

    switch (type) {
      case _TimerButtonType.primary:
        backgroundColor =
            Colors.amberAccent;
        foregroundColor =
        const Color(0xFF013328);
        borderColor =
            Colors.transparent;
        break;

      case _TimerButtonType.secondary:
        backgroundColor =
            Colors.black.withOpacity(0.28);
        foregroundColor =
            Colors.white;
        borderColor =
            Colors.white.withOpacity(0.22);
        break;

      case _TimerButtonType.danger:
        backgroundColor =
            Colors.black.withOpacity(0.28);
        foregroundColor =
            Colors.redAccent;
        borderColor =
            Colors.redAccent.withOpacity(0.35);
        break;
    }

    return Material(
      color: backgroundColor,
      borderRadius:
      BorderRadius.circular(30),
      child: InkWell(
        onTap:
        onPressed,
        borderRadius:
        BorderRadius.circular(30),
        child: Container(
          padding:
          EdgeInsets.symmetric(
            horizontal:
            screenWidth * 0.055,
            vertical:
            screenWidth * 0.03,
          ),
          decoration:
          BoxDecoration(
            borderRadius:
            BorderRadius.circular(30),
            border: Border.all(
              color:
              borderColor,
            ),
          ),
          child: Row(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              Icon(
                icon,
                color:
                foregroundColor,
                size:
                screenWidth * 0.045,
              ),

              SizedBox(
                width:
                screenWidth * 0.015,
              ),

              Text(
                text,
                style:
                TextStyle(
                  color:
                  foregroundColor,
                  fontSize:
                  screenWidth * 0.036,
                  fontWeight:
                  FontWeight.bold,
                  fontFamily:
                  'kopub',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

enum _TimerButtonType {
  primary,
  secondary,
  danger,
}