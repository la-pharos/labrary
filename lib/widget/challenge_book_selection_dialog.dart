/// Challenge에서 ReadingIntro로 넘어오는 책들

import 'package:flutter/material.dart';
import 'package:dayverse_book/model/book_model.dart';

class ChallengeBookSelectionDialog extends StatelessWidget {
  final List<BookModel> books;
  final List<BookModel> savedBooks;

  const ChallengeBookSelectionDialog({
    super.key,
    required this.books,
    required this.savedBooks,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width;

    final screenHeight =
        MediaQuery.of(context).size.height;

    // =========================================================
    // savedBooks 정보로 보강
    // 기존 로직 유지
    // =========================================================

    final List<BookModel> enrichedBooks =
    books.map((book) {
      final matched =
      savedBooks.firstWhere(
            (saved) =>
        saved.id == book.id,
        orElse: () => book,
      );

      return book.copyWith(
        imageUrl:
        matched.imageUrl ??
            book.imageUrl,

        pageCount:
        matched.pageCount ??
            book.pageCount,

        rereadCount:
        matched.rereadCount ??
            book.rereadCount,

        pageRead:
        matched.pageRead ??
            book.pageRead,
      );
    }).toList();

    return Dialog(
      backgroundColor:
      Colors.transparent,

      insetPadding:
      EdgeInsets.symmetric(
        horizontal:
        screenWidth * 0.05,
        vertical:
        screenHeight * 0.08,
      ),

      child: Container(
        width:
        double.infinity,

        constraints:
        BoxConstraints(
          maxHeight:
          screenHeight * 0.78,
        ),

        decoration:
        BoxDecoration(
          color:
          const Color(0xFF16483F),

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

        child: Column(
          mainAxisSize:
          MainAxisSize.min,
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
                screenWidth * 0.03,
              ),
              child: Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
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
                            FontWeight
                                .bold,
                          ),
                        ),

                        SizedBox(
                          height:
                          screenWidth *
                              0.01,
                        ),

                        Text(
                          '오늘 읽을 책을 선택해주세요.',
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
                      Navigator.of(
                        context,
                      ).pop();
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
            // BOOK LIST
            // =================================================

            Flexible(
              child:
              enrichedBooks.isEmpty
                  ? _buildEmptyState(
                screenWidth,
              )
                  : ListView.separated(
                shrinkWrap:
                true,
                padding:
                EdgeInsets.all(
                  screenWidth *
                      0.04,
                ),
                itemCount:
                enrichedBooks
                    .length,
                separatorBuilder:
                    (
                    context,
                    index,
                    ) =>
                    SizedBox(
                      height:
                      screenWidth *
                          0.022,
                    ),
                itemBuilder:
                    (
                    context,
                    index,
                    ) {
                  final book =
                  enrichedBooks[
                  index];

                  return _buildBookCard(
                    context:
                    context,
                    book:
                    book,
                    screenWidth:
                    screenWidth,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // BOOK CARD
  // =========================================================

  Widget _buildBookCard({
    required BuildContext context,
    required BookModel book,
    required double screenWidth,
  }) {
    final imageWidth =
        screenWidth * 0.13;

    final imageHeight =
        imageWidth * 1.42;

    final pageCount =
        book.pageCount;

    final pageRead =
        book.pageRead;

    final isDone =
        pageCount > 0 &&
            pageRead >= pageCount;

    final progress =
    pageCount > 0
        ? (pageRead / pageCount)
        .clamp(
      0.0,
      1.0,
    )
        .toDouble()
        : 0.0;

    final percent =
    pageCount > 0
        ? (progress * 100)
        .round()
        : 0;

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

      child: InkWell(
        onTap:
            () {
          Navigator.of(context)
              .pop(book);
        },

        borderRadius:
        BorderRadius.circular(
          14,
        ),

        child: Container(
          padding:
          EdgeInsets.all(
            screenWidth * 0.028,
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
              isDone
                  ? Colors.amberAccent
                  .withOpacity(
                0.18,
              )
                  : Colors.white
                  .withOpacity(
                0.06,
              ),
            ),
          ),

          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.center,
            children: [
              // =================================================
              // COVER
              // =================================================

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
                screenWidth *
                    0.028,
              ),

              // =================================================
              // INFO
              // =================================================

              Expanded(
                child: Column(
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
                            0.031,
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

                    SizedBox(
                      height:
                      screenWidth *
                          0.018,
                    ),

                    if (pageCount >
                        0) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isDone
                                  ? '$pageCount페이지 완독'
                                  : '$pageRead / $pageCount 페이지',
                              style:
                              TextStyle(
                                color:
                                isDone
                                    ? Colors
                                    .amberAccent
                                    : Colors
                                    .white54,
                                fontFamily:
                                'kopub',
                                fontSize:
                                screenWidth *
                                    0.025,
                                fontWeight:
                                isDone
                                    ? FontWeight
                                    .w600
                                    : FontWeight
                                    .normal,
                              ),
                            ),
                          ),

                          if (!isDone)
                            Text(
                              '$percent%',
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
                      ),

                      if (!isDone) ...[
                        SizedBox(
                          height:
                          screenWidth *
                              0.012,
                        ),

                        ClipRRect(
                          borderRadius:
                          BorderRadius
                              .circular(
                            30,
                          ),
                          child:
                          LinearProgressIndicator(
                            value:
                            progress,
                            minHeight:
                            screenWidth *
                                0.012,
                            backgroundColor:
                            Colors.white
                                .withOpacity(
                              0.07,
                            ),
                            color:
                            Colors.amberAccent,
                          ),
                        ),
                      ],
                    ] else
                      Text(
                        '페이지 정보 없음',
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
                ),
              ),

              SizedBox(
                width:
                screenWidth *
                    0.018,
              ),

              // =================================================
              // ACTION / COMPLETE
              // =================================================

              if (isDone)
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
                      0.11,
                    ),
                    shape:
                    BoxShape.circle,
                    border:
                    Border.all(
                      color:
                      Colors.amberAccent
                          .withOpacity(
                        0.28,
                      ),
                    ),
                  ),
                  child:
                  Icon(
                    Icons.check_rounded,
                    color:
                    Colors.amberAccent,
                    size:
                    screenWidth *
                        0.04,
                  ),
                )
              else
                Icon(
                  Icons
                      .chevron_right_rounded,
                  color:
                  Colors.white38,
                  size:
                  screenWidth *
                      0.05,
                ),
            ],
          ),
        ),
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
        width: width,
        height: height,
        fit: BoxFit.cover,
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
        width: width,
        height: height,
        fit: BoxFit.cover,
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

  // =========================================================
  // EMPTY
  // =========================================================

  Widget _buildEmptyState(
      double screenWidth,
      ) {
    return Padding(
      padding:
      EdgeInsets.all(
        screenWidth * 0.05,
      ),
      child:
      Container(
        width:
        double.infinity,
        padding:
        EdgeInsets.symmetric(
          horizontal:
          screenWidth * 0.04,
          vertical:
          screenWidth * 0.055,
        ),
        decoration:
        BoxDecoration(
          color:
          Colors.white
              .withOpacity(
            0.03,
          ),
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
        Column(
          children: [
            Icon(
              Icons
                  .menu_book_outlined,
              color:
              Colors.white30,
              size:
              screenWidth *
                  0.065,
            ),

            SizedBox(
              height:
              screenWidth *
                  0.018,
            ),

            Text(
              '선택할 수 있는 책이 없어요.',
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
}