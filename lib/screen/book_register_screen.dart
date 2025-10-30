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



class BookRegisterScreen extends StatefulWidget {
  final BookModel book;

  const BookRegisterScreen({super.key, required this.book});

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
    selectedCategory = book.category ?? 'done';
    startDate = book.startDate ?? DateTime.now();
    endDate = book.endDate ?? DateTime.now();

    final pageRead = book.pageRead ?? 1;
    final maxPage = book.pageCount ?? 9999;
    _pageController.text = (pageRead >= 1 && pageRead <= maxPage)
        ? pageRead.toString()
        : '1';

    if ((book.pageCount == null || book.pageCount == 0) && book.itemId != null) {
      _fetchPageCount();
    }
  }

  void _fetchPageCount() async {
    try {
      final fetched = await BookApiService.fetchBookDetail(book.itemId!);
      if (fetched != null && fetched.pageCount != null && fetched.pageCount! > 0) {
        setState(() {
          book = book.copyWith(pageCount: fetched.pageCount);
        });
      }
    } catch (e) {
      debugPrint('[페이지 수 fetch 실패] $e');
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
              _buildBox(_buildCoverSection(screenWidth), screenWidth),
              SizedBox(height: verticalSpacing),
              _buildBox(_buildInfoSection(screenWidth), screenWidth),
              SizedBox(height: verticalSpacing),
              _buildBox(_buildRegisterSection(screenWidth), screenWidth),
              SizedBox(height: screenHeight * 0.1),
              //buildAdSection( context,  screenHeight)
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

  Widget _buildBox(Widget child, double screenWidth) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.05), // 반응형 padding
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  /// 1. 책 표지 섹션
  Widget _buildCoverSection(double screenWidth) {
    final imageWidth = screenWidth * 0.4;
    final imageHeight = imageWidth * 1.3;

    return Column(
      children: [
        SizedBox(height: screenWidth * 0.05),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            book.imageUrl ?? '',
            width: imageWidth,
            height: imageHeight,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container(
              width: imageWidth,
              height: imageHeight,
              color: Colors.grey,
              child: const Icon(Icons.book, color: Colors.white, size: 40),
            ),
          ),
        ),
        SizedBox(height: screenWidth * 0.04),
        Text(
          book.title ?? '',
          style: TextStyle(
            fontSize: screenWidth * 0.04,
            fontWeight: FontWeight.bold,
            fontFamily: 'kopub',
            color: Colors.white,
          ),
        ),
        if (book.author != null)
          Text(
            book.author!,
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              fontFamily: 'kopub',
              color: Colors.white70,
            ),
          ),
      ],
    );
  }

  /// 2. 책 정보 섹션
  Widget _buildInfoSection(double screenWidth) {
    final description = book.description ?? '';
    final isLong = description.length > 80;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "책 정보",
          style: TextStyle(
            fontSize: screenWidth * 0.04,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: screenWidth * 0.04),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: screenWidth * 0.04,
            horizontal: screenWidth * 0.05,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow("출판사", book.publisher ?? '-', screenWidth),
              SizedBox(height: screenWidth * 0.02),
              _infoRow("ISBN", book.isbn ?? '-', screenWidth),
              SizedBox(height: screenWidth * 0.02),
              _infoRow("총 페이지", book.pageCount?.toString() ?? '-', screenWidth),
            ],
          ),
        ),
        SizedBox(height: screenWidth * 0.03),
        _buildExpandableDescription(description, isLong, screenWidth),
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

  Widget _buildExpandableDescription(String description, bool isLong, double screenWidth) {
    final maxLines = _isExpanded ? null : 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          description,
          maxLines: maxLines,
          overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: screenWidth * 0.03,
          ),
        ),
        if (isLong)
          Center(
            child: TextButton(
              onPressed: () => setState(() => _isExpanded = !_isExpanded),
              child: Text(
                _isExpanded ? "접기" : "더 보기",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: screenWidth * 0.03,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 3. 책 등록 섹션 (카테고리 + 날짜 선택)
  Widget _buildRegisterSection(double screenWidth) {
    final maxPage = (book.pageCount ?? 1) - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "책 등록",
          style: TextStyle(
            fontSize: screenWidth * 0.04,
            fontWeight: FontWeight.bold,
            fontFamily: 'kopub',
            color: Colors.white,
          ),
        ),
        SizedBox(height: screenWidth * 0.04),
        _buildCategorySelector(screenWidth),
        SizedBox(height: screenWidth * 0.04),
        if (selectedCategory == "done" || selectedCategory == "reading") ...[
          if (selectedCategory == "done")
            _buildDateSelector(screenWidth)
          else if (selectedCategory == "reading")
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      showCalendarDialog(
                        context: context,
                        selectedDate: startDate!,
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
                    child: _buildDateCard("시작일", startDate!, screenWidth),
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(screenWidth * 0.0175),
                    margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "읽은 페이지 수",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: screenWidth * 0.035,
                          ),
                        ),
                        TextField(
                          controller: _pageController,
                          keyboardType: TextInputType.number,
                          maxLength: 5,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'kopub',
                            fontSize: screenWidth * 0.04,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: '예: 120',
                            hintStyle: TextStyle(
                              color: Colors.grey,
                              fontSize: screenWidth * 0.035,
                            ),
                            counterText: '',
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (value) {
                            final entered = int.tryParse(value);
                            if (entered != null && (entered < 1 || entered > maxPage)) {
                              final clamped = entered.clamp(1, maxPage);
                              _pageController.text = clamped.toString();
                              _pageController.selection = TextSelection.fromPosition(
                                TextPosition(offset: _pageController.text.length),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('1 ~ $maxPage 사이의 숫자를 입력해주세요.'),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          if (selectedCategory == "done") SizedBox(height: screenWidth * 0.04),
        ],
      ],
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

  Widget _categoryButton(String title, String value, double screenWidth) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedCategory = value;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: screenWidth * 0.03),
          margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
          decoration: BoxDecoration(
            color: selectedCategory == value ? Colors.amberAccent : Colors.white24,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selectedCategory == value ? const Color(0xFF013328) : Colors.white,
              fontFamily: 'kopub',
              fontWeight: FontWeight.bold,
              fontSize: screenWidth * 0.035,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector(double screenWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              showCalendarDialog(
                context: context,
                selectedDate: startDate!,
                minDate: DateTime(2000),
                maxDate: DateTime.now(),
                onDatePicked: (picked) {
                  setState(() {
                    startDate = picked;
                    if (endDate != null && endDate!.isBefore(startDate!)) {
                      endDate = startDate;
                    }
                  });
                },
                isStartDate: true,
              );
            },
            child: _buildDateCard("시작일", startDate!, screenWidth),
          ),
        ),
        if (selectedCategory == "done")
          Expanded(
            child: GestureDetector(
              onTap: () {
                showCalendarDialog(
                  context: context,
                  selectedDate: endDate!,
                  minDate: startDate!,
                  maxDate: DateTime.now(),
                  onDatePicked: (picked) {
                    setState(() {
                      if (picked.isBefore(startDate!)) return;
                      endDate = picked;
                    });
                  },
                  isStartDate: false,
                );
              },
              child: _buildDateCard("종료일", endDate!, screenWidth),
            ),
          ),
      ],
    );
  }

  Widget _buildDateCard(String label, DateTime date, double screenWidth) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.02),
      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: screenWidth * 0.035,
            ),
          ),
          Text(
            DateFormat('yy/MM/dd').format(date),
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.04,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _saveBook() async {
    final provider = Provider.of<SavedBooksProvider>(context, listen: false);
    final screenWidth = MediaQuery.of(context).size.width;


    final maxPage = (book.pageCount ?? 1) - 1;
    final inputPage = int.tryParse(_pageController.text) ?? 1;

    final validPageRead = selectedCategory == "done"
        ? book.pageCount ?? 0
        : (selectedCategory == "reading" ? inputPage.clamp(1, maxPage) : 0);

    BookModel newBook = book.copyWith(
      category: selectedCategory,
      startDate: (selectedCategory == "done" || selectedCategory == "reading") ? startDate : null,
      endDate: (selectedCategory == "done") ? endDate : null,
      readDate: (selectedCategory == "done") ? (endDate ?? DateTime.now()) : null,
      pageRead: validPageRead,
    );

    if ((newBook.pageCount == 0 || newBook.pageCount == null) && newBook.itemId != null) {
      try {
        final fetched = await BookApiService.fetchBookDetail(newBook.itemId!);
        if (fetched != null && fetched.pageCount != null && fetched.pageCount! > 0) {
          newBook = newBook.copyWith(pageCount: fetched.pageCount);
        }
      } catch (e) {
        debugPrint('[fetchBookDetail 실패] $e');
      }
    }

    if (provider.savedBooks.any((b) => b.id == newBook.id)) {
      _showDuplicateDialog(context, newBook.title ?? '', screenWidth);
      return;
    }

    provider.addOrUpdateBook(newBook);
    _showBookSavedDialog(context, newBook.title ?? '', newBook.imageUrl ?? '', screenWidth);
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
            fontSize: screenWidth * 0.04,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              "확인",
              style: TextStyle(
                color: Colors.black87,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.04,
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
                    fontSize: screenWidth * 0.04,
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
