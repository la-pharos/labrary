import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/main.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/screen/reading_running_screen.dart';
import 'package:dayverse_book/service/reading_log_service.dart';
import 'package:dayverse_book/service/book_api_service.dart';
import 'package:dayverse_book/utils/book_utils.dart';
import 'package:dayverse_book/utils/challenge_check_utils.dart';
import 'package:dayverse_book/widget/book_search_dialog.dart';
import 'package:dayverse_book/widget/challenge_book_selection_dialog.dart';
import 'package:flutter/cupertino.dart';

class ReadingIntroScreen extends StatefulWidget {
  final Challenge? challenge;       // ✅ 챌린지 정보
  final BookModel? initialBook;     // ✅ 초기 도서
  final List<BookModel>? candidateBooksOverride;

  const ReadingIntroScreen({
    super.key,
    this.challenge,
    this.initialBook,
    this.candidateBooksOverride, // ✅ 추가
  });

  @override
  State<ReadingIntroScreen> createState() => _ReadingIntroScreenState();
}

class _ReadingIntroScreenState extends State<ReadingIntroScreen> {
  BookModel? selectedBook;
  int todayMinutes = 0;
  bool _hasPrecached = false;


  @override
  void initState() {
    super.initState();
    selectedBook = widget.initialBook;
    _fetchTodayMinutes();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowAdminBookSelectionDialog();
    });
  }

  void _maybeShowAdminBookSelectionDialog() async {
    final challenge = widget.challenge;

    final isAdminDefinedPageAuto = challenge != null &&
        challenge.method == ChallengeMethod.specificBooks &&
        challenge.specificBookMode == SpecificBookMode.systemDefined &&
        getChallengeCheckActionType(challenge) == ChallengeCheckActionType.pageAuto;

    if (isAdminDefinedPageAuto && mounted && selectedBook == null) {
      // ✅ override > challenge.requiredBooks 순서로 후보 결정
      final List<BookModel> candidates =
      (widget.candidateBooksOverride != null && widget.candidateBooksOverride!.isNotEmpty)
          ? widget.candidateBooksOverride!
          : (challenge!.requiredBooks ?? const <BookModel>[]);

      if (candidates.isEmpty) return; // 풀 로드 실패 등 예외 시 조용히 종료(필요시 스낵바 넣어도 OK)

      final selected = await showDialog<BookModel>(
        context: context,
        builder: (_) => ChallengeBookSelectionDialog(
          books: candidates, // ✅ 여기만 변경
          savedBooks: context.read<SavedBooksProvider>().savedBooks,
        ),
      );

      if (selected != null && mounted) {
        setState(() {
          selectedBook = selected;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasPrecached) {
      precacheImage(const AssetImage('assets/image/diving.jpg'), context);
      _hasPrecached = true;
    }
  }

  Future<void> _fetchTodayMinutes() async {
    final dailyMap = await ReadingLogService.getTotalReadingMinutesByDate();
    final todayKey = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
    setState(() {
      todayMinutes = dailyMap[todayKey] ?? 0;
    });
  }

  void _openBookSearchDialog() async {
    final selected = await showDialog<BookModel>(
      context: context,
      builder: (_) => const BookSearchDialog(),
    );

    if (!mounted || selected == null) return;

    setState(() {
      selectedBook = selected;
    });
  }

  void _startReading() async {
    if (selectedBook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("읽을 책을 먼저 선택해주세요.")),
      );
      return;
    }

    BookModel book = selectedBook!;


    // 페이지수가 없다면 YES24 ISBN 상세 조회로 보완
    final isbn = book.isbn?.trim();

    if (book.pageCount <= 0 &&
        isbn != null &&
        isbn.replaceAll(RegExp(r'[^0-9Xx]'), '').length == 13) {
      try {
        final detailed =
        await BookApiService.fetchBookDetailByIsbn(isbn);

        if (detailed != null && detailed.pageCount > 0) {
          // 기존 도서 정보는 유지하고 페이지수만 갱신
          book = book.copyWith(
            pageCount: detailed.pageCount,
          );
        }
      } catch (e) {
        debugPrint('[독서 시작 페이지수 조회 실패] $e');
      }
    }

    if (!mounted) return;


    // 🟢 BookModel 보강 (startDate, category 등)
    book = book.copyWith(
      startDate: DateTime.now(),
      category: 'reading',
      customLibraries: [],
    );

    // RunningScreen에 보강된 book 넘기기
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingRunningScreen(book: book),
      ),
    );

    if (result == true) {
      _fetchTodayMinutes(); // 독서 후 오늘 시간 갱신
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity =
            details.primaryVelocity ?? 0;

        if (velocity > 500) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1D27),
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/image/diving.webp',
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),

            _buildBackButton(context),

            SafeArea(
              child: Center(
                child: Column(
                  children: [
                    SizedBox(height: screenHeight * 0.02),
                    _buildIntroTextSection(screenWidth),
                    const Spacer(),
                    _buildStartButton(
                      w: screenWidth,
                      h: screenHeight,
                      onTap: selectedBook == null ? _openBookSearchDialog : _startReading,
                    ),
                    SizedBox(height: screenHeight * 0.05),
                  ],
                ),
              ),
            ),
            if (selectedBook != null)
              Positioned(
                top: screenHeight * 0.25,
                left: 0,
                right: 0,
                child: Center(child: _buildBookInfoCard(selectedBook!, screenWidth)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroTextSection(double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "독서로 빠져볼까요?",
          style: TextStyle(
            fontSize: screenWidth * 0.055,
            fontWeight: FontWeight.bold,
            fontFamily: 'kopub',
            color: Colors.white,
            shadows: const [
              Shadow(color: Colors.black54, offset: Offset(0, 1), blurRadius: 2),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: screenWidth * 0.03),
        Text(
          "깊은 몰입을 위해 스마트폰은 잠시 멀리 두세요!",
          style: TextStyle(
            fontSize: screenWidth * 0.035,
            color: Colors.white70,
            fontFamily: 'kopub',
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: screenWidth * 0.04),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.06,
            vertical: screenWidth * 0.03,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.24),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withOpacity(0.10),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule_rounded,
                color: Colors.amberAccent,
                size: screenWidth * 0.038,
              ),
              SizedBox(
                width: screenWidth * 0.015,
              ),
              Text(
                '오늘 $todayMinutes분 읽었어요',
                style: TextStyle(
                  fontSize: screenWidth * 0.03,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'kopub',
                  color: Colors.amberAccent,
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildBookInfoCard(BookModel book, double screenWidth) {
    final imageUrl = book.imageUrl ?? '';
    final coverWidth = screenWidth * 0.35;
    final coverHeight = coverWidth * 1.5;

    final imageWidget = imageUrl.startsWith('http')
        ? Image.network(
      imageUrl,
      width: coverWidth,
      height: coverHeight,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(Icons.book, size: 60, color: Colors.white70),
    )
        : Image.asset(
      imageUrl,
      width: coverWidth,
      height: coverHeight,
      fit: BoxFit.cover,
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        _buildBox(
          screenWidth,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(12), child: imageWidget),
              const SizedBox(height: 10),
              SizedBox(
                width: screenWidth * 0.6,
                child: Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'kopub',
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: screenWidth * 0.6,
                child: Text(
                  book.author,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'kopub',
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          right: screenWidth * 0.13,
          child: GestureDetector(
            onTap: () => setState(() => selectedBook = null),
            child: Container(
              decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBox(
      double screenWidth,
      Widget child,
      ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        screenWidth * 0.04,
      ),
      margin: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.18,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildBackButton(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 12,
      left: 16,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.42),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStartButton({
    required double w,
    required double h,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // 기존 0.2 → 0.22로 사이즈만 확대
        width: w * 0.22,
        height: w * 0.22,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.22),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.85),
            width: 1.4,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selectedBook == null
                  ? Icons.auto_stories_outlined
                  : Icons.play_arrow_rounded,
              color: Colors.amberAccent,
              size: w * 0.075,
            ),
            SizedBox(
              height: h * 0.004,
            ),
            Text(
              selectedBook == null
                  ? "선택"
                  : "시작",
              style: TextStyle(
                fontSize: w * 0.032,
                color: Colors.amberAccent,
                fontFamily: 'Kopub',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

}



// 🌿

