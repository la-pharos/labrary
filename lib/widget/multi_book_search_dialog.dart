/// 커스텀 챌린지 생성에서 사용

import 'package:flutter/material.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/service/book_api_service.dart';

class MultiBookSearchDialog extends StatefulWidget {
  final List<BookModel> initialSelectedBooks;

  const MultiBookSearchDialog({
    super.key,
    this.initialSelectedBooks = const [],
  });

  @override
  State<MultiBookSearchDialog> createState() =>
      _MultiBookSearchDialogState();
}

class _MultiBookSearchDialogState
    extends State<MultiBookSearchDialog> {
  final TextEditingController _searchController =
  TextEditingController();

  final ScrollController _scrollController =
  ScrollController();

  List<BookModel> _searchResults = [];
  late List<BookModel> _selectedBooks;

  bool _hasSearched = false;
  bool _isLoading = false;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();

    _selectedBooks = List<BookModel>.from(
      widget.initialSelectedBooks,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // =========================================================
  // BOOK KEY
  // =========================================================

  String _bookKey(BookModel book) {
    final itemId =
    (book.itemId ?? '').trim();

    if (itemId.isNotEmpty) {
      return 'itemId:$itemId';
    }

    return '${book.title.trim()}|${book.author.trim()}';
  }

  bool _isSelected(BookModel book) {
    final targetKey =
    _bookKey(book);

    return _selectedBooks.any(
          (selected) =>
      _bookKey(selected) ==
          targetKey,
    );
  }

  // =========================================================
  // SEARCH
  // =========================================================

  Future<void> _searchBooks() async {
    final keyword =
    _searchController.text.trim();

    if (keyword.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _searchResults = [];
    });

    try {
      final results =
      await BookApiService
          .searchBooksCombined(
        keyword,
      );

      if (!mounted) return;

      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      debugPrint(
        '❌ 다중 도서 검색 오류: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            '도서 검색 중 문제가 발생했습니다.',
            style: TextStyle(
              fontFamily: 'kopub',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // =========================================================
  // SELECT
  // =========================================================

  void _toggleBook(
      BookModel book,
      ) {
    final key =
    _bookKey(book);

    setState(() {
      final selectedIndex =
      _selectedBooks.indexWhere(
            (selected) =>
        _bookKey(selected) ==
            key,
      );

      if (selectedIndex >= 0) {
        _selectedBooks.removeAt(
          selectedIndex,
        );
      } else {
        _selectedBooks.add(
          book,
        );
      }
    });
  }

  void _removeSelectedBook(
      BookModel book,
      ) {
    final key =
    _bookKey(book);

    setState(() {
      _selectedBooks.removeWhere(
            (selected) =>
        _bookKey(selected) ==
            key,
      );
    });
  }

  // =========================================================
  // COMPLETE
  // =========================================================

  Future<void> _completeSelection() async {
    if (_selectedBooks.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            '도서를 한 권 이상 선택해주세요.',
            style: TextStyle(
              fontFamily: 'kopub',
            ),
          ),
        ),
      );

      return;
    }

    setState(() {
      _isCompleting = true;
    });

    try {
      final List<BookModel>
      completedBooks = [];

      for (final book
      in _selectedBooks) {
        BookModel completedBook =
            book;


        // 페이지수가 없는 도서는 YES24 ISBN 조회로 보완
        final isbn = book.isbn?.trim();

        if (book.pageCount <= 0 &&
            isbn != null &&
            isbn.replaceAll(RegExp(r'[^0-9Xx]'), '').length == 13) {
          try {
            final detail =
            await BookApiService.fetchBookDetailByIsbn(isbn);

            if (detail != null && detail.pageCount > 0) {
              // 기존 책 정보와 독서 기록을 보존
              completedBook = book.copyWith(
                pageCount: detail.pageCount,
              );
            }
          } catch (e) {
            debugPrint(
              '[YES24 선택 도서 페이지수 조회 실패] $e',
            );
          }
        }

        completedBooks.add(
          completedBook,
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop(
        completedBooks,
      );
    } catch (e) {
      debugPrint(
        '❌ 선택 도서 상세정보 로딩 오류: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            '도서 정보를 불러오는 중 문제가 발생했습니다.',
            style: TextStyle(
              fontFamily: 'kopub',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCompleting = false;
        });
      }
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final screenWidth =
        MediaQuery.of(context)
            .size
            .width;

    final screenHeight =
        MediaQuery.of(context)
            .size
            .height;

    return Dialog(
      backgroundColor:
      Colors.transparent,

      insetPadding:
      EdgeInsets.symmetric(
        horizontal:
        screenWidth * 0.04,
        vertical:
        screenHeight * 0.06,
      ),

      child: Container(
        width: double.infinity,
        height:
        screenHeight * 0.82,

        decoration:
        BoxDecoration(
          color:
          const Color(
            0xFF16483F,
          ),

          borderRadius:
          BorderRadius.circular(
            20,
          ),

          border:
          Border.all(
            color:
            Colors.white
                .withOpacity(
              0.08,
            ),
          ),

          boxShadow: [
            BoxShadow(
              color:
              Colors.black
                  .withOpacity(
                0.30,
              ),
              blurRadius:
              24,
              offset:
              const Offset(
                0,
                10,
              ),
            ),
          ],
        ),

        clipBehavior:
        Clip.antiAlias,

        child:
        Column(
          children: [
            // =================================================
            // CONTENT
            // =================================================

            Expanded(
              child:
              Padding(
                padding:
                EdgeInsets.fromLTRB(
                  screenWidth *
                      0.045,
                  screenWidth *
                      0.04,
                  screenWidth *
                      0.045,
                  0,
                ),

                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    _buildHeader(
                      screenWidth,
                    ),

                    SizedBox(
                      height:
                      screenWidth *
                          0.025,
                    ),

                    _buildSearchField(
                      screenWidth,
                    ),

                    if (_selectedBooks
                        .isNotEmpty) ...[
                      SizedBox(
                        height:
                        screenWidth *
                            0.03,
                      ),

                      _buildSelectedSummary(
                        screenWidth,
                      ),
                    ],

                    SizedBox(
                      height:
                      screenWidth *
                          0.025,
                    ),

                    Expanded(
                      child:
                      _buildResultSection(
                        screenWidth,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // =================================================
            // BOTTOM CTA
            // =================================================

            _buildBottomButton(
              screenWidth,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _buildHeader(
      double screenWidth,
      ) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Expanded(
          child:
          Column(
            crossAxisAlignment:
            CrossAxisAlignment
                .start,
            children: [
              Text(
                '읽을 책 선택',
                style:
                TextStyle(
                  color:
                  Colors.white,
                  fontFamily:
                  'kopub',
                  fontSize:
                  screenWidth *
                      0.043,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              SizedBox(
                height:
                screenWidth *
                    0.01,
              ),

              Text(
                '챌린지에서 읽을 책을 여러 권 선택할 수 있어요.',
                style:
                TextStyle(
                  color:
                  Colors.white
                      .withOpacity(
                    0.50,
                  ),
                  fontFamily:
                  'kopub',
                  fontSize:
                  screenWidth *
                      0.027,
                ),
              ),
            ],
          ),
        ),

        IconButton(
          onPressed:
          _isCompleting
              ? null
              : () {
            Navigator.of(
              context,
            ).pop();
          },
          icon:
          Icon(
            Icons.close_rounded,
            color:
            _isCompleting
                ? Colors.white24
                : Colors.white54,
            size:
            screenWidth *
                0.05,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // SEARCH
  // =========================================================

  Widget _buildSearchField(
      double screenWidth,
      ) {
    return TextField(
      controller:
      _searchController,

      enabled:
      !_isCompleting,

      textInputAction:
      TextInputAction.search,

      onSubmitted:
          (_) =>
          _searchBooks(),

      style:
      TextStyle(
        color:
        Colors.white,
        fontFamily:
        'kopub',
        fontSize:
        screenWidth *
            0.031,
      ),

      cursorColor:
      Colors.amberAccent,

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
          screenWidth *
              0.028,
        ),

        prefixIcon:
        Icon(
          Icons.search_rounded,
          color:
          Colors.white54,
          size:
          screenWidth *
              0.05,
        ),

        suffixIcon:
        IconButton(
          onPressed:
          _isLoading ||
              _isCompleting
              ? null
              : _searchBooks,
          icon:
          _isLoading
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
                .arrow_forward_rounded,
            color:
            Colors.white54,
            size:
            screenWidth *
                0.045,
          ),
        ),

        filled:
        true,

        fillColor:
        Colors.white
            .withOpacity(
          0.04,
        ),

        contentPadding:
        EdgeInsets.symmetric(
          horizontal:
          screenWidth *
              0.035,
          vertical:
          screenWidth *
              0.032,
        ),

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

        disabledBorder:
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
              0.04,
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
    );
  }

  // =========================================================
  // SELECTED BOOKS
  // =========================================================

  Widget _buildSelectedSummary(
      double screenWidth,
      ) {
    return Container(
      width:
      double.infinity,

      padding:
      EdgeInsets.all(
        screenWidth *
            0.03,
      ),

      decoration:
      BoxDecoration(
        color:
        Colors.amberAccent
            .withOpacity(
          0.055,
        ),

        borderRadius:
        BorderRadius.circular(
          14,
        ),

        border:
        Border.all(
          color:
          Colors.amberAccent
              .withOpacity(
            0.16,
          ),
        ),
      ),

      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons
                    .check_circle_outline_rounded,
                color:
                Colors.amberAccent,
                size:
                screenWidth *
                    0.038,
              ),

              SizedBox(
                width:
                screenWidth *
                    0.015,
              ),

              Text(
                '선택한 책',
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
                ),
              ),

              const Spacer(),

              Container(
                padding:
                EdgeInsets.symmetric(
                  horizontal:
                  screenWidth *
                      0.022,
                  vertical:
                  screenWidth *
                      0.009,
                ),
                decoration:
                BoxDecoration(
                  color:
                  Colors.amberAccent
                      .withOpacity(
                    0.10,
                  ),
                  borderRadius:
                  BorderRadius
                      .circular(
                    30,
                  ),
                ),
                child:
                Text(
                  '${_selectedBooks.length}권',
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
                    FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(
            height:
            screenWidth *
                0.022,
          ),

          SizedBox(
            height:
            screenWidth *
                0.095,
            child:
            ListView.separated(
              scrollDirection:
              Axis.horizontal,

              itemCount:
              _selectedBooks.length,

              separatorBuilder:
                  (
                  context,
                  index,
                  ) =>
                  SizedBox(
                    width:
                    screenWidth *
                        0.018,
                  ),

              itemBuilder:
                  (
                  context,
                  index,
                  ) {
                final book =
                _selectedBooks[
                index];

                return Container(
                  constraints:
                  BoxConstraints(
                    maxWidth:
                    screenWidth *
                        0.42,
                  ),

                  padding:
                  EdgeInsets.only(
                    left:
                    screenWidth *
                        0.025,
                  ),

                  decoration:
                  BoxDecoration(
                    color:
                    Colors.white
                        .withOpacity(
                      0.055,
                    ),
                    borderRadius:
                    BorderRadius
                        .circular(
                      999,
                    ),
                    border:
                    Border.all(
                      color:
                      Colors.white
                          .withOpacity(
                        0.07,
                      ),
                    ),
                  ),

                  child:
                  Row(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      Flexible(
                        child:
                        Text(
                          book.title,
                          maxLines:
                          1,
                          overflow:
                          TextOverflow
                              .ellipsis,
                          style:
                          TextStyle(
                            color:
                            Colors.white70,
                            fontFamily:
                            'kopub',
                            fontSize:
                            screenWidth *
                                0.025,
                          ),
                        ),
                      ),

                      InkWell(
                        onTap:
                        _isCompleting
                            ? null
                            : () {
                          _removeSelectedBook(
                            book,
                          );
                        },
                        borderRadius:
                        BorderRadius
                            .circular(
                          999,
                        ),
                        child:
                        Padding(
                          padding:
                          EdgeInsets.all(
                            screenWidth *
                                0.018,
                          ),
                          child:
                          Icon(
                            Icons
                                .close_rounded,
                            color:
                            Colors.white38,
                            size:
                            screenWidth *
                                0.035,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // RESULTS
  // =========================================================

  Widget _buildResultSection(
      double screenWidth,
      ) {
    if (!_hasSearched) {
      return _buildInitialState(
        screenWidth,
      );
    }

    if (_isLoading) {
      return const Center(
        child:
        SizedBox(
          width:
          28,
          height:
          28,
          child:
          CircularProgressIndicator(
            color:
            Colors.amberAccent,
            strokeWidth:
            2.5,
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return _buildEmptyState(
        screenWidth,
      );
    }

    return RawScrollbar(
      controller:
      _scrollController,

      thumbVisibility:
      true,

      thumbColor:
      Colors.white
          .withOpacity(
        0.18,
      ),

      thickness:
      3,

      radius:
      const Radius.circular(
        20,
      ),

      child:
      ListView.separated(
        controller:
        _scrollController,

        padding:
        EdgeInsets.only(
          right:
          screenWidth *
              0.012,
          bottom:
          screenWidth *
              0.03,
        ),

        itemCount:
        _searchResults.length,

        separatorBuilder:
            (
            context,
            index,
            ) =>
            SizedBox(
              height:
              screenWidth *
                  0.02,
            ),

        itemBuilder:
            (
            context,
            index,
            ) {
          final book =
          _searchResults[
          index];

          final selected =
          _isSelected(
            book,
          );

          return _buildBookItem(
            book:
            book,
            selected:
            selected,
            screenWidth:
            screenWidth,
          );
        },
      ),
    );
  }

  // =========================================================
  // BOOK ITEM
  // =========================================================

  Widget _buildBookItem({
    required BookModel book,
    required bool selected,
    required double screenWidth,
  }) {
    final imageWidth =
        screenWidth * 0.13;

    final imageHeight =
        imageWidth * 1.42;

    return Material(
      color:
      selected
          ? Colors.amberAccent
          .withOpacity(
        0.06,
      )
          : Colors.white
          .withOpacity(
        0.035,
      ),

      borderRadius:
      BorderRadius.circular(
        14,
      ),

      child:
      InkWell(
        onTap:
        _isCompleting
            ? null
            : () {
          _toggleBook(
            book,
          );
        },

        borderRadius:
        BorderRadius.circular(
          14,
        ),

        child:
        Container(
          padding:
          EdgeInsets.all(
            screenWidth *
                0.027,
          ),

          decoration:
          BoxDecoration(
            borderRadius:
            BorderRadius.circular(
              14,
            ),

            border:
            Border.all(
              color:
              selected
                  ? Colors
                  .amberAccent
                  .withOpacity(
                0.36,
              )
                  : Colors.white
                  .withOpacity(
                0.06,
              ),
            ),
          ),

          child:
          Row(
            crossAxisAlignment:
            CrossAxisAlignment
                .center,
            children: [
              // COVER
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

              SizedBox(
                width:
                screenWidth *
                    0.027,
              ),

              // INFO
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
                        FontWeight
                            .bold,
                        height:
                        1.35,
                      ),
                    ),

                    SizedBox(
                      height:
                      screenWidth *
                          0.007,
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

                    if (book.pageCount >
                        0) ...[
                      SizedBox(
                        height:
                        screenWidth *
                            0.012,
                      ),

                      Text(
                        '${book.pageCount}페이지',
                        style:
                        TextStyle(
                          color:
                          Colors.white38,
                          fontFamily:
                          'kopub',
                          fontSize:
                          screenWidth *
                              0.024,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(
                width:
                screenWidth *
                    0.02,
              ),

              // SELECT INDICATOR
              AnimatedContainer(
                duration:
                const Duration(
                  milliseconds:
                  150,
                ),

                width:
                screenWidth *
                    0.07,

                height:
                screenWidth *
                    0.07,

                decoration:
                BoxDecoration(
                  color:
                  selected
                      ? Colors
                      .amberAccent
                      : Colors.white
                      .withOpacity(
                    0.025,
                  ),

                  shape:
                  BoxShape.circle,

                  border:
                  Border.all(
                    color:
                    selected
                        ? Colors
                        .amberAccent
                        : Colors.white
                        .withOpacity(
                      0.22,
                    ),
                  ),
                ),

                child:
                selected
                    ? Icon(
                  Icons
                      .check_rounded,
                  color:
                  const Color(
                    0xFF013328,
                  ),
                  size:
                  screenWidth *
                      0.042,
                )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // INITIAL
  // =========================================================

  Widget _buildInitialState(
      double screenWidth,
      ) {
    return Center(
      child:
      Column(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Container(
            width:
            screenWidth *
                0.13,
            height:
            screenWidth *
                0.13,
            decoration:
            BoxDecoration(
              color:
              Colors.amberAccent
                  .withOpacity(
                0.07,
              ),
              shape:
              BoxShape.circle,
            ),
            child:
            Icon(
              Icons
                  .auto_stories_outlined,
              color:
              Colors.amberAccent
                  .withOpacity(
                0.65,
              ),
              size:
              screenWidth *
                  0.055,
            ),
          ),

          SizedBox(
            height:
            screenWidth *
                0.025,
          ),

          Text(
            '챌린지에서 읽을 책을 검색해보세요.',
            textAlign:
            TextAlign.center,
            style:
            TextStyle(
              color:
              Colors.white54,
              fontFamily:
              'kopub',
              fontSize:
              screenWidth *
                  0.028,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // EMPTY
  // =========================================================

  Widget _buildEmptyState(
      double screenWidth,
      ) {
    return Center(
      child:
      Column(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Icon(
            Icons
                .search_off_rounded,
            color:
            Colors.white30,
            size:
            screenWidth *
                0.06,
          ),

          SizedBox(
            height:
            screenWidth *
                0.018,
          ),

          Text(
            '검색 결과가 없어요.',
            style:
            TextStyle(
              color:
              Colors.white54,
              fontFamily:
              'kopub',
              fontSize:
              screenWidth *
                  0.028,
            ),
          ),

          SizedBox(
            height:
            screenWidth *
                0.008,
          ),

          Text(
            '다른 제목이나 작가명으로 검색해보세요.',
            style:
            TextStyle(
              color:
              Colors.white30,
              fontFamily:
              'kopub',
              fontSize:
              screenWidth *
                  0.024,
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
      String? imageUrl,
      double width,
      double height,
      ) {
    if (imageUrl == null ||
        imageUrl.isEmpty) {
      return _buildPlaceholder(
        width,
        height,
      );
    }

    if (imageUrl.startsWith(
      'http',
    )) {
      return Image.network(
        imageUrl,
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
          return _buildPlaceholder(
            width,
            height,
          );
        },
      );
    }

    if (imageUrl.startsWith(
      'assets/',
    )) {
      return Image.asset(
        imageUrl,
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
          return _buildPlaceholder(
            width,
            height,
          );
        },
      );
    }

    return _buildPlaceholder(
      width,
      height,
    );
  }

  Widget _buildPlaceholder(
      double width,
      double height,
      ) {
    return Container(
      width:
      width,
      height:
      height,
      color:
      Colors.white
          .withOpacity(
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

  // =========================================================
  // BOTTOM BUTTON
  // =========================================================

  Widget _buildBottomButton(
      double screenWidth,
      ) {
    return SafeArea(
      top:
      false,

      child:
      Container(
        width:
        double.infinity,

        padding:
        EdgeInsets.fromLTRB(
          screenWidth *
              0.045,
          screenWidth *
              0.025,
          screenWidth *
              0.045,
          screenWidth *
              0.035,
        ),

        decoration:
        BoxDecoration(
          color:
          const Color(
            0xFF16483F,
          ),

          border:
          Border(
            top:
            BorderSide(
              color:
              Colors.white
                  .withOpacity(
                0.07,
              ),
            ),
          ),

        ),

        child:
        ElevatedButton(
          onPressed:
          _isCompleting
              ? null
              : _completeSelection,

          style:
          ElevatedButton
              .styleFrom(
            backgroundColor:
            Colors.amberAccent,

            disabledBackgroundColor:
            Colors.amberAccent
                .withOpacity(
              0.45,
            ),

            foregroundColor:
            const Color(
              0xFF013328,
            ),

            elevation:
            0,

            padding:
            EdgeInsets.symmetric(
              vertical:
              screenWidth *
                  0.038,
            ),

            shape:
            RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(
                14,
              ),
            ),
          ),

          child:
          _isCompleting
              ? SizedBox(
            width:
            screenWidth *
                0.05,
            height:
            screenWidth *
                0.05,
            child:
            const CircularProgressIndicator(
              strokeWidth:
              2.2,
              color:
              Color(
                0xFF013328,
              ),
            ),
          )
              : Row(
            mainAxisAlignment:
            MainAxisAlignment
                .center,
            children: [
              Icon(
                Icons
                    .check_rounded,
                size:
                screenWidth *
                    0.042,
              ),

              SizedBox(
                width:
                screenWidth *
                    0.012,
              ),

              Text(
                '선택 완료 (${_selectedBooks.length}권)',
                style:
                TextStyle(
                  fontFamily:
                  'kopub',
                  fontWeight:
                  FontWeight
                      .bold,
                  fontSize:
                  screenWidth *
                      0.032,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}