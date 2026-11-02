import 'package:flutter/material.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/screen/book_detail_screen.dart';
import 'package:dayverse_book/widget/ad_banner_placeholder.dart';
import 'package:dayverse_book/widget/card_box.dart';

class LibrarySearchScreen extends StatefulWidget {
  final List<BookModel> savedBooks;

  const LibrarySearchScreen({super.key, required this.savedBooks});

  @override
  _LibrarySearchScreenState createState() => _LibrarySearchScreenState();
}

class _LibrarySearchScreenState extends State<LibrarySearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  late List<BookModel> _filteredBooks;

  @override
  void initState() {
    super.initState();
    _filteredBooks = widget.savedBooks;
  }

  void _filterBooks(String query) {
    final normalizedQuery = query.trim().toLowerCase();

    setState(() {
      if (normalizedQuery.isEmpty) {
        _filteredBooks = List<BookModel>.from(widget.savedBooks);
        return;
      }

      _filteredBooks = widget.savedBooks.where((book) {
        final title = book.title.toLowerCase();
        final author = book.author.toLowerCase();
        final publisher = book.publisher?.toLowerCase() ?? '';

        return title.contains(normalizedQuery) ||
            author.contains(normalizedQuery) ||
            publisher.contains(normalizedQuery);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final horizontalPadding = width * 0.04;
    final adHeight = height * 0.08;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 20) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF013328),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text(
            '서재 내 도서 검색',
            style: TextStyle(
              color: Colors.white,
              fontSize: width * 0.045,
              fontFamily: 'kopub',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(
                  left: horizontalPadding,
                  right: horizontalPadding,
                  top: width * 0.025,
                  bottom: adHeight + height * 0.03,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchField(width),

                    SizedBox(height: width * 0.035),

                    _buildResultHeader(width),

                    SizedBox(height: width * 0.025),

                    if (_filteredBooks.isEmpty)
                      _buildEmptyResult(width)
                    else
                      _buildBookList(width),

                    SizedBox(height: height * 0.03),
                  ],
                ),
              ),
            ),

            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BottomAdBannerBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(double screenWidth) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _filterBooks,
        textInputAction: TextInputAction.search,
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'kopub',
          fontSize: screenWidth * 0.035,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFF16483F),
          hintText: '책 제목 / 작가 / 출판사를 입력하세요',
          hintStyle: TextStyle(
            color: Colors.white54,
            fontFamily: 'kopub',
            fontSize: screenWidth * 0.033,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Colors.white60,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white60,
            ),
            onPressed: () {
              _searchController.clear();
              _filterBooks('');
              FocusScope.of(context).unfocus();
            },
          )
              : null,
          contentPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04,
            vertical: screenWidth * 0.038,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Colors.amberAccent.withOpacity(0.65),
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultHeader(double screenWidth) {
    final isSearching = _searchController.text.trim().isNotEmpty;

    return Row(
      children: [
        Container(
          width: screenWidth * 0.075,
          height: screenWidth * 0.075,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            isSearching
                ? Icons.manage_search_rounded
                : Icons.library_books_outlined,
            color: Colors.white70,
            size: screenWidth * 0.045,
          ),
        ),

        SizedBox(width: screenWidth * 0.025),

        Expanded(
          child: Text(
            isSearching ? '검색 결과' : '서재의 책',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.038,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        Container(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.025,
            vertical: screenWidth * 0.012,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_filteredBooks.length}권',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.031,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookList(double screenWidth) {
    return Column(
      children: _filteredBooks.map((book) {
        return _buildBookCard(
          book,
          screenWidth,
        );
      }).toList(),
    );
  }

  Widget _buildBookCard(
      BookModel book,
      double screenWidth,
      ) {
    final imageWidth = screenWidth * 0.15;
    final imageHeight = imageWidth * 1.4;

    final publisher = book.publisher?.trim() ?? '';

    final detailText = [
      if (book.author.trim().isNotEmpty) book.author,
      if (publisher.isNotEmpty) publisher,
    ].join(' · ');

    return CardBox(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookDetailScreen(
              book: book,
            ),
          ),
        );
      },
      margin: EdgeInsets.only(
        bottom: screenWidth * 0.025,
      ),
      padding: EdgeInsets.all(
        screenWidth * 0.03,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: imageWidth,
            height: imageHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: _buildBookImage(
                book,
                imageWidth,
                imageHeight,
              ),
            ),
          ),

          SizedBox(width: screenWidth * 0.035),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'kopub',
                    fontSize: screenWidth * 0.036,
                    fontWeight: FontWeight.bold,
                    height: 1.35,
                  ),
                ),

                if (detailText.isNotEmpty) ...[
                  SizedBox(height: screenWidth * 0.018),

                  Text(
                    detailText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white60,
                      fontFamily: 'kopub',
                      fontSize: screenWidth * 0.03,
                      height: 1.35,
                    ),
                  ),
                ],

                SizedBox(height: screenWidth * 0.022),

                _buildBookStatusChip(
                  book,
                  screenWidth,
                ),
              ],
            ),
          ),

          SizedBox(width: screenWidth * 0.015),

          Icon(
            Icons.chevron_right_rounded,
            color: Colors.white38,
            size: screenWidth * 0.06,
          ),
        ],
      ),
    );
  }

  Widget _buildBookStatusChip(
      BookModel book,
      double screenWidth,
      ) {
    String label;
    IconData icon;

    switch (book.category) {
      case 'done':
        label = '읽은 책';
        icon = Icons.check_circle_outline_rounded;
        break;

      case 'reading':
        label = '읽는 중';
        icon = Icons.auto_stories_rounded;
        break;

      case 'want':
      default:
        label = '읽을 예정';
        icon = Icons.bookmark_border_rounded;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.02,
        vertical: screenWidth * 0.01,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white60,
            size: screenWidth * 0.032,
          ),
          SizedBox(width: screenWidth * 0.01),
          Text(
            label,
            style: TextStyle(
              color: Colors.white60,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.027,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyResult(double screenWidth) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.05,
        vertical: screenWidth * 0.12,
      ),
      child: Column(
        children: [
          Container(
            width: screenWidth * 0.15,
            height: screenWidth * 0.15,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              color: Colors.white38,
              size: screenWidth * 0.075,
            ),
          ),

          SizedBox(height: screenWidth * 0.035),

          Text(
            '검색된 책이 없어요.',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.038,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: screenWidth * 0.015),

          Text(
            '책 제목이나 작가 이름을 다시 확인해주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.031,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookImage(
      BookModel book,
      double width,
      double height,
      ) {
    if (book.imageFile != null) {
      return Image.file(
        book.imageFile!,
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    }

    final imageUrl = book.imageUrl?.trim() ?? '';

    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return _buildFallbackBookImage(
            width,
            height,
          );
        },
      );
    }

    return _buildFallbackBookImage(
      width,
      height,
    );
  }
  Widget _buildFallbackBookImage(
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
        size: 30,
      ),
    );
  }
}
