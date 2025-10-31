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
import 'package:dayverse_book/widget/calendar_widget.dart';

class ReadingRunningScreen extends StatefulWidget {
  final BookModel book;

  const ReadingRunningScreen({super.key, required this.book});

  @override
  State<ReadingRunningScreen> createState() => _ReadingRunningScreenState();
}

class _ReadingRunningScreenState extends State<ReadingRunningScreen>
    with WidgetsBindingObserver {
  // 3-2-1 카운트다운
  int _countdown = 3;
  bool _showCountdown = true;

  // ✅ 벽시계 기반 타이머 상태
  Timer? _ticker;                    // 1초마다 UI만 갱신
  int _seconds = 0;                  // 표시용(계산 결과)
  bool _isPaused = false;

  late DateTime _startTime;          // 카운트다운 이후의 '실제 시작 시각'
  Duration _pausedTotal = Duration.zero; // 누적 일시정지 시간
  DateTime? _pausedAt;               // 일시정지 시작 시각

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCountdown();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  // 앱이 백→복귀 시 바로 값 보정
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_showCountdown) {
      _recomputeSeconds();
      setState(() {});
    }
  }

  // --- Countdown → Timer -----------------------------------------------------

  void _startCountdown() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 1) {
        timer.cancel();
        setState(() {
          _showCountdown = false;
        });

        // ✅ 여기서부터가 '진짜' 독서 시작 시각
        _startTime = DateTime.now();
        _pausedTotal = Duration.zero;
        _pausedAt = null;
        _isPaused = false;

        _startTimer();
      } else {
        setState(() {
          _countdown--;
        });
      }
    });
  }

  void _startTimer() {
    // 1초마다 화면만 갱신 (권위는 _recomputeSeconds)
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused) {
        _recomputeSeconds();
        setState(() {});
      }
    });
  }

  // ✅ 벽시계 기준으로 경과초 재계산
  void _recomputeSeconds() {
    final now = DateTime.now();
    final pausedExtra = (_pausedAt != null) ? now.difference(_pausedAt!) : Duration.zero;
    final elapsed = now.difference(_startTime) - _pausedTotal - pausedExtra;
    _seconds = elapsed.isNegative ? 0 : elapsed.inSeconds;
  }

  void _togglePause() {
    final now = DateTime.now();
    if (_isPaused) {
      // ▶️ 재개: 방금까지 정지시간을 누적
      if (_pausedAt != null) {
        _pausedTotal += now.difference(_pausedAt!);
        _pausedAt = null;
      }
      _isPaused = false;
      _recomputeSeconds();
      setState(() {});
    } else {
      // ⏸️ 정지 시작: 정지 직전까지 확정
      _recomputeSeconds();
      _pausedAt = now;
      _isPaused = true;
      setState(() {});
    }
  }

  // --- Stop → PageInputDialog → 저장 ----------------------------------------

  void _stopTimer() async {
    setState(() => _isProcessing = true);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "독서를 마치시겠어요?",
          style: TextStyle(
            fontFamily: 'kopub',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        content: const Text(
          "지금까지의 시간을 저장합니다.\n단, 1분 이상 독서해야 기록이 저장됩니다.",
          style: TextStyle(
            fontFamily: 'kopub',
            fontSize: 15,
            height: 1.4,
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              "확인",
              style: TextStyle(
                fontFamily: 'kopub',
                fontWeight: FontWeight.bold,
                color: Colors.amberAccent,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              "취소",
              style: TextStyle(
                fontFamily: 'kopub',
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      setState(() => _isProcessing = false);
      return;
    }

    _ticker?.cancel();        // ✅ periodic 중지
    _recomputeSeconds();      // ✅ 종료 직전 최종 보정

    final endTime = DateTime.now();
    final durationMinutes = (_seconds / 60).round();

    if (_seconds < 60) {
      setState(() => _isProcessing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⏱ 1분 이상 독서해야 기록이 저장됩니다."),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    // ✅ 페이지 입력 다이얼로그 (원래 흐름 유지)
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => PageInputDialog(
        totalPages: widget.book.pageCount,
        initialPage: widget.book.pageRead,
      ),
    );

    if (result == null) {
      setState(() => _isProcessing = false);
      return;
    }

    final int? pageRead = result['page'] as int?;
    final bool isDone = result['done'] as bool;
    final String newCategory = isDone ? "done" : "reading";

    try {
      final booksProvider = Provider.of<SavedBooksProvider>(context, listen: false);

      // ✅ 타이머 로그 저장 (시작/종료/분)
      await ReadingLogService.saveTimerLog(
        bookId: widget.book.id,
        title: widget.book.title,
        startTime: _startTime,    // ← 카운트다운 이후 실제 시작시각
        endTime: endTime,
        durationMinutes: durationMinutes,
      );

      if (!mounted) return;

      // ✅ 책 정보 업데이트
      await booksProvider.addOrUpdateBook(
        widget.book.copyWith(
          category: newCategory,
          startDate: widget.book.startDate ?? _startTime,
          endDate: isDone ? DateTime.now() : null,
          readDate: isDone ? DateTime.now() : null,
          pageRead: pageRead ?? widget.book.pageRead,
        ),
      );

      // ✅ 챌린지 상태 리프레시
      final challengeProvider = Provider.of<ChallengeProvider>(context, listen: false);
      final savedBooks = booksProvider.savedBooks;
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      await challengeProvider.refreshAllStatuses(
        savedBooks: savedBooks,
        userId: userId,
      );

      if (!mounted) return;

      setState(() => _isProcessing = false);

      // ✅ 축하 다이얼로그 (원래처럼 1.5초 뒤 닫힘)
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
          });

          return AlertDialog(
            backgroundColor: Colors.greenAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  // (선택) 기존에 있던 카테고리/기간 입력 다이얼로그 – 원본 유지
  Future<Map<String, dynamic>?> _showCategoryAndDateDialog() async {
    final category = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("독서 기간 선택",
            style: TextStyle(
                fontFamily: 'kopub',
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        content: const Text("책을 얼만큼 읽으셨나요?",
            style: TextStyle(
                fontFamily: 'kopub',
                color: Colors.white70,
                fontSize: 15,
                height: 1.4)),
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

  // --- UI --------------------------------------------------------------------

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
            child: Center(
              child: _showCountdown
                  ? Text(
                '$_countdown',
                style: const TextStyle(
                  fontSize: 100,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              )
                  : _buildTimerContent(screenWidth),
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
  }

  Widget _buildTimerContent(double screenWidth) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _formatTime(_seconds),
          style: TextStyle(
            fontSize: screenWidth * 0.22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 40),
        _buildControlButtons(screenWidth),
      ],
    );
  }

  Widget _buildControlButtons(double screenWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _isPaused
          ? [
        _buildStyledButton("계속", Colors.amberAccent, _togglePause, screenWidth),
        const SizedBox(width: 16),
        _buildStyledButton("종료", Colors.redAccent, _stopTimer, screenWidth),
      ]
          : [
        _buildStyledButton("일시정지", Colors.white70, _togglePause, screenWidth),
      ],
    );
  }

  Widget _buildStyledButton(
      String text, Color color, VoidCallback onPressed, double screenWidth) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.black,
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.06,
          vertical: screenWidth * 0.03,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 6,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: screenWidth * 0.045,
          fontWeight: FontWeight.bold,
          fontFamily: 'kopub',
        ),
      ),
    );
  }
}