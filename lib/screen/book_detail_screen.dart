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
import 'package:dayverse_book/service/reading_log_service.dart';
import 'package:dayverse_book/widget/card_box.dart';
import 'package:dayverse_book/screen/share_note_screen.dart';
import 'package:dayverse_book/widget/share_book_sheet.dart';
import 'package:dayverse_book/screen/memo_edit_screen.dart';
import 'package:dayverse_book/model/memo_model.dart';

class BookDetailScreen extends StatefulWidget {
  final BookModel book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  bool _deletedHere = false;
  bool _handledMissing = false;
  bool _isSavingPage = false;
  int? _lastSavedPageValue;
  bool _skipNextFocusSave = false;

  final TextEditingController _pageController = TextEditingController();
  final FocusNode _pageFocusNode = FocusNode();

  final TextEditingController _memoSearchController =
  TextEditingController();

  String _memoSearchQuery = '';
  bool _isDeletingMemo = false;

  String? _pageControllerBookId;
  int? _pageOriginalValue; // 편집 시작 시 원본 저장
  late Future<int> _totalReadingMinutesFuture;

  @override
  void initState() {
    super.initState();

    _totalReadingMinutesFuture = _loadTotalReadingMinutes(widget.book.id);

    _pageFocusNode.addListener(() {
      if (!mounted) return;

      setState(() {});

      if (!_pageFocusNode.hasFocus) {
        if (_skipNextFocusSave) {
          _skipNextFocusSave = false;
          return;
        }

        final provider = context.read<SavedBooksProvider>();
        final book = provider.getBookByIdOrNull(widget.book.id);

        if (book != null && book.category == "reading") {
          _savePageRead(book, provider);
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pageFocusNode.dispose();
    _memoSearchController.dispose();
    super.dispose();
  }

  int _maxPage(BookModel book) {
    final pc = book.pageCount;
    return (pc > 0) ? pc : 0;
  }

  void _syncPageController(BookModel book) {
    if (_pageControllerBookId != book.id) {
      _pageControllerBookId = book.id;
      _pageController.text = book.pageRead.toString();
      return;
    }

    // 같은 책이어도, 입력 중이 아니면 provider 값으로 동기화
    if (!_pageFocusNode.hasFocus) {
      _pageController.text = book.pageRead.toString();
    }
  }

  void _showErrorRangeSnack(int max) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("1 ~ $max 사이의 값만 입력할 수 있어요."),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showSavedSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("저장되었습니다."),
        duration: Duration(milliseconds: 900),
      ),
    );
  }

  void _revertToOriginal(BookModel book) {
    final value = _pageOriginalValue ?? book.pageRead;
    _pageController.text = value.toString();
  }

  Future<void> _savePageRead(
      BookModel book, SavedBooksProvider provider) async {
    if (_isSavingPage) return;
    if (book.category != "reading") return;

    final messenger = ScaffoldMessenger.of(context);

    final max = _maxPage(book);
    if (max <= 0) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(
        content: Text("총 페이지 정보가 없어 저장할 수 없어요."),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    final raw = _pageController.text.trim();
    final parsed = int.tryParse(raw);

    if (parsed == null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(
        content: Text("숫자만 입력해주세요."),
        backgroundColor: Colors.redAccent,
      ));
      _revertToOriginal(book);
      FocusScope.of(context).unfocus();
      return;
    }

    final bool outOfRange = (parsed < 1 || parsed > max);
    final int clamped = parsed.clamp(1, max);

    // ✅ outOfRange면 저장하지 말고 경고만
    if (outOfRange) {
      _pageController.text = clamped.toString();
      messenger.hideCurrentSnackBar();
      _showErrorRangeSnack(max);
      FocusScope.of(context).unfocus();
      setState(() {});
      return;
    }

    // ✅ 값 동일이면 아무것도 안 함
    if (_lastSavedPageValue == clamped || book.pageRead == clamped) {
      FocusScope.of(context).unfocus();
      return;
    }

    _isSavingPage = true;
    try {
      provider.updatePageRead(book.id, clamped);
      _lastSavedPageValue = clamped;

      messenger.hideCurrentSnackBar();
      _showSavedSnack();

      FocusScope.of(context).unfocus();
      setState(() {});
    } finally {
      _isSavingPage = false;
    }
  }

  Future<int> _loadTotalReadingMinutes(String bookId) async {
    try {
      final logs = await ReadingLogService.getTimerLogsForBook(bookId);

      int totalMinutes = 0;

      for (final log in logs) {
        final rawMinutes = log['durationMinutes'];

        if (rawMinutes is int) {
          totalMinutes += rawMinutes;
        } else if (rawMinutes is num) {
          totalMinutes += rawMinutes.toInt();
        } else {
          totalMinutes += int.tryParse(rawMinutes?.toString() ?? '') ?? 0;
        }
      }

      return totalMinutes;
    } catch (e) {
      debugPrint('❌ 도서별 독서시간 불러오기 실패: $e');
      return 0;
    }
  }

  String _formatReadingTime(int totalMinutes) {
    if (totalMinutes < 60) {
      return '$totalMinutes분';
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (minutes == 0) {
      return '$hours시간';
    }

    return '$hours시간 $minutes분';
  }

  Future<void> _openMemoEditScreen(
      BookModel book, {
        MemoModel? memo,
      }) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MemoEditScreen(
          book: book,
          memo: memo,
          openedFromBookDetail: true,
        )
      ),
    );

