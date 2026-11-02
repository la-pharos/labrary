import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/utils/book_utils.dart';
import 'package:dayverse_book/service/book_api_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:dayverse_book/widget/calendar_widget.dart';
import 'package:dayverse_book/widget/ad_banner_placeholder.dart';
import 'package:dayverse_book/widget/card_box.dart';
import 'package:dayverse_book/provider/custom_library_provider.dart';

class BookRegisterScreen extends StatefulWidget {
  final BookModel book;

  /// 읽은 책: done
  /// 읽는 중인 책: reading
  /// 읽을 예정인 책: want
  final String? initialCategory;

  /// 커스텀 서재에서 진입한 경우 해당 서재 이름
  final String? targetCustomLibrary;

  const BookRegisterScreen({
    super.key,
    required this.book,
    this.initialCategory,
    this.targetCustomLibrary,
  });

  @override
  State<BookRegisterScreen> createState() => _BookRegisterScreenState();
}

class _BookRegisterScreenState extends State<BookRegisterScreen> {
  late String selectedCategory;
  DateTime? startDate;
  DateTime? endDate;
  bool _isExpanded = false;
  late BookModel book;
  final TextEditingController _pageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    book = widget.book;
    selectedCategory = _resolveInitialCategory();
    startDate = book.startDate ?? DateTime.now();
    endDate = book.endDate ?? DateTime.now();

    final pageRead = book.pageRead ?? 1;
    final maxPage = book.pageCount ?? 9999;

    if (selectedCategory == 'want') {
      _pageController.text = '0';
    } else if (selectedCategory == 'done') {
      _pageController.text =
      (book.pageCount ?? 0) > 0
          ? book.pageCount.toString()
          : '1';
    } else {
      _pageController.text =
      (pageRead >= 1 && pageRead < maxPage)
          ? pageRead.toString()
          : '1';
    }

