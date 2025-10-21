import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/main.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/provider/custom_library_provider.dart';
import 'package:dayverse_book/widget/calendar_widget.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:dayverse_book/service/book_api_service.dart';


class BookDetailScreen extends StatefulWidget {
  final BookModel book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {

  bool _deletedHere = false;
  bool _handledMissing = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final horizontalPadding = screenWidth * 0.04;
    final verticalSpacing = screenHeight * 0.01;

    final saved = context.watch<SavedBooksProvider>();
    final book  = saved.getBookByIdOrNull(widget.book.id);

    if (book == null) {
      if (!_handledMissing) {
        _handledMissing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          // ✅ 내가 여기서 삭제한 경우엔 스낵바 생략
          if (!_deletedHere) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('이미 삭제된 책입니다.')),
            );
          }

          final nav = Navigator.of(context);
          if (nav.canPop()) {
            nav.pop();
          } else {
            nav.pushReplacement(
              MaterialPageRoute(builder: (_) => const MainScreen(initialTabIndex: 1)),
            );
          }
        });
      }
      return const Scaffold(
        backgroundColor: Color(0xFF0A1D27),
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final records = saved.getRecordsForBook(book.id);

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 20) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1D27),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: (book.category == "done")
              ? _buildRatingBar(book, screenWidth)
              : _buildProgressBar(book, screenWidth),
          actions: [
            PopupMenuTheme(
              data: PopupMenuThemeData(
                color: Colors.grey[850], // 원하는 배경색
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(color: Colors.white, fontFamily: 'kopub'),
              ),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) async {
                  if (value == 'delete') {
                    _confirmDeleteBook(context);
                  } else if (value == 'refresh') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: const Color(0xFF1B2C2E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text("책 정보 다시 불러오기", style: TextStyle(fontFamily: 'kopub', color: Colors.white, fontWeight: FontWeight.bold)),
                        content: const Text("책 정보를 다시 불러올까요?\n책 제목, 저자, 이미지 등이 변경될 수 있어요.",
                            style: TextStyle(fontFamily: 'kopub', color: Colors.white, fontSize: 15)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text("확인", style: TextStyle(color: Colors.redAccent)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text("취소"),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      _refreshBookInfo();
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'refresh',
                    child: Text('책 정보 다시 불러오기', style: TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('책 삭제', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalSpacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCoverSection(book, screenWidth),
              SizedBox(height: screenWidth * 0.025),
              _buildInfoSection(book, screenWidth),
              const Divider(color: Colors.white38, thickness: 1, height: 30),
              //_buildProgressBarSection(book, screenWidth),
              //SizedBox(height: screenWidth * 0.015),
              _buildReadingStatusSection(book, screenWidth),
              SizedBox(height: screenWidth * 0.03),
              _buildMemoSection(context),
              SizedBox(height: screenWidth * 0.1),
            ],
          ),
        ),
      ),
    );
  }

  /// 책 진행률
  Widget _buildProgressBar(BookModel book, double screenWidth) {
    final progress = book.progressRatio.clamp(0.0, 1.0);
    final percentText = "${book.progressPercent}%";

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: screenWidth * 0.6,
          child: LinearProgressIndicator(
            borderRadius: BorderRadius.circular(screenWidth * 0.04),
            value: progress,
            minHeight: screenWidth * 0.02,
            backgroundColor: Colors.white30,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
          ),
        ),
        SizedBox(width: screenWidth * 0.025),
        Text(
          percentText,
          style: TextStyle(
            color: Colors.white,
            fontSize: screenWidth * 0.035,
            fontFamily: 'kopub',
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// 별점
  Widget _buildRatingBar(BookModel book, double screenWidth) {
    final provider = Provider.of<SavedBooksProvider>(context, listen: false);

    if (book.rating == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.updateBookRating(book.id, 0.0);
        setState(() {});
      });
    }

    return RatingBar.builder(
      initialRating: book.rating ?? 0.0,
      minRating: 0,
      direction: Axis.horizontal,
      allowHalfRating: true,
      itemCount: 5,
      itemSize: screenWidth * 0.06, // 예: 28 → 반응형
      unratedColor: Colors.white30,
      itemPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
      itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber,),
      onRatingUpdate: (rating) {
        provider.updateBookRating(book.id, rating);
        setState(() {});
      },
    );
  }

  /// 책 정보 다시 불러오기
  Future<void> _refreshBookInfo() async {
    final savedProvider = context.read<SavedBooksProvider>();
    final book = savedProvider.getBookByIdOrNull(widget.book.id);
    if (book == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("이미 삭제된 책입니다.")),
      );
      return;
    }

    final isbn = book.isbn;
    if (isbn == null || isbn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ISBN이 없어 책 정보를 불러올 수 없어요")),
      );
      return;
    }

    BookModel? naverBook = await BookApiService.fetchBookFromNaver(isbn);
    if (naverBook == null) {
      final fallbackQuery = "${book.title} ${book.author}";
      naverBook = await BookApiService.fetchBookFromNaver(fallbackQuery);
    }

    if (naverBook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("책 정보를 불러오지 못했어요")),
      );
      return;
    }

    BookModel? aladinBook = await BookApiService.fetchBookDetailByIsbn(isbn);
    final int pageCount = aladinBook?.pageCount ?? 0;

    // pageCount만 덮어쓰기
    final updated = book.copyWith(
      title: naverBook.title,
      author: naverBook.author,
      publisher: naverBook.publisher,
      description: naverBook.description,
      imageUrl: naverBook.imageUrl,
      pageCount: pageCount > 0 ? pageCount : book.pageCount,
    );

    await savedProvider.addOrUpdateBook(updated);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("책 정보가 업데이트되었어요")),
    );

    setState(() {});
  }

  /// 책 삭제
  Future<void> _confirmDeleteBook(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("책 삭제",
            style: TextStyle(fontFamily: 'kopub', color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          "정말 이 책을 삭제할까요?\n책과 관련된 모든 기록이 사라져요!",
          style: TextStyle(fontFamily: 'kopub', color: Colors.white, fontSize: 16),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(true),  child: const Text("삭제", style: TextStyle(color: Colors.redAccent))),
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("취소")),
        ],
      ),
    );

    if (confirm == true) {
      _deletedHere = true;
      final saved = context.read<SavedBooksProvider>();
      final lib   = context.read<CustomLibraryProvider>();

      // 스낵바 먼저 (원한다면 navigatorKey 사용해서 루트에 띄울 수도 있음)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제되었습니다.')),
      );

      await saved.removeBook(widget.book.id, lib);

      if (!mounted) return;
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.pop();
      } else {
        nav.pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen(initialTabIndex: 1)),
        );
      }
    }
  }

  /// 책 표지
  Widget _buildCoverSection(BookModel book, double screenWidth) {
    final imageWidth = screenWidth * 0.4;
    final imageHeight = imageWidth * 1.3;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: screenWidth * 0.05,
        horizontal: screenWidth * 0.05,
      ),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
      ),
      child: Column(
        children: [
          SizedBox(height: screenWidth * 0.02),
          Container(
            padding: EdgeInsets.symmetric(
              vertical: screenWidth * 0.02,
            ),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(screenWidth * 0.03),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(screenWidth * 0.03),
              child: () {
                final highResImageUrl = (book.imageUrl ?? '').replaceAll('coversum', 'cover');
                return (highResImageUrl.startsWith("http"))
                    ? Image.network(
                  highResImageUrl,
                  width: imageWidth,
                  height: imageHeight,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => _fallbackImage(screenWidth),
                )
                    : _fallbackImage(screenWidth);
              }(),
            ),
          ),
          SizedBox(height: screenWidth * 0.04),
          Text(
            book.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              fontWeight: FontWeight.bold,
              fontFamily: 'kopub',
              color: Colors.white,
            ),
          ),
          if (book.author.isNotEmpty)
            Text(
              book.author,
              style: TextStyle(
                fontSize: screenWidth * 0.035,
                fontFamily: 'kopub',
                color: Colors.white70,
              ),
            ),
        ],
      ),
    );
  }

  /// 책 정보
  Widget _buildInfoSection(BookModel book, double screenWidth) {
    final isbn = (book.isbn?.isNotEmpty == true) ? book.isbn! : "알 수 없음";
    final pageCount = (book.pageCount > 0) ? "${book.pageCount}쪽" : "알 수 없음";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: screenWidth * 0.04,
            horizontal: screenWidth * 0.05,
          ),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(screenWidth * 0.03),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow("출판사", book.publisher ?? '-', screenWidth),
              SizedBox(height: screenWidth * 0.02),
              _infoRow("ISBN", isbn, screenWidth),
              SizedBox(height: screenWidth * 0.02),
              _infoRow("총 페이지", pageCount, screenWidth),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value, double screenWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: screenWidth * 0.03,
            color: Colors.white70,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: screenWidth * 0.03,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _fallbackImage(double screenWidth) {
    return Container(
      width: screenWidth * 0.4,
      height: screenWidth * 0.55,
      color: Colors.grey,
      child: const Icon(Icons.book, color: Colors.white, size: 40),
    );
  }

  /// 독서 상태
  Widget _buildReadingStatusSection(BookModel initialBook, double screenWidth) {
    final provider = Provider.of<SavedBooksProvider>(context, listen: false);
    late BookModel book = provider.getBookById(initialBook.id)!;
    final TextEditingController _pageController = TextEditingController(text: book.pageRead.toString());
    final int pageMax = (book.pageCount ?? 1) - 1;

    void _updateCategoryAndPage(String newCategory) {
      final now = DateTime.now();

      DateTime? newStartDate;
      DateTime? newEndDate;
      int newPage = book.pageRead;

      if (newCategory == "reading") {
        newStartDate = book.startDate ?? now;
        newEndDate = null;
        newPage = (book.pageRead > 0 && book.pageRead < (book.pageCount ?? 10000)) ? book.pageRead : 1;
      } else if (newCategory == "done") {
        newStartDate = book.startDate ?? now;
        newEndDate = book.endDate ?? now;
        newPage = book.pageCount ?? 0;
      } else if (newCategory == "want") {
        newStartDate = null;
        newEndDate = null;
        newPage = 0;
      }

      provider.updateCategory(book.id, newCategory);
      provider.updateBookDates(book.id, startDate: newStartDate, endDate: newEndDate);
      provider.updatePageRead(book.id, newPage);

      book = provider.getBookById(book.id)!;
      _pageController.text = book.pageRead.toString();
      setState(() {});
    }

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("독서 상태",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.04,
                    fontFamily: 'kopub',
                    fontWeight: FontWeight.bold,
                  )),
              DropdownButton<String>(
                dropdownColor: Colors.grey[850],
                value: book.category,
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.035,
                  fontWeight: FontWeight.bold,
                ),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.amberAccent),
                underline: Container(height: 0),
                borderRadius: BorderRadius.circular(12),
                items: const [
                  DropdownMenuItem(value: "done", child: Text("읽은 책")),
                  DropdownMenuItem(value: "reading", child: Text("읽는 중")),
                  DropdownMenuItem(value: "want", child: Text("읽을 예정")),
                ],
                onChanged: (value) {
                  if (value != null) _updateCategoryAndPage(value);
                },
              ),
            ],
          ),
          SizedBox(height: screenWidth * 0.04),

          if (book.category == "reading") ...[
            _buildDateRow("시작 날짜", book.startDate, isStartDate: true, bookId: book.id,
                currentStartDate: book.startDate, currentEndDate: book.endDate, provider: provider, screenWidth: screenWidth),
            SizedBox(height: screenWidth * 0.025),
          ] else if (book.category == "done") ...[
            _buildDateRow("시작 날짜", book.startDate, isStartDate: true, bookId: book.id,
                currentStartDate: book.startDate, currentEndDate: book.endDate, provider: provider, screenWidth: screenWidth),
            SizedBox(height: screenWidth * 0.025),
            _buildDateRow("완료 날짜", book.endDate, isStartDate: false, minDate: book.startDate, bookId: book.id,
                currentStartDate: book.startDate, currentEndDate: book.endDate, provider: provider, screenWidth: screenWidth),
            SizedBox(height: screenWidth * 0.03),
          ] else if (book.category == "want") ...[
            Padding(
              padding: EdgeInsets.only(top: screenWidth * 0.01),
              child: Center(
                child: Text(
                  "아직 읽기를 시작하지 않았어요. 곧 책 속으로 떠나볼까요?",
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontFamily: 'kopub',
                    fontSize: screenWidth * 0.035,
                  ),
                ),
              ),
            ),
            SizedBox(height: screenWidth * 0.03),
          ],

          if (book.category == "reading" || book.category == "done")
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("읽은 페이지 수",
                    style: TextStyle(
                      color: Colors.white54,
                      fontFamily: 'kopub',
                      fontSize: screenWidth * 0.034,
                    )),
                SizedBox(width: screenWidth * 0.03),
                Container(
                  width: screenWidth * 0.25,
                  height: screenWidth * 0.08,
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.025),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3E50),
                    borderRadius: BorderRadius.circular(screenWidth * 0.02),
                  ),
                  child: Center(
                    child: TextField(
                      controller: _pageController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth * 0.036,
                        fontFamily: 'kopub',
                      ),
                      enabled: book.category == "reading",
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '예: 120',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: screenWidth * 0.032),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (value) {
                        final parsed = int.tryParse(value);
                        if (parsed == null || parsed < 1 || parsed > pageMax) {
                          final clamped = parsed?.clamp(1, pageMax) ?? 1;
                          _pageController.text = clamped.toString();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("1 ~ $pageMax 사이의 값을 입력해주세요."),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          provider.updatePageRead(book.id, clamped);
                        } else {
                          provider.updatePageRead(book.id, parsed);
                        }
                        setState(() {});
                      },
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDateRow(
      String label,
      DateTime? date, {
        required bool isStartDate,
        DateTime? minDate,
        required String bookId,
        required DateTime? currentStartDate,
        required DateTime? currentEndDate,
        required SavedBooksProvider provider,
        required double screenWidth,
      }) {
    final dateText = date != null
        ? "${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}"
        : "미지정";

    return GestureDetector(
      onTap: () {
        showCalendarDialog(
          context: context,
          isStartDate: isStartDate,
          selectedDate: date ?? DateTime.now(),
          minDate: isStartDate ? DateTime(2000) : (minDate ?? DateTime(2000)),
          maxDate: DateTime.now(),
          onDatePicked: (picked) {
            final newStart = isStartDate ? picked : currentStartDate;
            final newEnd = isStartDate ? currentEndDate : picked;
            provider.updateBookDates(bookId, startDate: newStart, endDate: newEnd);
            setState(() {});
          },
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                color: Colors.white54,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.034,
              )),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.white54),
              SizedBox(width: screenWidth * 0.015),
              Text(dateText,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'kopub',
                    fontSize: screenWidth * 0.035,
                  )),
            ],
          ),
        ],
      ),
    );
  }


  /// 독서 메모
  Widget _buildMemoSection(BuildContext context) {
    final provider = Provider.of<SavedBooksProvider>(context);
    final bookId = widget.book.id;
    final screenWidth = MediaQuery.of(context).size.width;

    final List<Map<String, dynamic>> memos = provider.getRecordsForBook(bookId)
        .where((r) => r['content'] != '독서 타이머 기록')
        .toList();

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 메모 헤더 Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "독서 메모",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: screenWidth * 0.04,
                  fontFamily: 'kopub',
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => _showMemoBottomSheet(context, provider, bookId),
                child: Text(
                  "메모 추가",
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontSize: screenWidth * 0.035,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'kopub',
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: screenWidth * 0.02),

          /// 메모 리스트
          ...memos.map((memo) {
            final content = memo['content'];
            final savedAt = memo['savedAt'];
            final parsedDate = DateTime.tryParse(savedAt ?? '');
            final formatted = parsedDate != null
                ? "${parsedDate.year % 100}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.day.toString().padLeft(2, '0')}"
                : "";

            return Container(
              margin: EdgeInsets.symmetric(vertical: screenWidth * 0.015),
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.03,
                vertical: screenWidth * 0.025,
              ),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(screenWidth * 0.02),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 날짜 + 삭제 아이콘 Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      /// 날짜
                      Text(
                        formatted,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: screenWidth * 0.032,
                        ),
                      ),

                      /// 수정 + 삭제 아이콘 (붙여서)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              _showMemoBottomSheet(
                                context,
                                provider,
                                bookId,
                                isEdit: true,
                                originalMemo: memo,
                              );
                            },
                            child: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                          ),
                          const SizedBox(width: 10), // 진짜 최소 간격만
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E2A38),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  title: const Text(
                                    '메모 삭제',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  content: const Text(
                                    '이 메모를 삭제하시겠습니까?',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        provider.deleteRecord(bookId, savedAt, content);
                                        Navigator.of(context).pop(); // 다이얼로그 닫기
                                      },
                                      child: const Text("삭제", style: TextStyle(color: Colors.redAccent)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(), // 취소
                                      child: const Text("취소",),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: screenWidth * 0.015),
                  Text(
                    content,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Kopub',
                      fontSize: screenWidth * 0.035,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  void _showMemoBottomSheet(
      BuildContext context,
      SavedBooksProvider provider,
      String bookId, {
        bool isEdit = false,
        Map<String, dynamic>? originalMemo,
      }) {
    final TextEditingController _controller = TextEditingController(
      text: isEdit ? (originalMemo?['content'] ?? '') : '',
    );

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final formattedDate = isEdit
        ? DateFormat('yy/MM/dd').format(DateTime.parse(originalMemo?['savedAt']))
        : DateFormat('yy/MM/dd').format(DateTime.now());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // ✅ 외부에서 배경 제어
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: screenWidth * 0.03, // ✅ 양쪽 여백 추가 (전체 너비보다 살짝 좁게)
            right: screenWidth * 0.03,
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            height: screenHeight * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenWidth * 0.04,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// 날짜 + 확인 버튼
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        final text = _controller.text.trim();
                        if (text.isNotEmpty) {
                          if (isEdit && originalMemo != null) {
                            provider.deleteRecord(bookId, originalMemo['savedAt'], originalMemo['content']);
                            provider.addRecord(bookId, text);
                          } else {
                            provider.addRecord(bookId, text);
                          }
                        }
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        "확인",
                        style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                /// 메모 입력 영역
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    minLines: 10,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      height: 1.4,
                    ),
                    decoration: const InputDecoration(
                      hintText: "메모를 남겨보세요",
                      hintStyle: TextStyle(color: Colors.black38),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}