    if (!mounted) return;

    if (saved == true) {
      setState(() {});
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final horizontalPadding = screenWidth * 0.04;
    final verticalSpacing = screenHeight * 0.01;

    final saved = context.watch<SavedBooksProvider>();
    final book = saved.getBookByIdOrNull(widget.book.id);

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
              MaterialPageRoute(
                  builder: (_) => const MainScreen(initialTabIndex: 1)),
            );
          }
        });
      }
      return const Scaffold(
        backgroundColor: Color(0xFF0A1D27),
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }


    return _keyboardDoneWrapper(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent, // ✅ 빈 공간 탭도 잡힘
        onTap: () => FocusScope.of(context).unfocus(), // ✅ 키보드 내림
        onHorizontalDragUpdate: (details) {
          if (details.delta.dx > 20) Navigator.pop(context);
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF013328),
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
              PopupMenuButton<String>(
                tooltip: '책 설정',
                color: const Color(0xFF1B2C2E),
                elevation: 10,
                offset: const Offset(0, 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
                icon: Container(
                  width: screenWidth * 0.085,
                  height: screenWidth * 0.085,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white70,
                    size: screenWidth * 0.05,
                  ),
                ),
                onSelected: (value) async {
                  if (value == 'refresh') {
                    final confirmed =
                    await _showRefreshBookConfirmDialog();

                    if (confirmed == true) {
                      await _refreshBookInfo();
                    }
                  } else if (value == 'delete') {
                    await _confirmDeleteBook(context);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'refresh',
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.025,
                      vertical: screenWidth * 0.008,
                    ),
                    child: _buildBookMenuItem(
                      icon: Icons.refresh_rounded,
                      title: '책 정보 다시 불러오기',
                      screenWidth: screenWidth,
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.025,
                      vertical: screenWidth * 0.008,
                    ),
                    child: _buildBookMenuItem(
                      icon: Icons.delete_outline_rounded,
                      title: '책 삭제',
                      screenWidth: screenWidth,
                      isDestructive: true,
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: screenWidth * 0.015,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding, vertical: verticalSpacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCoverSection(book, screenWidth),
                SizedBox(height: screenWidth * 0.03),
                _buildInfoSection(book, screenWidth),
                SizedBox(height: screenWidth * 0.03),
                _buildReadingStatusSection(book, screenWidth),
                SizedBox(height: screenWidth * 0.03),
                _buildMemoSection(context),
                SizedBox(height: screenWidth * 0.2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookMenuItem({
    required IconData icon,
    required String title,
    required double screenWidth,
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? Colors.redAccent
        : Colors.white;

    return Container(
      constraints: BoxConstraints(
        minWidth: screenWidth * 0.48,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.015,
        vertical: screenWidth * 0.018,
      ),
      child: Row(
        children: [
          Container(
            width: screenWidth * 0.08,
            height: screenWidth * 0.08,
            decoration: BoxDecoration(
              color: isDestructive
                  ? Colors.redAccent.withOpacity(0.12)
                  : Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isDestructive
                  ? Colors.redAccent
                  : Colors.white70,
              size: screenWidth * 0.043,
            ),
          ),
          SizedBox(
            width: screenWidth * 0.025,
          ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: color,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.033,
                fontWeight: isDestructive
                    ? FontWeight.bold
                    : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showRefreshBookConfirmDialog() {
    return _showBookActionDialog(
      icon: Icons.refresh_rounded,
      title: '책 정보 다시 불러오기',
      message:
      '책 정보를 다시 불러올까요?\n책 제목, 저자, 이미지 등이 변경될 수 있어요.',
      confirmText: '다시 불러오기',
    );
  }

  Future<bool?> _showBookActionDialog({
    required IconData icon,
    required String title,
    required String message,
    required String confirmText,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (dialogContext) {
        final screenWidth =
            MediaQuery.of(dialogContext).size.width;

        final accentColor = isDestructive
            ? Colors.redAccent
            : Colors.amberAccent;

        return AlertDialog(
          backgroundColor: const Color(0xFF1B2C2E),
          elevation: 16,
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.08,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          contentPadding: EdgeInsets.fromLTRB(
            screenWidth * 0.05,
            screenWidth * 0.05,
            screenWidth * 0.05,
            screenWidth * 0.025,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: screenWidth * 0.14,
                height: screenWidth * 0.14,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: accentColor.withOpacity(0.25),
                  ),
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: screenWidth * 0.065,
                ),
              ),
              SizedBox(
                height: screenWidth * 0.035,
              ),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.043,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(
                height: screenWidth * 0.025,
              ),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.033,
                  height: 1.55,
                ),
              ),
            ],
          ),
          actionsPadding: EdgeInsets.fromLTRB(
            screenWidth * 0.04,
            screenWidth * 0.015,
            screenWidth * 0.04,
            screenWidth * 0.04,
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                        dialogContext,
                        true,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: isDestructive
                          ? Colors.white
                          : Colors.black,
                      elevation: 0,
                      minimumSize: Size(
                        0,
                        screenWidth * 0.12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      confirmText,
                      style: TextStyle(
                        fontFamily: 'kopub',
                        fontSize: screenWidth * 0.033,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: screenWidth * 0.025,
                ),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(
                        dialogContext,
                        false,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(
                        color: Colors.white.withOpacity(0.12),
                      ),
                      minimumSize: Size(
                        0,
                        screenWidth * 0.12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '취소',
                      style: TextStyle(
                        fontFamily: 'kopub',
                        fontSize: screenWidth * 0.033,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// 책 진행률
  Widget _buildProgressBar(BookModel book, double screenWidth) {
    final progress = book.progressRatio.clamp(0.0, 1.0);
    final percentText = "${book.progressPercent}%";

    return Row(
      children: [
        Expanded(
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
      itemBuilder: (context, _) => const Icon(
        Icons.star,
        color: Colors.amber,
      ),
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
  Future<void> _confirmDeleteBook(
      BuildContext context,
      ) async {
    final confirm =
    await _showBookActionDialog(
      icon: Icons.delete_outline_rounded,
      title: '책 삭제',
      message:
      '정말 이 책을 삭제할까요?\n책과 관련된 모든 기록이 함께 사라져요.',
      confirmText: '삭제',
      isDestructive: true,
    );

    if (confirm != true || !mounted) {
      return;
    }

    _deletedHere = true;

    final saved =
    context.read<SavedBooksProvider>();

    final libraryProvider =
    context.read<CustomLibraryProvider>();

    try {
      await saved.removeBook(
        widget.book.id,
        libraryProvider,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('삭제되었습니다.'),
          ),
        );

      final navigator = Navigator.of(context);

      if (navigator.canPop()) {
        navigator.pop();
      } else {
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => const MainScreen(
              initialTabIndex: 1,
            ),
          ),
        );
      }
    } catch (e) {
      _deletedHere = false;

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              '책을 삭제하지 못했습니다.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
    }
  }

  /// ✅ 책 표지 및 기본 정보 카드
  Widget _buildCoverSection(BookModel book, double screenWidth) {
    final imageWidth = screenWidth * 0.4;
    final imageHeight = imageWidth * 1.5;

    final highResImageUrl =
        (book.imageUrl ?? '').replaceAll('coversum', 'cover');

    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: screenWidth * 0.055,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: imageWidth,
                    height: imageHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: highResImageUrl.startsWith('http')
                          ? Image.network(
                              highResImageUrl,
                              width: imageWidth,
                              height: imageHeight,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _fallbackImage(screenWidth),
                            )
                          : _fallbackImage(screenWidth),
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.055),
                  Text(
                    book.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: screenWidth * 0.042,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'kopub',
                      height: 1.4,
                    ),
                  ),
                  if (book.author.trim().isNotEmpty) ...[
                    SizedBox(height: screenWidth * 0.018),
                    Text(
                      book.author,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: screenWidth * 0.034,
                        fontFamily: 'kopub',
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            top: screenWidth * 0.025,
            right: screenWidth * 0.025,
            child: Material(
              color: Colors.white.withOpacity(0.12),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  showBookShareSheet(
                    context: context,
                    book: book,
                  );
                },
                child: Padding(
                  padding: EdgeInsets.all(
                    screenWidth * 0.023,
                  ),
                  child: Icon(
                    Icons.ios_share_rounded,
                    color: Colors.white,
                    size: screenWidth * 0.05,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ 출판 정보 카드
  Widget _buildInfoSection(BookModel book, double screenWidth) {
    final isbn = book.isbn?.trim().isNotEmpty == true ? book.isbn! : '알 수 없음';

    final pageCount = book.pageCount > 0 ? '${book.pageCount}쪽' : '알 수 없음';

    final publisher =
        book.publisher?.trim().isNotEmpty == true ? book.publisher! : '알 수 없음';

    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: screenWidth * 0.085,
                height: screenWidth * 0.085,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white70,
                  size: screenWidth * 0.05,
                ),
              ),
              SizedBox(width: screenWidth * 0.025),
              Text(
                '책 정보',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: screenWidth * 0.04,
                  fontFamily: 'kopub',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: screenWidth * 0.04),
          _infoRow('출판사', publisher, screenWidth),
          _buildInfoDivider(screenWidth),
          _infoRow('ISBN', isbn, screenWidth),
          _buildInfoDivider(screenWidth),
          _infoRow('총 페이지', pageCount, screenWidth),
        ],
      ),
    );
  }

  Widget _buildInfoDivider(double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: screenWidth * 0.025,
      ),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Colors.white.withOpacity(0.06),
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value,
    double screenWidth,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: screenWidth * 0.22,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white54,
              fontSize: screenWidth * 0.032,
              fontFamily: 'kopub',
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.white,
              fontSize: screenWidth * 0.032,
              fontFamily: 'kopub',
              fontWeight: FontWeight.w500,
            ),
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
    _syncPageController(book);
    final int pageMax = _maxPage(book);

    void _updateCategoryAndPage(String newCategory) {
      final now = DateTime.now();

      DateTime? newStartDate;
      DateTime? newEndDate;
      int newPage = book.pageRead;

      if (newCategory == "reading") {
        newStartDate = book.startDate ?? now;
        newEndDate = null;
        newPage =
            (book.pageRead > 0 && book.pageRead < (book.pageCount ?? 10000))
                ? book.pageRead
                : 1;
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
      provider.updateBookDates(book.id,
          startDate: newStartDate, endDate: newEndDate);
      provider.updatePageRead(book.id, newPage);

      book = provider.getBookById(book.id)!;
      _pageController.text = book.pageRead.toString();
      setState(() {});
    }

    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: screenWidth * 0.085,
                height: screenWidth * 0.085,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white70,
                  size: screenWidth * 0.05,
                ),
              ),
              SizedBox(width: screenWidth * 0.025),
              Expanded(
                child: Text(
                  '독서 상태',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.04,
                    fontFamily: 'kopub',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildReadingStatusButton(
                category: book.category,
                screenWidth: screenWidth,
                onChanged: (value) {
                  if (value != null && value != book.category) {
                    _updateCategoryAndPage(value);
                  }
                },
              ),
            ],
          ),
          SizedBox(height: screenWidth * 0.04),
          if (book.category == "reading") ...[
            _buildDateRow(
              "시작 날짜",
              book.startDate,
              isStartDate: true,
              bookId: book.id,
              currentStartDate: book.startDate,
              currentEndDate: book.endDate,
              provider: provider,
              screenWidth: screenWidth,
            ),
            SizedBox(height: screenWidth * 0.02),

            // ✅ 완료 날짜 자리(두번째 줄)에 '읽은 페이지'를 넣는다
            _buildPageReplaceRow(book, provider, screenWidth),
            SizedBox(height: screenWidth * 0.025),

            _buildReadingTimeRow(screenWidth),
            SizedBox(height: screenWidth * 0.03),
          ] else if (book.category == "done") ...[
            _buildDateRow(
              "시작 날짜",
              book.startDate,
              isStartDate: true,
              bookId: book.id,
              currentStartDate: book.startDate,
              currentEndDate: book.endDate,
              provider: provider,
              screenWidth: screenWidth,
            ),
            SizedBox(height: screenWidth * 0.025),
            _buildDateRow(
              "완료 날짜",
              book.endDate,
              isStartDate: false,
              minDate: book.startDate,
              bookId: book.id,
              currentStartDate: book.startDate,
              currentEndDate: book.endDate,
              provider: provider,
              screenWidth: screenWidth,
            ),
            SizedBox(height: screenWidth * 0.025),
            _buildReadingTimeRow(screenWidth),
            SizedBox(height: screenWidth * 0.03),
          ] else if (book.category == "want") ...[
            Padding(
              padding: EdgeInsets.only(top: screenWidth * 0.01),
              child: Center(
                child: Text(
                  "아직 읽기를 시작하지 않았어요.\n곧 책 속으로 떠나볼까요?",
                  style: TextStyle(
                    color: Colors.white54,
                    fontFamily: 'kopub',
                    fontSize: screenWidth * 0.035,
                  ),
                ),
              ),
            ),
            SizedBox(height: screenWidth * 0.03),
          ],
        ],
      ),
    );
  }

  Widget _buildReadingStatusButton({
    required String category,
    required double screenWidth,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: screenWidth * 0.085,
      decoration: BoxDecoration(
        color: Colors.amberAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amberAccent.withOpacity(0.35),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: category,
          isDense: true,
          dropdownColor: const Color(0xFF1B2C2E),
          borderRadius: BorderRadius.circular(14),
          icon: Padding(
            padding: EdgeInsets.only(
              right: screenWidth * 0.018,
            ),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.amberAccent,
              size: screenWidth * 0.042,
            ),
          ),
          selectedItemBuilder: (context) {
            return ['done', 'reading', 'want'].map((value) {
              return Padding(
                padding: EdgeInsets.only(
                  left: screenWidth * 0.03,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getReadingStatusIcon(value),
                      color: Colors.amberAccent,
                      size: screenWidth * 0.042,
                    ),
                    SizedBox(
                      width: screenWidth * 0.01,
                    ),
                    Text(
                      _getReadingStatusText(value),
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontFamily: 'kopub',
                        fontSize: screenWidth * 0.031,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList();
          },
          items: [
            _buildReadingStatusMenuItem(
              value: 'done',
              label: '읽은 책',
              icon: Icons.check_circle_outline_rounded,
              isSelected: category == 'done',
              screenWidth: screenWidth,
            ),
            _buildReadingStatusMenuItem(
              value: 'reading',
              label: '읽는 중',
              icon: Icons.menu_book_rounded,
              isSelected: category == 'reading',
              screenWidth: screenWidth,
            ),
            _buildReadingStatusMenuItem(
              value: 'want',
              label: '읽을 예정',
              icon: Icons.bookmark_border_rounded,
              isSelected: category == 'want',
              screenWidth: screenWidth,
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  DropdownMenuItem<String> _buildReadingStatusMenuItem({
    required String value,
    required String label,
    required IconData icon,
    required bool isSelected,
    required double screenWidth,
  }) {
    return DropdownMenuItem<String>(
      value: value,
      child: Container(
        constraints: BoxConstraints(
          minWidth: screenWidth * 0.31,
        ),
        padding: EdgeInsets.symmetric(
          vertical: screenWidth * 0.018,
        ),
        child: Row(
          children: [
            Container(
              width: screenWidth * 0.075,
              height: screenWidth * 0.075,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.amberAccent.withOpacity(0.14)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? Colors.amberAccent
                    : Colors.white60,
                size: screenWidth * 0.042,
              ),
            ),
            SizedBox(
              width: screenWidth * 0.025,
            ),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.amberAccent
                      : Colors.white,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.033,
                  fontWeight: isSelected
                      ? FontWeight.bold
                      : FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_rounded,
                color: Colors.amberAccent,
                size: screenWidth * 0.045,
              ),
          ],
        ),
      ),
    );
  }

  String _getReadingStatusText(
      String category,
      ) {
    switch (category) {
      case 'done':
        return '읽은 책';
      case 'reading':
        return '읽는 중';
      case 'want':
        return '읽을 예정';
      default:
        return '독서 상태';
    }
  }

  IconData _getReadingStatusIcon(
      String category,
      ) {
    switch (category) {
      case 'done':
        return Icons.check_circle_outline_rounded;
      case 'reading':
        return Icons.menu_book_rounded;
      case 'want':
        return Icons.bookmark_border_rounded;
      default:
        return Icons.auto_stories_rounded;
    }
  }

  Widget _buildPageReplaceRow(
      BookModel book, SavedBooksProvider provider, double screenWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "읽은 페이지",
          style: TextStyle(
            color: Colors.white54,
            fontFamily: 'kopub',
            fontSize: screenWidth * 0.034,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.edit,
              size: 16, // ✅ 달력 아이콘이랑 같은 급
              color:
                  _pageFocusNode.hasFocus ? Colors.amberAccent : Colors.white54,
            ),
            SizedBox(width: screenWidth * 0.01),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _pageFocusNode.requestFocus(),
              child: Container(
                width: screenWidth * 0.187,
                height: screenWidth * 0.06,
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.025),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(screenWidth * 0.02),
                  border: Border.all(
                    color: _pageFocusNode.hasFocus
                        ? Colors.amberAccent.withOpacity(0.65)
                        : Colors.white.withOpacity(0.12),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pageController,
                        focusNode: _pageFocusNode,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: screenWidth * 0.035,
                          fontFamily: 'kopub',
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: "0~${_maxPage(book)}",
                          hintStyle: TextStyle(
                            color: Colors.white30,
                            fontSize: screenWidth * 0.033,
                          ),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onTap: () => _pageOriginalValue = book.pageRead,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          _skipNextFocusSave = true;
                          _savePageRead(book, provider);
                        },
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.012),
                    Text(
                      "쪽",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: screenWidth * 0.034,
                        fontFamily: 'kopub',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _keyboardDoneWrapper({required Widget child}) {
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.of(context).viewInsets.bottom, // 키보드 바로 위
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: MediaQuery.of(context).viewInsets.bottom > 0 ? 44 : 0,
            color: const Color(0xFF1B2C2E),
            child: MediaQuery.of(context).viewInsets.bottom > 0
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          final provider = context.read<SavedBooksProvider>();
                          final book =
                              provider.getBookByIdOrNull(widget.book.id);
                          if (book != null) {
                            _skipNextFocusSave = true; // ✅ 추가
                            _savePageRead(book, provider);
                          }
                        },
                        child: const Text(
                          "완료",
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontFamily: 'kopub',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
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
            provider.updateBookDates(bookId,
                startDate: newStart, endDate: newEnd);
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

  Widget _buildReadingTimeRow(double screenWidth) {
    return FutureBuilder<int>(
      future: _totalReadingMinutesFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        final totalMinutes = snapshot.data ?? 0;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "읽은 시간",
              style: TextStyle(
                color: Colors.white54,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.034,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.schedule,
                  size: 16,
                  color: Colors.white54,
                ),
                SizedBox(width: screenWidth * 0.015),
                Text(
                  isLoading ? "불러오는 중" : _formatReadingTime(totalMinutes),
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'kopub',
                    fontSize: screenWidth * 0.035,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// 독서 메모
  Widget _buildMemoSection(
      BuildContext context,
      ) {
    final provider =
    context.watch<SavedBooksProvider>();

    final book =
    provider.getBookByIdOrNull(widget.book.id);

    if (book == null) {
      return const SizedBox.shrink();
    }

    final screenWidth =
        MediaQuery.of(context).size.width;

    final allMemos =
    provider.getMemosForBook(book.id);

    final normalizedQuery =
    _memoSearchQuery.trim().toLowerCase();

    final filteredMemos =
    normalizedQuery.isEmpty
        ? allMemos
        : allMemos.where((memo) {
      return memo.content
          .toLowerCase()
          .contains(normalizedQuery);
    }).toList();

    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(
        screenWidth * 0.04,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          _buildMemoHeader(
            book: book,
            memoCount: allMemos.length,
            screenWidth: screenWidth,
          ),

          if (allMemos.length >= 4) ...[
            SizedBox(
              height: screenWidth * 0.03,
            ),
            _buildMemoSearchField(
              screenWidth,
            ),
          ],

          SizedBox(
            height: screenWidth * 0.03,
          ),

          if (filteredMemos.isEmpty)
            _buildEmptyMemoPreview(
              book: book,
              screenWidth: screenWidth,
              hasSearchQuery:
              normalizedQuery.isNotEmpty,
            )
          else
            ...filteredMemos.map(
                  (memo) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom:
                    screenWidth * 0.025,
                  ),
                  child: _buildMemoCard(
                    book: book,
                    memo: memo,
                    screenWidth: screenWidth,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMemoHeader({
    required BookModel book,
    required int memoCount,
    required double screenWidth,
  }) {
    return Row(
      children: [
        Container(
          width: screenWidth * 0.085,
          height: screenWidth * 0.085,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius:
            BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.edit_note_rounded,
            color: Colors.white70,
            size: screenWidth * 0.055,
          ),
        ),

        SizedBox(
          width: screenWidth * 0.025,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                '독서 메모',
                style: TextStyle(
                  color: Colors.white,
                  fontSize:
                  screenWidth * 0.04,
                  fontFamily: 'kopub',
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              if (memoCount > 0) ...[
                SizedBox(
                  height:
                  screenWidth * 0.006,
                ),
                Text(
                  '$memoCount개의 메모',
                  style: TextStyle(
                    color: Colors.white38,
                    fontFamily: 'kopub',
                    fontSize:
                    screenWidth * 0.028,
                  ),
                ),
              ],
            ],
          ),
        ),

        Material(
          color: Colors.amberAccent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () {
              _openMemoEditScreen(book);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: screenWidth * 0.085,
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.03,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amberAccent.withOpacity(0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_rounded,
                    color: Colors.amberAccent,
                    size: screenWidth * 0.042,
                  ),
                  SizedBox(
                    width: screenWidth * 0.01,
                  ),
                  Text(
                    '메모 추가',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontSize: screenWidth * 0.031,
                      fontFamily: 'kopub',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMemoSearchField(
      double screenWidth,
      ) {
    return TextField(
      controller: _memoSearchController,
      onChanged: (value) {
        setState(() {
          _memoSearchQuery = value;
        });
      },
      style: TextStyle(
        color: Colors.white,
        fontFamily: 'kopub',
        fontSize: screenWidth * 0.034,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor:
        Colors.white.withOpacity(0.055),
        hintText: '메모 내용 검색',
        hintStyle: TextStyle(
          color: Colors.white38,
          fontFamily: 'kopub',
          fontSize:
          screenWidth * 0.032,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: Colors.white54,
        ),
        suffixIcon:
        _memoSearchQuery.isNotEmpty
            ? IconButton(
          onPressed: () {
            _memoSearchController
                .clear();

            setState(() {
              _memoSearchQuery = '';
            });
          },
          icon: const Icon(
            Icons.close_rounded,
            color: Colors.white54,
          ),
        )
            : null,
        border: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
        EdgeInsets.symmetric(
          vertical:
          screenWidth * 0.035,
        ),
      ),
    );
  }

  Widget _buildMemoCard({
    required BookModel book,
    required MemoModel memo,
    required double screenWidth,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.055),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          _openMemoEditScreen(
            book,
            memo: memo,
          );
        },
        child: Padding(
          padding: EdgeInsets.all(
            screenWidth * 0.035,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    color: Colors.white70,
                    size: screenWidth * 0.037,
                  ),

                  SizedBox(
                    width: screenWidth * 0.015,
                  ),

                  Text(
                    _formatMemoDate(
                      memo.createdAt,
                    ),
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'kopub',
                      fontSize: screenWidth * 0.029,
                      fontWeight: FontWeight.bold
                    ),
                  ),

                  const Spacer(),

                  Text(
                    '메모 열기',
                    style: TextStyle(
                      color: Colors.white38,
                      fontFamily: 'kopub',
                      fontSize:
                      screenWidth * 0.028,
                    ),
                  ),

                  SizedBox(
                    width: screenWidth * 0.005,
                  ),

                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white38,
                    size: screenWidth * 0.045,
                  ),
                ],
              ),

              if (memo.imageUrls.isNotEmpty) ...[
                SizedBox(
                  height: screenWidth * 0.02,
                ),

                Row(
                  children: [
                    Icon(
                      Icons.image_outlined,
                      color: Colors.white54,
                      size: screenWidth * 0.04,
                    ),

                    SizedBox(
                      width: screenWidth * 0.012,
                    ),

                    Text(
                      '이미지 ${memo.imageUrls.length}장',
                      style: TextStyle(
                        color: Colors.white54,
                        fontFamily: 'kopub',
                        fontSize:
                        screenWidth * 0.029,
                      ),
                    ),
                  ],
                ),
              ],

              if (memo.content.trim().isNotEmpty) ...[
                SizedBox(
                  height: screenWidth * 0.03,
                ),

                Text(
                  memo.content,
                  maxLines: 5,
                  overflow:
                  TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'kopub',
                    fontSize:
                    screenWidth * 0.035,
                    height: 1.6,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyMemoPreview({
    required BookModel book,
    required double screenWidth,
    bool hasSearchQuery = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenWidth * 0.065,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius:
        BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        children: [
          Icon(
            hasSearchQuery
                ? Icons.search_off_rounded
                : Icons.edit_note_rounded,
            color: Colors.white30,
            size: screenWidth * 0.075,
          ),

          SizedBox(
            height: screenWidth * 0.025,
          ),

          Text(
            hasSearchQuery
                ? '검색 결과가 없습니다.'
                : '아직 작성한 메모가 없습니다.',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'kopub',
              fontSize:
              screenWidth * 0.034,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(
            height: screenWidth * 0.012,
          ),

          Text(
            hasSearchQuery
                ? '다른 검색어로 다시 찾아보세요.'
                : '기억하고 싶은 문장과 생각을 남겨보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white38,
              fontFamily: 'kopub',
              fontSize:
              screenWidth * 0.03,
            ),
          ),

          if (!hasSearchQuery) ...[
            SizedBox(
              height: screenWidth * 0.035,
            ),


          ],
        ],
      ),
    );
  }

  String _formatMemoDate(
      DateTime date,
      ) {
    return '${date.year}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.day.toString().padLeft(2, '0')}';
  }

}