    if ((book.pageCount == null || book.pageCount == 0) && book.itemId != null) {
      _fetchPageCount();
    }
  }

  String _resolveInitialCategory() {
    const validCategories = {
      'done',
      'reading',
      'want',
    };

    final initialCategory = widget.initialCategory;

    if (initialCategory != null &&
        validCategories.contains(initialCategory)) {
      return initialCategory;
    }

    if (book.category != null &&
        validCategories.contains(book.category)) {
      return book.category!;
    }

    return 'done';
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }


  void _fetchPageCount() async {
    final isbn = book.isbn?.trim();

    // YES24 상세 조회는 ISBN13 기준
    if (isbn == null || isbn.replaceAll(RegExp(r'[^0-9Xx]'), '').length != 13) {
      return;
    }

    // 이미 페이지수가 있으면 재조회하지 않음
    if ((book.pageCount ?? 0) > 0) {
      return;
    }

    try {
      final fetched = await BookApiService.fetchBookDetailByIsbn(isbn);

      if (!mounted) return;

      if (fetched != null && (fetched.pageCount ?? 0) > 0) {
        setState(() {
          book = book.copyWith(
            pageCount: fetched.pageCount,
          );
        });
      }
    } catch (e) {
      debugPrint('[YES24 페이지수 조회 실패] $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final horizontalPadding = screenWidth * 0.04;
    final verticalSpacing = screenHeight * 0.01;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 10) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF013328),
        appBar: _buildAppBar(screenWidth),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalSpacing),
          child: Column(
            children: [
              _buildCoverSection(screenWidth),

              SizedBox(height: screenWidth * 0.03),

              _buildInfoSection(screenWidth),

              SizedBox(height: screenWidth * 0.03),

              _buildRegisterSection(screenWidth),

              SizedBox(height: screenHeight * 0.1),
            ],
          ),
        ),
      ),
    );
  }

  /// 0. 앱바
  PreferredSizeWidget _buildAppBar(double screenWidth) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: Text(
        "책 등록하기",
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'kopub',
          fontSize: screenWidth * 0.045, // 반응형
          fontWeight: FontWeight.bold,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        TextButton(
          onPressed: _saveBook,
          child: Text(
            "저장",
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.04, // 반응형
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(width: screenWidth * 0.02),
      ],
    );
  }

  /// 1. 책 표지 및 기본 정보 카드
  Widget _buildCoverSection(double screenWidth) {
    final imageWidth = screenWidth * 0.4;
    final imageHeight = imageWidth * 1.5;

    final imageUrl =
    (book.imageUrl ?? '').replaceAll('coversum', 'cover');

    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.05,
        vertical: screenWidth * 0.055,
      ),
      child: Column(
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
              child: imageUrl.startsWith('http')
                  ? Image.network(
                imageUrl,
                width: imageWidth,
                height: imageHeight,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return _buildFallbackCover(
                    imageWidth,
                    imageHeight,
                  );
                },
              )
                  : _buildFallbackCover(
                imageWidth,
                imageHeight,
              ),
            ),
          ),

          SizedBox(height: screenWidth * 0.055),

          Text(
            book.title ?? '',
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

          if ((book.author ?? '').trim().isNotEmpty) ...[
            SizedBox(height: screenWidth * 0.018),
            Text(
              book.author!,
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
    );
  }

  Widget _buildFallbackCover(
      double width,
      double height,
      ) {
    return Container(
      width: width,
      height: height,
      color: Colors.white.withOpacity(0.08),
      alignment: Alignment.center,
      child: const Icon(
        Icons.menu_book_rounded,
        color: Colors.white54,
        size: 42,
      ),
    );
  }

  /// 2. 책 정보 카드
  Widget _buildInfoSection(double screenWidth) {
    final description = (book.description ?? '').trim();
    final isLong = description.length > 80;

    final publisher =
    (book.publisher ?? '').trim().isNotEmpty
        ? book.publisher!
        : '알 수 없음';

    final isbn =
    (book.isbn ?? '').trim().isNotEmpty
        ? book.isbn!
        : '알 수 없음';

    final pageCount =
    (book.pageCount ?? 0) > 0
        ? '${book.pageCount}쪽'
        : '알 수 없음';

    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.info_outline_rounded,
            title: '책 정보',
            screenWidth: screenWidth,
          ),

          SizedBox(height: screenWidth * 0.04),

          _infoRow('출판사', publisher, screenWidth),
          _buildInnerDivider(screenWidth),

          _infoRow('ISBN', isbn, screenWidth),
          _buildInnerDivider(screenWidth),

          _infoRow('총 페이지', pageCount, screenWidth),

          if (description.isNotEmpty) ...[
            SizedBox(height: screenWidth * 0.04),

            Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withOpacity(0.06),
            ),

            SizedBox(height: screenWidth * 0.035),

            Text(
              '책 소개',
              style: TextStyle(
                color: Colors.white70,
                fontSize: screenWidth * 0.033,
                fontFamily: 'kopub',
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: screenWidth * 0.018),

            _buildExpandableDescription(
              description,
              isLong,
              screenWidth,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required double screenWidth,
  }) {
    return Row(
      children: [
        Container(
          width: screenWidth * 0.085,
          height: screenWidth * 0.085,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Colors.white70,
            size: screenWidth * 0.05,
          ),
        ),

        SizedBox(width: screenWidth * 0.025),

        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: screenWidth * 0.04,
            fontWeight: FontWeight.bold,
            fontFamily: 'kopub',
          ),
        ),
      ],
    );
  }

  Widget _buildInnerDivider(double screenWidth) {
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

  Widget _buildExpandableDescription(
      String description,
      bool isLong,
      double screenWidth,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          description,
          maxLines: _isExpanded ? null : 3,
          overflow:
          _isExpanded
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white70,
            fontSize: screenWidth * 0.032,
            fontFamily: 'kopub',
            height: 1.6,
          ),
        ),

        if (isLong)
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Text(
                _isExpanded ? '접기' : '더 보기',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: screenWidth * 0.031,
                  fontFamily: 'kopub',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 3. 책 등록 섹션 (카테고리 + 날짜 선택)
  /// ✅ 책 등록 설정 카드
  Widget _buildRegisterSection(double screenWidth) {
    final pageCount = book.pageCount ?? 0;

    // 총 페이지가 1 이하인 경우에도 입력 범위가 깨지지 않도록 처리
    final maxPage = pageCount > 1 ? pageCount - 1 : 1;

    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.library_add_outlined,
            title: '책 등록',
            screenWidth: screenWidth,
          ),

          SizedBox(height: screenWidth * 0.04),

          _buildCategorySelector(screenWidth),

          if (selectedCategory == 'done' ||
              selectedCategory == 'reading') ...[
            SizedBox(height: screenWidth * 0.04),

            if (selectedCategory == 'done')
              _buildDateSelector(screenWidth)
            else
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        showCalendarDialog(
                          context: context,
                          selectedDate:
                          startDate ?? DateTime.now(),
                          minDate: DateTime(2000),
                          maxDate: DateTime.now(),
                          onDatePicked: (picked) {
                            setState(() {
                              startDate = picked;
                            });
                          },
                          isStartDate: true,
                        );
                      },
                      child: _buildDateCard(
                        '시작일',
                        startDate ?? DateTime.now(),
                        screenWidth,
                      ),
                    ),
                  ),

                  SizedBox(width: screenWidth * 0.02),

                  Expanded(
                    child: _buildPageInputCard(
                      screenWidth,
                      maxPage,
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPageInputCard(
      double screenWidth,
      int maxPage,
      ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.025,
        vertical: screenWidth * 0.025,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '읽은 페이지',
            style: TextStyle(
              color: Colors.white60,
              fontSize: screenWidth * 0.032,
              fontFamily: 'kopub',
            ),
          ),

          SizedBox(height: screenWidth * 0.012),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: TextField(
                  controller: _pageController,
                  keyboardType: TextInputType.number,
                  maxLength: 5,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'kopub',
                    fontSize: screenWidth * 0.04,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '1',
                    hintStyle: TextStyle(
                      color: Colors.white30,
                      fontSize: screenWidth * 0.035,
                    ),
                    counterText: '',
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) {
                    final entered = int.tryParse(value);

                    if (entered != null &&
                        (entered < 1 || entered > maxPage)) {
                      final clamped =
                      entered.clamp(1, maxPage);

                      _pageController.text =
                          clamped.toString();

                      _pageController.selection =
                          TextSelection.fromPosition(
                            TextPosition(
                              offset:
                              _pageController.text.length,
                            ),
                          );

                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              '1 ~ $maxPage 사이의 숫자를 입력해주세요.',
                            ),
                            duration:
                            const Duration(seconds: 2),
                            backgroundColor:
                            Colors.redAccent,
                          ),
                        );
                    }
                  },
                ),
              ),

              Text(
                '쪽',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: screenWidth * 0.032,
                  fontFamily: 'kopub',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard(
      String label,
      DateTime date,
      double screenWidth,
      ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.025,
        vertical: screenWidth * 0.025,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white60,
              fontSize: screenWidth * 0.032,
              fontFamily: 'kopub',
            ),
          ),

          SizedBox(height: screenWidth * 0.015),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                color: Colors.white54,
                size: screenWidth * 0.038,
              ),

              SizedBox(width: screenWidth * 0.015),

              Text(
                DateFormat('yy/MM/dd').format(date),
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.037,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(double screenWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _categoryButton("읽은 책", "done", screenWidth),
        _categoryButton("읽는 중인 책", "reading", screenWidth),
        _categoryButton("읽을 예정인 책", "want", screenWidth),
      ],
    );
  }

  Widget _categoryButton(
      String title,
      String value,
      double screenWidth,
      ) {
    final isSelected = selectedCategory == value;

    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.008,
        ),
        child: Material(
          color: isSelected
              ? Colors.amberAccent
              : Colors.white.withOpacity(0.055),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () {
              setState(() {
                selectedCategory = value;

                final totalPage = book.pageCount ?? 0;

                if (value == 'want') {
                  _pageController.text = '0';
                } else if (value == 'done') {
                  _pageController.text =
                  totalPage > 0
                      ? totalPage.toString()
                      : '1';
                } else {
                  final currentPage =
                      int.tryParse(_pageController.text) ?? 1;

                  final maxReadingPage =
                  totalPage > 1
                      ? totalPage - 1
                      : 1;

                  _pageController.text = currentPage
                      .clamp(1, maxReadingPage)
                      .toString();
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: screenWidth * 0.03,
                horizontal: screenWidth * 0.01,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Colors.amberAccent
                      : Colors.white.withOpacity(0.07),
                ),
              ),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFF013328)
                      : Colors.white70,
                  fontFamily: 'kopub',
                  fontWeight: FontWeight.bold,
                  fontSize: screenWidth * 0.032,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector(double screenWidth) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              showCalendarDialog(
                context: context,
                selectedDate: startDate ?? DateTime.now(),
                minDate: DateTime(2000),
                maxDate: DateTime.now(),
                onDatePicked: (picked) {
                  setState(() {
                    startDate = picked;

                    if (endDate != null &&
                        endDate!.isBefore(startDate!)) {
                      endDate = startDate;
                    }
                  });
                },
                isStartDate: true,
              );
            },
            child: _buildDateCard(
              '시작일',
              startDate ?? DateTime.now(),
              screenWidth,
            ),
          ),
        ),

        if (selectedCategory == 'done') ...[
          SizedBox(width: screenWidth * 0.02),

          Expanded(
            child: GestureDetector(
              onTap: () {
                showCalendarDialog(
                  context: context,
                  selectedDate: endDate ?? DateTime.now(),
                  minDate: startDate ?? DateTime(2000),
                  maxDate: DateTime.now(),
                  onDatePicked: (picked) {
                    if (startDate != null &&
                        picked.isBefore(startDate!)) {
                      return;
                    }

                    setState(() {
                      endDate = picked;
                    });
                  },
                  isStartDate: false,
                );
              },
              child: _buildDateCard(
                '종료일',
                endDate ?? DateTime.now(),
                screenWidth,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _saveBook() async {
    final provider =
    context.read<SavedBooksProvider>();

    final screenWidth =
        MediaQuery.of(context).size.width;

    BookModel resolvedBook = book;


    // 페이지수가 없다면 YES24 ISBN 상세 조회로 보완
    final isbn = resolvedBook.isbn?.trim();

    if ((resolvedBook.pageCount ?? 0) <= 0 &&
        isbn != null &&
        isbn.replaceAll(RegExp(r'[^0-9Xx]'), '').length == 13) {
      try {
        final fetched = await BookApiService.fetchBookDetailByIsbn(isbn);

        if (fetched != null && (fetched.pageCount ?? 0) > 0) {
          resolvedBook = resolvedBook.copyWith(
            pageCount: fetched.pageCount,
          );
        }
      } catch (e) {
        debugPrint('[YES24 페이지수 보완 실패] $e');
      }
    }


    final totalPage =
        resolvedBook.pageCount ?? 0;

    if (selectedCategory == 'reading' &&
        totalPage <= 1) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              '총 페이지 정보를 확인할 수 없어 읽는 중으로 등록할 수 없습니다.',
            ),
          ),
        );

      return;
    }

    final maxPage =
    totalPage > 1
        ? totalPage - 1
        : 1;

    final inputPage =
        int.tryParse(
          _pageController.text.trim(),
        ) ??
            1;

    final int validPageRead;

    switch (selectedCategory) {
      case 'done':
        validPageRead = totalPage;
        break;

      case 'reading':
        validPageRead =
            inputPage.clamp(1, maxPage);
        break;

      case 'want':
      default:
        validPageRead = 0;
        break;
    }

    final newBook = resolvedBook.copyWith(
      category: selectedCategory,
      startDate:
      selectedCategory == 'done' ||
          selectedCategory == 'reading'
          ? startDate
          : null,
      endDate:
      selectedCategory == 'done'
          ? endDate
          : null,
      readDate:
      selectedCategory == 'done'
          ? endDate ?? DateTime.now()
          : null,
      pageRead: validPageRead,
    );

    if (provider.savedBooks.any(
          (savedBook) =>
      savedBook.id == newBook.id,
    )) {
      _showDuplicateDialog(
        context,
        newBook.title ?? '',
        screenWidth,
      );

      return;
    }

    await provider.addOrUpdateBook(newBook);

    final targetCustomLibrary =
    widget.targetCustomLibrary?.trim();

    if (targetCustomLibrary != null &&
        targetCustomLibrary.isNotEmpty) {
      final customLibraryProvider =
      context.read<CustomLibraryProvider>();

      await provider.addBookToCustomLibrary(
        newBook.id,
        targetCustomLibrary,
        customLibraryProvider:
        customLibraryProvider,
      );
    }

    if (!mounted) return;

    _showBookSavedDialog(
      context,
      newBook.title ?? '',
      newBook.imageUrl ?? '',
      screenWidth,
    );
  }

  void _showDuplicateDialog(BuildContext context, String title, double screenWidth) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.redAccent.shade100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(screenWidth * 0.025)),
        title: Text(
          "이미 등록된 책입니다!",
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'kopub',
            fontWeight: FontWeight.bold,
            fontSize: screenWidth * 0.045,
          ),
        ),
        content: Text(
          "『$title』은(는) 이미 등록된 책이에요!",
          style: TextStyle(
            color: Colors.black87,
            fontFamily: 'kopub',
            fontWeight: FontWeight.w500,
            fontSize: screenWidth * 0.035,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              "확인",
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBookSavedDialog(BuildContext context, String title, String imageUrl, double screenWidth) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(const Duration(milliseconds: 1300), () {
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop(); // 다이얼로그
            Navigator.of(context).pop(); // 이전 화면
          }
        });

        return AlertDialog(
          backgroundColor: Colors.amberAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(screenWidth * 0.025)),
          content: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(screenWidth * 0.015),
                child: Image.network(
                  imageUrl,
                  width: screenWidth * 0.13,
                  height: screenWidth * 0.18,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: screenWidth * 0.13,
                    height: screenWidth * 0.18,
                    color: Colors.grey,
                    child: const Icon(Icons.book, color: Colors.white, size: 30),
                  ),
                ),
              ),
              SizedBox(width: screenWidth * 0.03),
              Flexible(
                child: Text(
                  "『$title』\n책이 등록되었습니다!",
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    fontFamily: 'kopub',
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}
