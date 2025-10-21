import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/service/reading_log_service.dart';
import 'package:dayverse_book/service/challenge_record_service.dart';
import 'package:dayverse_book/service/book_api_service.dart';
import 'package:dayverse_book/utils/book_utils.dart';
import 'package:dayverse_book/utils/challenge_check_utils.dart';
import 'package:dayverse_book/widget/book_search_dialog.dart';
import 'package:dayverse_book/widget/page_input_dialog.dart';
import 'package:dayverse_book/old(250705)/(old)fixed_book_selection_dialog.dart';

class ChallengeActionScreen extends StatefulWidget {
  final Challenge challenge;
  final ChallengeCheckActionType checkType;
  final Function(int minutes) onSuccess;

  const ChallengeActionScreen({
    super.key,
    required this.challenge,
    required this.checkType,
    required this.onSuccess,
  });

  @override
  State<ChallengeActionScreen> createState() => _ChallengeActionScreenState();
}

class _ChallengeActionScreenState extends State<ChallengeActionScreen> {
  int _countdown = 3;
  bool _showCountdown = true;
  Timer? _timer;
  int _seconds = 0;
  bool _isPaused = false;
  late DateTime _startTime;
  BookModel? _selectedBook;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showBookSelectionDialog();
    });
  }

  void _startCountdown() {
    _startTime = DateTime.now();
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 1) {
        timer.cancel();
        setState(() => _showCountdown = false);
        _startTimer();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _startTimer() {
    if (_timer != null && _timer!.isActive) return;
    _isPaused = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) setState(() => _seconds++);
    });
  }

  void _togglePause() => setState(() => _isPaused = !_isPaused);

  void _stopTimer() async {
    _timer?.cancel();
    final now = DateTime.now();
    final timerMinutes = (_seconds / 60).floor();
    final requiredMinutes = widget.challenge.requiredMinutes ?? 1;

    final todayMinutes = await ReadingLogService.getTodayTotalMinutes();
    final remainingMinutes = requiredMinutes - todayMinutes;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _buildConfirmDialog(remainingMinutes),
    );

    if (confirm != true) {
      _startTimer();
      return;
    }

    final selectedPage = await showDialog<int?>(
      context: context,
      builder: (_) => PageInputDialog(
        totalPages: _selectedBook?.pageCount ?? 1000,
        initialPage: _selectedBook?.pageRead ?? 0,
        onConfirm: (page, isDone) => Navigator.of(context).pop(page), // ✅ 에러 해결
      ),
    );

    if (selectedPage == null) {
      _startTimer();
      return;
    }

    if (_selectedBook != null) {
      await Provider.of<SavedBooksProvider>(context, listen: false)
          .updatePageReadAndCategory(_selectedBook!.id, selectedPage, _selectedBook!.category, );
    }

    if (_selectedBook != null && _seconds >= 60) {
      await ReadingLogService.saveTimerLog(
        bookId: _selectedBook!.id,
        title: _selectedBook!.title,
        startTime: _startTime,
        endTime: now,
        durationMinutes: timerMinutes,
      );
    }

    final checkAction = getChallengeCheckActionType(widget.challenge);
    if (checkAction == ChallengeCheckActionType.pageAuto ||
        checkAction == ChallengeCheckActionType.timerAuto) {
      await _handleCheckSuccess(timerMinutes);
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _handleCheckSuccess(int minutes) async {
    final now = DateTime.now();

    // ✅ 1분 이상 읽었을 때만 타이머 로그 저장
    if (_selectedBook != null && minutes >= 1) {
      await ReadingLogService.saveTimerLog(
        bookId: _selectedBook!.id,
        title: _selectedBook!.title,
        startTime: _startTime,
        endTime: now,
        durationMinutes: minutes,
      );
    }

    // ✅ provider 인스턴스 준비
    final savedBooksProvider = Provider.of<SavedBooksProvider>(context, listen: false);
    final challengeProvider = Provider.of<ChallengeProvider>(context, listen: false);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // ✅ Firestore의 최신 savedBooks
    final savedBooks = savedBooksProvider.savedBooks;

    // ✅ 챌린지 상태 갱신 (리팩토링된 시그니처에 맞게)
    await challengeProvider.refreshChallengeStatus(
      widget.challenge.id,
      savedBooks: savedBooks,
      userId: userId,
    );

    if (!mounted) return;

    // ✅ 성공 다이얼로그 표시
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          Navigator.of(dialogContext, rootNavigator: true).maybePop();
        });
        return _buildSuccessDialog();
      },
    );

    // ✅ Firestore에서 최신 책 데이터 다시 로드
    await savedBooksProvider.reloadFromFirestore();

    // ✅ 화면 닫기
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _showBookSelectionDialog() async {
    final provider = Provider.of<SavedBooksProvider>(context, listen: false);
    final books = provider.savedBooks;

    BookModel? selected;

    if (widget.challenge.method == ChallengeMethod.specificBooks &&
        widget.challenge.specificBookMode == SpecificBookMode.userDefined) {
      final filteredBooks = widget.challenge.participatingBooks ?? [];

      if (filteredBooks.isEmpty) {
        Navigator.of(context).pop();
        return;
      }

      if (filteredBooks.length == 1) {
        selected = filteredBooks.first;
      } else {
        selected = await showDialog<BookModel>(
          context: context,
          barrierDismissible: true,
          builder: (_) => FixedBookSelectionDialog(
            books: filteredBooks,
            onBookSelected: (book) => Navigator.of(context).pop(book),
          ),
        );
      }
    } else {
      selected = await showDialog<BookModel>(
        context: context,
        barrierDismissible: true,
        builder: (_) => const BookSearchDialog(),
      );
    }

    if (selected == null) {
      Navigator.of(context).pop();
      return;
    }

    BookModel detailedBook = selected;

    if (selected.pageCount == 0 && selected.itemId != null) {
      final fetched = await BookApiService.fetchBookDetail(selected.itemId!);
      if (fetched != null && fetched.pageCount > 0) {
        detailedBook = fetched;
      }
    }

    _selectedBook = detailedBook;

    if (!books.any((b) => b.id == detailedBook.id)) {
      await provider.addOrUpdateBook(detailedBook);
    }

    setState(() {});
    _startCountdown();
  }

  Widget _buildConfirmDialog(int remainingMinutes) {
    return AlertDialog(
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
      content: Text(
        remainingMinutes <= 0
            ? "오늘의 챌린지 목표를 달성하셨습니다! 🎉"
            : "이 챌린지는 ${remainingMinutes}분 이상 읽었다면 성공해요!\n읽은 시간은 1분 이상부터 저장됩니다.\n저장하시겠어요?",
        style: const TextStyle(
          fontFamily: 'kopub',
          fontSize: 15,
          height: 1.4,
          color: Colors.white70,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text("확인", style: TextStyle(color: Colors.amberAccent)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text("취소", style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    );
  }

  AlertDialog _buildSuccessDialog() {
    final isRoutine = widget.challenge.category == ChallengeCategory.routine;

    return AlertDialog(
      backgroundColor: Colors.greenAccent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("✨", style: TextStyle(fontSize: 36)),
            const SizedBox(height: 12),
            Text(
              isRoutine
                  ? "오늘의 루틴 완료!\n꾸준함이 빛을 만듭니다 💪"
                  : "오늘도 완료!\n꾸준함이 빛을 만듭니다 💪",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Kopub',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text("응원합니다 🌟", textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final d = Duration(seconds: seconds);
    return '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 20) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1D27),
        body: Stack(
          children: [
            SizedBox.expand(
              child: Image.asset('assets/image/dive_in.jpg', fit: BoxFit.cover),
            ),
            SafeArea(
              child: Center(
                child: _showCountdown
                    ? Text('$_countdown',
                    style: const TextStyle(
                        fontSize: 100,
                        fontWeight: FontWeight.bold,
                        color: Colors.white))
                    : _buildTimerSection(screenWidth),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerSection(double screenWidth) {
    return SizedBox(
      width: screenWidth * 0.7,
      height: screenWidth * 0.7,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTime(_seconds),
            style: const TextStyle(
              fontSize: 96,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          _buildControlButtons(),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _isPaused
          ? [
        _buildStyledButton("계속", Colors.amberAccent, _togglePause),
        const SizedBox(width: 16),
        _buildStyledButton("종료", Colors.redAccent, _stopTimer),
      ]
          : [
        _buildStyledButton("일시정지", Colors.white70, _togglePause),
      ],
    );
  }

  Widget _buildStyledButton(String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 6,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'kopub',
        ),
      ),
    );
  }
}
