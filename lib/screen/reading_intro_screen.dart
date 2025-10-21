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
import 'package:dayverse_book/widget/definded_book_selection.dart';
import 'package:flutter/cupertino.dart';

class ReadingIntroScreen extends StatefulWidget {
  final Challenge? challenge;       // ✅ 챌린지 정보
  final BookModel? initialBook;     // ✅ 초기 도서

  const ReadingIntroScreen({
    super.key,
    this.challenge,
    this.initialBook,
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
      final books = challenge!.requiredBooks ?? [];
      final selected = await showDialog<BookModel>(
        context: context,
        builder: (_) => DefinedBookSelection(
          books: challenge.requiredBooks ?? [],
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

    // 🔍 상세 정보 가져오기
    if (book.pageCount == 0 && book.itemId != null) {
      final detailed = await BookApiService.fetchBookDetail(book.itemId!);
      if (detailed != null) {
        book = detailed;
      }
    }

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

    return Scaffold(
      backgroundColor: const Color(0xFF0A1D27),
      bottomNavigationBar: _buildBottomNavBar(context),
      body: Stack(
        children: [
          SizedBox(
            height: screenHeight,
            width: screenWidth,
            child: Image.asset(
              'assets/image/diving.webp',
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
          SafeArea(
            child: Center(
              child: Column(
                children: [
                  SizedBox(height: screenHeight * 0.06),
                  _buildIntroTextSection(screenWidth),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: selectedBook == null ? _openBookSearchDialog : _startReading,
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: EdgeInsets.all(screenWidth * 0.08),
                      backgroundColor: Colors.white24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow, size: screenWidth * 0.1, color: Colors.amberAccent),
                        SizedBox(height: screenHeight * 0.005),
                        Text(
                          "시작",
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            color: Colors.amberAccent,
                            fontFamily: 'Kopub',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
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
        SizedBox(height: screenWidth * 0.02),
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
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "오늘의 독서 시간: ${todayMinutes}분",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'kopub',
              color: Colors.amberAccent,
            ),
          ),
        ),
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

  Widget _buildBox(double screenWidth, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: const BoxDecoration(
        color: Color(0xFF01241c),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(5, (index) {
          final icons = [
            Icons.home_filled,
            Icons.shelves,
            Icons.local_fire_department,
            Icons.bar_chart,
            Icons.menu,
          ];
          return _buildNavItem(context, icons[index], index);
        }),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, int index) {
    return GestureDetector(
      onTap: () {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => MainScreen(initialTabIndex: index)),
              (route) => false,
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: Colors.grey[500], size: 28),
      ),
    );
  }
}



// 🌿

