import 'package:flutter/material.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/service/book_api_service.dart';

/// 단일 + 사용자 지정도서 + 페이지 연동 챌린지의
/// 참여 다이얼로그에서 사용하는 도서 선택 위젯
class ChallegeBookSelectionBox extends StatefulWidget {
  final BookModel? initialSelectedBook;
  final Function(BookModel?) onBookChanged;

  const ChallegeBookSelectionBox({
    super.key,
    this.initialSelectedBook,
    required this.onBookChanged,
  });

  @override
  State<ChallegeBookSelectionBox> createState() =>
      _BookSearchSelectionBoxState();
}

class _BookSearchSelectionBoxState
    extends State<ChallegeBookSelectionBox> {
  final TextEditingController _searchController =
  TextEditingController();

  List<BookModel> _searchResults = [];
  BookModel? _selectedBook;

  bool _isSearching = false;

  @override
  void initState() {
    super.initState();

    _selectedBook =
        widget.initialSelectedBook;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // =========================================================
  // SEARCH
  // =========================================================

  Future<void> _handleSearch(
      String keyword,
      ) async {
    final trimmed =
    keyword.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results =
      await BookApiService
          .searchBooksCombined(
        trimmed,
      );

      if (!mounted) return;

      setState(() {
        _searchResults = results;
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            '도서 검색 중 문제가 발생했습니다.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  // =========================================================
  // SELECT
  // =========================================================

  void _selectBook(
      BookModel book,
      ) {
    setState(() {
      _selectedBook = book;
      _searchResults = [];
    });

    widget.onBookChanged(
      book,
    );
  }

  void _removeBook() {
    setState(() {
      _selectedBook = null;
    });

    widget.onBookChanged(
      null,
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width;

    final screenHeight =
        MediaQuery.of(context).size.height;

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        // =====================================================
        // SEARCH FIELD
        // =====================================================

        TextField(
          controller:
          _searchController,
          onSubmitted:
          _handleSearch,

          textInputAction:
          TextInputAction.search,

          style: TextStyle(
            color:
            Colors.white,
            fontFamily:
            'kopub',
            fontSize:
            screenWidth * 0.031,
          ),

          decoration:
          InputDecoration(
            hintText:
            '책 제목 또는 작가를 검색하세요.',

            hintStyle:
            TextStyle(
              color:
              Colors.white38,
              fontFamily:
              'kopub',
              fontSize:
              screenWidth * 0.029,
            ),

            filled:
            true,

            fillColor:
            Colors.white
                .withOpacity(0.04),

            contentPadding:
            EdgeInsets.symmetric(
              horizontal:
              screenWidth * 0.035,
              vertical:
              screenWidth * 0.032,
            ),

            prefixIcon:
            Padding(
              padding:
              EdgeInsets.only(
                left:
                screenWidth * 0.012,
              ),
              child:
              IconButton(
                onPressed:
                _isSearching
                    ? null
                    : () {
                  _handleSearch(
                    _searchController
                        .text,
                  );
                },
                icon:
                _isSearching
                    ? SizedBox(
                  width:
                  screenWidth *
                      0.04,
                  height:
                  screenWidth *
                      0.04,
                  child:
                  const CircularProgressIndicator(
                    strokeWidth:
                    2,
                    color:
                    Colors.amberAccent,
                  ),
                )
                    : Icon(
                  Icons
                      .search_rounded,
                  color:
                  Colors.white54,
                  size:
                  screenWidth *
                      0.05,
                ),
              ),
            ),

            suffixIcon:
            _searchController
                .text
                .isNotEmpty
                ? IconButton(
              onPressed:
                  () {
                _searchController
                    .clear();

                setState(() {
                  _searchResults =
                  [];
                });
              },
              icon:
              Icon(
                Icons
                    .close_rounded,
                color:
                Colors.white38,
                size:
                screenWidth *
                    0.045,
              ),
            )
                : null,

            enabledBorder:
            OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(
                14,
              ),
              borderSide:
              BorderSide(
                color:
                Colors.white
                    .withOpacity(
                  0.07,
                ),
              ),
            ),

            focusedBorder:
            OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(
                14,
              ),
              borderSide:
              BorderSide(
                color:
                Colors.amberAccent
                    .withOpacity(
                  0.50,
                ),
              ),
            ),

            border:
            OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(
                14,
              ),
            ),
          ),
        ),

        // =====================================================
        // SEARCH RESULTS
        // =====================================================

        AnimatedSize(
          duration:
          const Duration(
            milliseconds: 220,
          ),
          curve:
          Curves.easeOutCubic,
          child:
          _searchResults.isEmpty
              ? const SizedBox
              .shrink()
              : Padding(
            padding:
            EdgeInsets.only(
              top:
              screenWidth *
                  0.02,
            ),
            child:
            Container(
              constraints:
              BoxConstraints(
                maxHeight:
                screenHeight *
                    0.28,
              ),
              decoration:
              BoxDecoration(
                color:
                Colors.black
                    .withOpacity(
                  0.08,
                ),
                borderRadius:
                BorderRadius
                    .circular(
                  14,
                ),
                border:
                Border.all(
                  color:
                  Colors.white
                      .withOpacity(
                    0.06,
                  ),
                ),
              ),
              child:
              ClipRRect(
                borderRadius:
                BorderRadius
                    .circular(
                  14,
                ),
                child:
                ListView.separated(
                  shrinkWrap:
                  true,
                  padding:
                  EdgeInsets.all(
                    screenWidth *
                        0.015,
                  ),
                  itemCount:
                  _searchResults
                      .length,
                  separatorBuilder:
                      (
                      context,
                      index,
                      ) =>
                      SizedBox(
                        height:
                        screenWidth *
                            0.01,
                      ),
                  itemBuilder:
                      (
                      context,
                      index,
                      ) {
                    final book =
                    _searchResults[
                    index];

                    final isSelected =
                        _selectedBook
                            ?.id ==
                            book.id;

                    return _buildSearchResultCard(
                      book:
                      book,
                      isSelected:
                      isSelected,
                      screenWidth:
                      screenWidth,
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        // =====================================================
        // SELECTED BOOK
        // =====================================================

        if (_selectedBook !=
            null) ...[
          SizedBox(
            height:
            screenWidth * 0.03,
          ),

          Row(
            children: [
              Text(
                '선택한 책',
                style:
                TextStyle(
                  color:
                  Colors.white
                      .withOpacity(
                    0.58,
                  ),
                  fontFamily:
                  'kopub',
                  fontSize:
                  screenWidth *
                      0.027,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),

              const Spacer(),

              Text(
                '1권',
                style:
                TextStyle(
                  color:
                  Colors.amberAccent,
                  fontFamily:
                  'kopub',
                  fontSize:
                  screenWidth *
                      0.026,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ],
          ),

          SizedBox(
            height:
            screenWidth * 0.015,
          ),

          _buildSelectedBookCard(
            book:
            _selectedBook!,
            screenWidth:
            screenWidth,
          ),
        ],
      ],
    );
  }

  // =========================================================
  // SEARCH RESULT CARD
  // =========================================================

  Widget _buildSearchResultCard({
    required BookModel book,
    required bool isSelected,
    required double screenWidth,
  }) {
    final imageWidth =
        screenWidth * 0.115;

    final imageHeight =
        imageWidth * 1.42;

    // 중요:
    // Container + background + ListTile 구조를 없애고
    // Material + InkWell로 변경.
    //
    // 이게 ListTile background assertion 해결 포인트.
    return Material(
      color:
      isSelected
          ? Colors.amberAccent
          .withOpacity(0.08)
          : Colors.white
          .withOpacity(0.035),

      borderRadius:
      BorderRadius.circular(12),

      child: InkWell(
        onTap: () =>
            _selectBook(book),

        borderRadius:
        BorderRadius.circular(12),

        child: Container(
          padding:
          EdgeInsets.all(
            screenWidth * 0.022,
          ),
          decoration:
          BoxDecoration(
            borderRadius:
            BorderRadius.circular(
              12,
            ),
            border:
            Border.all(
              color:
              isSelected
                  ? Colors
                  .amberAccent
                  .withOpacity(
                0.30,
              )
                  : Colors.white
                  .withOpacity(
                0.05,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius:
                BorderRadius.circular(
                  6,
                ),
                child:
                _buildCover(
                  book.imageUrl,
                  imageWidth,
                  imageHeight,
                ),
              ),

              SizedBox(
                width:
                screenWidth * 0.025,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines:
                      2,
                      overflow:
                      TextOverflow
                          .ellipsis,
                      style:
                      TextStyle(
                        color:
                        Colors.white,
                        fontFamily:
                        'kopub',
                        fontSize:
                        screenWidth *
                            0.029,
                        fontWeight:
                        FontWeight.w600,
                        height:
                        1.35,
                      ),
                    ),

                    if (book.author
                        .trim()
                        .isNotEmpty) ...[
                      SizedBox(
                        height:
                        screenWidth *
                            0.006,
                      ),

                      Text(
                        book.author,
                        maxLines:
                        1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        TextStyle(
                          color:
                          Colors.white54,
                          fontFamily:
                          'kopub',
                          fontSize:
                          screenWidth *
                              0.025,
                        ),
                      ),
                    ],

                    if (book.publisher !=
                        null &&
                        book.publisher!
                            .trim()
                            .isNotEmpty) ...[
                      SizedBox(
                        height:
                        screenWidth *
                            0.005,
                      ),

                      Text(
                        book.publisher!,
                        maxLines:
                        1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        TextStyle(
                          color:
                          Colors.white30,
                          fontFamily:
                          'kopub',
                          fontSize:
                          screenWidth *
                              0.023,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(
                width:
                screenWidth * 0.015,
              ),

              Container(
                width:
                screenWidth * 0.07,
                height:
                screenWidth * 0.07,
                decoration:
                BoxDecoration(
                  color:
                  isSelected
                      ? Colors
                      .amberAccent
                      .withOpacity(
                    0.12,
                  )
                      : Colors.white
                      .withOpacity(
                    0.04,
                  ),
                  shape:
                  BoxShape.circle,
                  border:
                  Border.all(
                    color:
                    isSelected
                        ? Colors
                        .amberAccent
                        .withOpacity(
                      0.30,
                    )
                        : Colors.white
                        .withOpacity(
                      0.06,
                    ),
                  ),
                ),
                child:
                Icon(
                  isSelected
                      ? Icons
                      .check_rounded
                      : Icons
                      .add_rounded,
                  color:
                  isSelected
                      ? Colors
                      .amberAccent
                      : Colors.white54,
                  size:
                  screenWidth *
                      0.04,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // SELECTED BOOK CARD
  // =========================================================

  Widget _buildSelectedBookCard({
    required BookModel book,
    required double screenWidth,
  }) {
    final imageWidth =
        screenWidth * 0.13;

    final imageHeight =
        imageWidth * 1.42;

    return Container(
      width:
      double.infinity,
      padding:
      EdgeInsets.all(
        screenWidth * 0.025,
      ),
      decoration:
      BoxDecoration(
        color: Colors.amberAccent
            .withOpacity(0.055),

        borderRadius:
        BorderRadius.circular(14),

        border:
        Border.all(
          color: Colors.amberAccent
              .withOpacity(0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.center,
        children: [
          Container(
            decoration:
            BoxDecoration(
              borderRadius:
              BorderRadius.circular(
                7,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                  Colors.black
                      .withOpacity(
                    0.18,
                  ),
                  blurRadius:
                  6,
                  offset:
                  const Offset(
                    0,
                    3,
                  ),
                ),
              ],
            ),
            child:
            ClipRRect(
              borderRadius:
              BorderRadius.circular(
                7,
              ),
              child:
              _buildCover(
                book.imageUrl,
                imageWidth,
                imageHeight,
              ),
            ),
          ),

          SizedBox(
            width:
            screenWidth * 0.027,
          ),

          Expanded(
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  book.title,
                  maxLines:
                  2,
                  overflow:
                  TextOverflow
                      .ellipsis,
                  style:
                  TextStyle(
                    color:
                    Colors.white,
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth *
                        0.03,
                    fontWeight:
                    FontWeight.bold,
                    height:
                    1.35,
                  ),
                ),

                if (book.author
                    .trim()
                    .isNotEmpty) ...[
                  SizedBox(
                    height:
                    screenWidth *
                        0.006,
                  ),

                  Text(
                    book.author,
                    maxLines:
                    1,
                    overflow:
                    TextOverflow
                        .ellipsis,
                    style:
                    TextStyle(
                      color:
                      Colors.white54,
                      fontFamily:
                      'kopub',
                      fontSize:
                      screenWidth *
                          0.026,
                    ),
                  ),
                ],

                if (book.pageCount >
                    0) ...[
                  SizedBox(
                    height:
                    screenWidth *
                        0.014,
                  ),

                  Text(
                    '${book.pageCount}페이지',
                    style:
                    TextStyle(
                      color:
                      Colors.amberAccent,
                      fontFamily:
                      'kopub',
                      fontSize:
                      screenWidth *
                          0.025,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),

          SizedBox(
            width:
            screenWidth * 0.015,
          ),

          Material(
            color:
            Colors.white
                .withOpacity(
              0.045,
            ),
            shape:
            const CircleBorder(),
            child:
            InkWell(
              customBorder:
              const CircleBorder(),
              onTap:
              _removeBook,
              child:
              SizedBox(
                width:
                screenWidth *
                    0.075,
                height:
                screenWidth *
                    0.075,
                child:
                Icon(
                  Icons
                      .close_rounded,
                  color:
                  Colors.white54,
                  size:
                  screenWidth *
                      0.04,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // COVER
  // =========================================================

  Widget _buildCover(
      String? url,
      double width,
      double height,
      ) {
    if (url == null ||
        url.isEmpty) {
      return _buildCoverFallback(
        width,
        height,
      );
    }

    if (url.startsWith('http')) {
      return Image.network(
        url,
        width:
        width,
        height:
        height,
        fit:
        BoxFit.cover,
        errorBuilder:
            (
            context,
            error,
            stackTrace,
            ) {
          return _buildCoverFallback(
            width,
            height,
          );
        },
      );
    }

    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        width:
        width,
        height:
        height,
        fit:
        BoxFit.cover,
        errorBuilder:
            (
            context,
            error,
            stackTrace,
            ) {
          return _buildCoverFallback(
            width,
            height,
          );
        },
      );
    }

    return _buildCoverFallback(
      width,
      height,
    );
  }

  Widget _buildCoverFallback(
      double width,
      double height,
      ) {
    return Container(
      width:
      width,
      height:
      height,
      color:
      Colors.white.withOpacity(
        0.055,
      ),
      alignment:
      Alignment.center,
      child:
      const Icon(
        Icons.book_rounded,
        color:
        Colors.white38,
      ),
    );
  }
}