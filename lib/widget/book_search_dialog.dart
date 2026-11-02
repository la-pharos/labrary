/// ReadingIntroScreen에서 사용

import 'package:flutter/material.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/service/book_api_service.dart';

class BookSearchDialog extends StatefulWidget {
  const BookSearchDialog({
    super.key,
  });

  @override
  State<BookSearchDialog> createState() =>
      _BookSearchDialogState();
}

class _BookSearchDialogState
    extends State<BookSearchDialog> {
  final TextEditingController
  _searchController =
  TextEditingController();

  final ScrollController
  _scrollController =
  ScrollController();

  List<BookModel> _searchResults = [];

  bool _hasSearched = false;
  bool _isLoading = false;

  double _dialogHeightRatio = 0.3;

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // =========================================================
  // SEARCH
  // =========================================================

  Future<void> _onSearchChanged(
      String keyword,
      ) async {
    final trimmed =
    keyword.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _dialogHeightRatio = 0.3;
      });

      return;
    }

    setState(() {
      _isLoading = true;
      _searchResults = [];
      _hasSearched = true;
      _dialogHeightRatio = 0.72;
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
        _dialogHeightRatio = 0.72;
      });
    } catch (e) {
      debugPrint(
        '❌ API 검색 오류: $e',
      );

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
          _isLoading = false;
        });
      }
    }
  }

  // =========================================================
  // BOOK SELECT
  // =========================================================


  Future<void> _onBookTap(BookModel book) async {
    BookModel selected = book;

    // 페이지수가 없는 경우 YES24 ISBN 조회
    final isbn = book.isbn?.trim();

    if (book.pageCount <= 0 &&
        isbn != null &&
        isbn.replaceAll(RegExp(r'[^0-9Xx]'), '').length == 13) {
      try {
        final detail =
        await BookApiService.fetchBookDetailByIsbn(isbn);

        if (detail != null && detail.pageCount > 0) {
          // 기존 책 정보는 유지하고 페이지수만 보완
          selected = book.copyWith(
            pageCount: detail.pageCount,
          );
        }
      } catch (e) {
        debugPrint('[YES24 도서 페이지수 조회 실패] $e');
      }
    }

    debugPrint(
      '[📘 선택된 책] '
          '${selected.title}, '
          'pageCount: ${selected.pageCount}',
    );

    if (!mounted) return;

    Navigator.of(context).pop(selected);
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

    final dialogWidth =
        screenWidth * 0.90;

    return Dialog(
      backgroundColor:
      Colors.transparent,

      insetPadding:
      EdgeInsets.symmetric(
        horizontal:
        screenWidth * 0.05,
        vertical:
        screenHeight * 0.07,
      ),

      child: AnimatedContainer(
        duration:
        const Duration(
          milliseconds: 260,
        ),

        curve:
        Curves.easeOutCubic,

        width:
        dialogWidth,

        height:
        screenHeight *
            _dialogHeightRatio,

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

        child:
        Column(
          children: [
            // =================================================
            // HEADER
            // =================================================

            Padding(
              padding:
              EdgeInsets.fromLTRB(
                screenWidth * 0.045,
                screenWidth * 0.045,
                screenWidth * 0.02,
                screenWidth * 0.025,
              ),
              child:
              _buildDialogHeader(
                screenWidth,
              ),
            ),

            Divider(
              height:
              1,
              thickness:
              1,
              color:
              Colors.white
                  .withOpacity(
                0.07,
              ),
            ),

            // =================================================
            // SEARCH
            // =================================================

            Padding(
              padding:
              EdgeInsets.fromLTRB(
                screenWidth * 0.045,
                screenWidth * 0.03,
                screenWidth * 0.045,
                screenWidth * 0.02,
              ),
              child:
              _buildSearchField(
                screenWidth,
              ),
            ),

            // =================================================
            // RESULT
            // =================================================

            Expanded(
              child:
              _buildResultSection(
                screenWidth,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _buildDialogHeader(
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
                '책 선택하기',
                style:
                TextStyle(
                  fontSize:
                  screenWidth *
                      0.043,
                  fontWeight:
                  FontWeight.bold,
                  fontFamily:
                  'kopub',
                  color:
                  Colors.white,
                ),
              ),

              SizedBox(
                height:
                screenWidth *
                    0.01,
              ),

              Text(
                '어떤 책과 함께 읽어볼까요?',
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
                      0.028,
                ),
              ),
            ],
          ),
        ),

        IconButton(
          onPressed:
              () {
            Navigator.of(context)
                .pop();
          },
          icon:
          Icon(
            Icons.close_rounded,
            color:
            Colors.white54,
            size:
            screenWidth *
                0.05,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // SEARCH FIELD
  // =========================================================

  Widget _buildSearchField(
      double screenWidth,
      ) {
    return TextField(
      controller:
      _searchController,

      onSubmitted:
      _onSearchChanged,

      textInputAction:
      TextInputAction.search,

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
              0.029,
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

        prefixIcon:
        Padding(
          padding:
          EdgeInsets.only(
            left:
            screenWidth *
                0.012,
          ),
          child:
          IconButton(
            onPressed:
            _isLoading
                ? null
                : () {
              _onSearchChanged(
                _searchController
                    .text,
              );
            },
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
              _hasSearched =
              false;
              _dialogHeightRatio =
              0.3;
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
    );
  }

  // =========================================================
  // RESULT SECTION
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
            strokeWidth:
            2.5,
            color:
            Colors.amberAccent,
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return _buildEmptyResult(
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
        0.20,
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
        EdgeInsets.fromLTRB(
          screenWidth *
              0.045,
          screenWidth *
              0.015,
          screenWidth *
              0.05,
          screenWidth *
              0.04,
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

          return _buildBookCard(
            book:
            book,
            screenWidth:
            screenWidth,
          );
        },
      ),
    );
  }

  // =========================================================
  // BOOK CARD
  // =========================================================

  Widget _buildBookCard({
    required BookModel book,
    required double screenWidth,
  }) {
    final imageWidth =
        screenWidth * 0.13;

    final imageHeight =
        imageWidth * 1.42;

    return Material(
      color:
      Colors.white
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
            () {
          _onBookTap(
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
              Colors.white
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
              Container(
                decoration:
                BoxDecoration(
                  borderRadius:
                  BorderRadius
                      .circular(
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
                  BorderRadius
                      .circular(
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
                          Colors.white38,
                          fontFamily:
                          'kopub',
                          fontSize:
                          screenWidth *
                              0.025,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(
                width:
                screenWidth *
                    0.015,
              ),

              Container(
                width:
                screenWidth *
                    0.07,
                height:
                screenWidth *
                    0.07,
                decoration:
                BoxDecoration(
                  color:
                  Colors.amberAccent
                      .withOpacity(
                    0.09,
                  ),
                  shape:
                  BoxShape.circle,
                  border:
                  Border.all(
                    color:
                    Colors.amberAccent
                        .withOpacity(
                      0.20,
                    ),
                  ),
                ),
                child:
                Icon(
                  Icons
                      .chevron_right_rounded,
                  color:
                  Colors.amberAccent,
                  size:
                  screenWidth *
                      0.042,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // INITIAL STATE
  // =========================================================

  Widget _buildInitialState(
      double screenWidth,
      ) {
    return Center(
      child:
      Padding(
        padding:
        EdgeInsets.symmetric(
          horizontal:
          screenWidth *
              0.06,
        ),
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
                    .menu_book_outlined,
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
              '찾고 싶은 책을 검색해보세요.',
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
                    0.029,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // EMPTY RESULT
  // =========================================================

  Widget _buildEmptyResult(
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
                0.065,
          ),

          SizedBox(
            height:
            screenWidth *
                0.02,
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
                  0.029,
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
                  0.025,
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

}