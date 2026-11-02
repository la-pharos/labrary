import 'package:flutter/material.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/screen/book_register_screen.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/service/book_api_service.dart';
import 'package:dayverse_book/widget/ad_banner_placeholder.dart';
import 'package:dayverse_book/widget/card_box.dart';
import 'package:dayverse_book/screen/book_self_register_screen.dart';

enum SearchState { idle, focused, submitted }

class BookSearchScreen extends StatefulWidget {
  final String? initialCategory;
  final String? targetCustomLibrary;

  const BookSearchScreen({
    super.key,
    this.initialCategory,
    this.targetCustomLibrary,
  });

  @override
  State<BookSearchScreen> createState() => _BookSearchScreenState();
}

class _BookSearchScreenState extends State<BookSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  SearchState _searchState = SearchState.idle;
  List<BookModel> _searchResults = [];
  bool _isLoading = false;

  List<BookModel> _bestsellers = [];
  bool _isBestsellerLoading = false;

  @override
  void initState() {
    super.initState();

    _loadBestsellers();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _searchController.text.isEmpty) {
        setState(() {
          _searchState = SearchState.focused;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _searchBooks(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _searchState = SearchState.submitted;
      _isLoading = true;
      _searchResults = [];
    });

    try {
      final result = await BookApiService.searchBooksCombined(query);

      if (!mounted) return;

      setState(() {
        _searchResults = result;
      });
    } catch (e) {
      debugPrint("📛 검색 실패: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("검색 중 오류가 발생했습니다."),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBestsellers() async {
    setState(() {
      _isBestsellerLoading = true;
    });

    try {
      final result = await BookApiService.fetchBestsellers();

      debugPrint("✅ 화면에 반영할 베스트셀러 개수: ${result.length}");
      for (final b in result) {
        debugPrint("📚 ${b.title}");
      }

      if (!mounted) return;

      setState(() {
        _bestsellers = result;
      });
    } catch (e) {
      debugPrint("📛 베스트셀러 불러오기 실패: $e");
    } finally {
      if (!mounted) return;

      setState(() {
        _isBestsellerLoading = false;
      });
    }
  }

  void _navigateToSelfRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookSelfRegisterScreen(
          initialCategory: widget.initialCategory,
          targetCustomLibrary: widget.targetCustomLibrary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savedBooksProvider = Provider.of<SavedBooksProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final adHeight = screenHeight * 0.08;

    return GestureDetector(
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
            "책 추가하기",
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              tooltip: "직접 등록",
              icon: const Icon(
                Icons.add_rounded,
                color: Colors.white,
              ),
              onPressed: _navigateToSelfRegister,
            ),
            SizedBox(width: screenWidth * 0.015),
          ],
        ),
        body: Stack(
          children: [
            SizedBox(
              height: screenHeight,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: screenWidth * 0.04,
                    right: screenWidth * 0.04,
                    top: screenWidth * 0.04,
                    bottom: adHeight + screenHeight * 0.03,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white24,
                          hintText: "책 제목 / 작가를 입력하세요",
                          hintStyle: TextStyle(
                            color: Colors.white54,
                            fontFamily: 'kopub',
                            fontSize: screenWidth * 0.035,
                          ),
                          prefixIcon: const Icon(Icons.search, color: Colors.white),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchResults.clear();
                                _searchState = SearchState.idle;
                                _focusNode.unfocus();
                              });
                            },
                          )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: _searchBooks,
                        onChanged: (text) {
                          setState(() {});

                          if (text.isEmpty) {
                            setState(() {
                              _searchState = _focusNode.hasFocus
                                  ? SearchState.focused
                                  : SearchState.idle;
                              _searchResults.clear();
                            });
                          }
                        },
                      ),
                      SizedBox(height: screenHeight * 0.015),

                      _buildSearchResultView(
                        savedBooksProvider,
                        screenWidth,
                        screenHeight,
                      ),
                    ],
                  ),
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

  Widget _buildSearchResultView(
      SavedBooksProvider provider,
      double screenWidth,
      double screenHeight,
      ) {
    if (_isLoading || _isBestsellerLoading) {
      return Padding(
        padding: EdgeInsets.only(top: screenHeight * 0.1),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    switch (_searchState) {
      case SearchState.focused:
        return const SizedBox.shrink();

      case SearchState.submitted:
        if (_searchResults.isEmpty) {
          return _buildEmptySearchResult(
            screenWidth,
            screenHeight,
          );
        }

        return _buildBookColumn(
          context,
          _searchResults,
          provider,
          screenWidth,
          showRank: false,
        );

      case SearchState.idle:
      default:
        if (_bestsellers.isEmpty) {
          return Padding(
            padding: EdgeInsets.only(top: screenHeight * 0.08),
            child: Center(
              child: Text(
                "베스트셀러를 불러오는 중입니다.",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: screenWidth * 0.035,
                  fontFamily: 'kopub',
                ),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CardBox(
              margin: EdgeInsets.only(
                top: screenHeight * 0.005,
                bottom: screenHeight * 0.015,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.04,
                vertical: screenWidth * 0.035,
              ),
              child: Row(
                children: [
                  Container(
                    width: screenWidth * 0.105,
                    height: screenWidth * 0.105,
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.local_fire_department_rounded,
                      color: Colors.amberAccent,
                      size: screenWidth * 0.06,
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "현재 베스트셀러 TOP 10",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.04,
                            fontFamily: 'kopub',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: screenWidth * 0.008),
                        Text(
                          "지금 독자들이 주목하는 책을 만나보세요.",
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: screenWidth * 0.03,
                            fontFamily: 'kopub',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _buildBookColumn(
              context,
              _bestsellers,
              provider,
              screenWidth,
              showRank: true,
            ),
          ],
        );
    }
  }


  Widget _buildEmptySearchResult(
      double screenWidth,
      double screenHeight,
      ) {
    return Padding(
      padding: EdgeInsets.only(
        top: screenHeight * 0.055,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: screenWidth * 0.18,
              height: screenWidth * 0.18,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                color: Colors.white54,
                size: screenWidth * 0.085,
              ),
            ),

            SizedBox(
              height: screenWidth * 0.045,
            ),

            Text(
              '검색 결과가 없어요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.042,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(
              height: screenWidth * 0.018,
            ),

            Text(
              '찾는 책이 없다면 직접 등록해 보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.032,
                height: 1.45,
              ),
            ),

            SizedBox(
              height: screenWidth * 0.055,
            ),

            SizedBox(
              width: double.infinity,
              height: screenWidth * 0.125,
              child: ElevatedButton.icon(
                onPressed: _navigateToSelfRegister,
                icon: Icon(
                  Icons.add_rounded,
                  size: screenWidth * 0.055,
                ),
                label: Text(
                  '책 직접 등록하기',
                  style: TextStyle(
                    fontFamily: 'kopub',
                    fontSize: screenWidth * 0.036,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  Colors.amberAccent,
                  foregroundColor:
                  const Color(0xFF013328),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookColumn(
      BuildContext context,
      List<BookModel> books,
      SavedBooksProvider provider,
      double screenWidth, {
        bool showRank = false,
      }) {
    return Column(
      children: books.asMap().entries.map((entry) {
        final index = entry.key;
        final book = entry.value;

        return _buildBookTile(
          book,
          screenWidth,
          index: showRank ? index + 1 : null,
        );
      }).toList(),
    );
  }

  Widget _buildBookTile(
      BookModel book,
      double screenWidth, {
        int? index,
      }) {
    final imageWidth = screenWidth * 0.145;
    final imageHeight = screenWidth * 0.205;

    final author = book.author.trim();
    final publisher = book.publisher?.trim() ?? '';

    final detailText = [
      if (author.isNotEmpty) author,
      if (publisher.isNotEmpty) publisher,
    ].join(' · ');

    return CardBox(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookRegisterScreen(
              book: book,
              initialCategory: widget.initialCategory,
              targetCustomLibrary: widget.targetCustomLibrary,
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
          // ✅ 베스트셀러일 때만 순위 배지 표시
          if (index != null) ...[
            Container(
              width: screenWidth * 0.085,
              height: screenWidth * 0.085,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: index <= 3
                    ? Colors.amberAccent.withOpacity(0.16)
                    : Colors.white.withOpacity(0.07),
                shape: BoxShape.circle,
                border: Border.all(
                  color: index <= 3
                      ? Colors.amberAccent.withOpacity(0.45)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Text(
                '$index',
                style: TextStyle(
                  color: index <= 3
                      ? Colors.amberAccent
                      : Colors.white70,
                  fontSize: screenWidth * 0.038,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'kopub',
                ),
              ),
            ),
            SizedBox(width: screenWidth * 0.025),
          ],

          // ✅ 책 표지
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
              child: Image.network(
                book.imageUrl ?? '',
                width: imageWidth,
                height: imageHeight,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Container(
                    color: Colors.white.withOpacity(0.08),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white54,
                      size: screenWidth * 0.07,
                    ),
                  );
                },
              ),
            ),
          ),

          SizedBox(width: screenWidth * 0.035),

          // ✅ 책 정보
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
                      fontSize: screenWidth * 0.03,
                      fontFamily: 'kopub',
                      height: 1.35,
                    ),
                  ),
                ],
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

}
