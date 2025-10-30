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

  int _countdown = 3;
  bool _showCountdown = true;

  // ✅ 벽시계 기반 필드들
  Timer? _ticker;                       // 화면을 1초마다 다시 그리는 용도(권위 아님)
  int _seconds = 0;                     // 표시용(항상 계산 결과를 넣음)
  bool _isPaused = false;

  late DateTime _effectiveStart;        // 카운트다운 종료 직후의 "진짜 시작 시간"
  Duration _pausedTotal = Duration.zero; // 누적 일시정지 시간
  DateTime? _pausedAt;                  // 일시정지 시작 시각

  bool _isProcessing = false;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _startCountdown();
  }

  void _startCountdown() {
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown == 1) {
        t.cancel();
        setState(() {
          _showCountdown = false;
        });
        _startSession();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  // ✅ 세션 시작: 기준시각을 "지금"으로, 일시정지 누적 0으로
  void _startSession() {
    _effectiveStart = DateTime.now();
    _pausedTotal = Duration.zero;
    _pausedAt = null;
    _isPaused = false;

    // 1초마다 화면만 갱신(권위는 _recomputeSeconds의 벽시계 계산)
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused) {
        _recomputeSeconds();
        setState(() {}); // _seconds 반영
      }
    });
  }

  // ✅ 벽시계 기준으로 경과 초를 재계산
  void _recomputeSeconds() {
    final now = DateTime.now();
    final pausedExtra = (_pausedAt != null)
        ? now.difference(_pausedAt!)               // 현재도 일시정지 중이면 그 시간까지 포함
        : Duration.zero;

    final elapsed = now.difference(_effectiveStart)
        - _pausedTotal
        - pausedExtra;

    _seconds = elapsed.isNegative ? 0 : elapsed.inSeconds;
  }

  void _togglePause() {
    final now = DateTime.now();

    if (_isPaused) {
      // ▶️ 재개: 방금까지의 정지시간을 누적
      if (_pausedAt != null) {
        _pausedTotal += now.difference(_pausedAt!);
        _pausedAt = null;
      }
      _isPaused = false;
      _recomputeSeconds();
      setState(() {});
    } else {
      // ⏸️ 일시정지 시작
      _recomputeSeconds(); // 정지 직전까지 초를 확정
      _pausedAt = now;
      _isPaused = true;
      setState(() {});
    }
  }

  Future<void> _stopTimer() async {
    setState(() => _isProcessing = true);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            backgroundColor: const Color(0xFF1B2C2E),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text("독서를 마치시겠어요?",
                style: TextStyle(fontFamily: 'kopub',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white)),
            content: const Text("지금까지의 시간을 저장합니다.\n단, 1분 이상 독서해야 기록이 저장됩니다.",
                style: TextStyle(fontFamily: 'kopub',
                    fontSize: 15,
                    height: 1.4,
                    color: Colors.white70)),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(true),
                  child: const Text("확인", style: TextStyle(fontFamily: 'kopub',
                      fontWeight: FontWeight.bold,
                      color: Colors.amberAccent))),
              TextButton(onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("취소", style: TextStyle(fontFamily: 'kopub',
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent))),
            ],
          ),
    );

    if (confirmed != true) {
      setState(() => _isProcessing = false);
      return;
    }

    _ticker?.cancel();

    // ✅ 종료 직전에 최종 재계산(정확한 경과 보장)
    _recomputeSeconds();
    final endTime = DateTime.now();
    final durationMinutes = (_seconds / 60).round();

    if (_seconds < 60) {
      setState(() => _isProcessing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⏱ 1분 이상 독서해야 기록이 저장됩니다."),
            backgroundColor: Colors.redAccent, duration: Duration(seconds: 2)),
      );
      Navigator.of(context).pop();
      return;
    }
  }

  Future<Map<String, dynamic>?> _showCategoryAndDateDialog() async {
    final category = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("독서 기간 선택", style: TextStyle(fontFamily: 'kopub', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        content: const Text("책을 얼만큼 읽으셨나요?", style: TextStyle(fontFamily: 'kopub', color: Colors.white70,fontSize: 15, height: 1.4)),
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
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$mm:$ss";
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  // ✅ 앱 라이프사이클 변화 시 표시값을 즉시 보정
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 복귀했을 때 즉시 재계산해 반영
    if (state == AppLifecycleState.resumed && !_showCountdown) {
      _recomputeSeconds();
      setState(() {});
    }
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
          if (_isProcessing) // ✅ 로딩 인디케이터 표시
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
            fontSize: screenWidth * 0.22, // 반응형
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

  Widget _buildStyledButton(String text, Color color, VoidCallback onPressed, double screenWidth) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.black,
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.06, // 반응형
          vertical: screenWidth * 0.03, // 반응형
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 6,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: screenWidth * 0.045, // 반응형
          fontWeight: FontWeight.bold,
          fontFamily: 'kopub',
        ),
      ),
    );
  }

}
