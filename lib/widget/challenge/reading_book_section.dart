import 'package:flutter/material.dart';

import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/widget/card_box.dart';

/// 지정 도서 + 페이지 연동 챌린지의
/// 진행/완료 화면 공용 위젯
class ReadingBookSection extends StatelessWidget {
  final Challenge challenge;
  final List<BookModel> savedBooks;

  final bool isDoneMode;
  final List<String>? completedBookIds;

  /// 풀/참여 도서 등 외부에서 주입하는 타겟 리스트
  final List<BookModel>? booksOverride;

  /// 부모에서 풀/네트워크 로딩 여부 전달
  final bool isLoading;

  const ReadingBookSection({
    super.key,
    required this.challenge,
    required this.savedBooks,
    this.isDoneMode = false,
    this.completedBookIds,
    this.booksOverride,
    this.isLoading = false,
  });

  // =========================================================
  // BOOK KEY
  // =========================================================

  String? _keyForBook(BookModel book) {
    if (book.id.isNotEmpty) {
      return book.id;
    }

    final isbn = book.isbn;

    if (isbn != null &&
        isbn.isNotEmpty) {
      return isbn;
    }

    return null;
  }

  // =========================================================
  // ENRICH
  // =========================================================

  List<BookModel> _enrichWithSaved(
      List<BookModel> books,
      List<BookModel> saved,
      ) {
    final savedMap =
    <String, BookModel>{
      for (final book in saved)
        if (_keyForBook(book) != null)
          _keyForBook(book)!: book,
    };

    return books.map((book) {
      final key =
      _keyForBook(book);

      final savedBook =
      key != null
          ? savedMap[key]
          : null;

      if (savedBook == null) {
        return book;
      }

      return book.copyWith(
        imageUrl:
        book.imageUrl?.isNotEmpty ==
            true
            ? book.imageUrl
            : savedBook.imageUrl,

        pageCount:
        book.pageCount > 0
            ? book.pageCount
            : savedBook.pageCount,

        publisher:
        book.publisher?.isNotEmpty ==
            true
            ? book.publisher
            : savedBook.publisher,

        itemId:
        book.itemId ??
            savedBook.itemId,

        description:
        book.description ??
            savedBook.description,
      );
    }).toList();
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
        errorBuilder: (
            _,
            __,
            ___,
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
        errorBuilder: (
            _,
            __,
            ___,
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
      width: width,
      height: height,
      color: Colors.white
          .withOpacity(0.055),
      alignment:
      Alignment.center,
      child: const Icon(
        Icons.book_rounded,
        color:
        Colors.white38,
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width;

    final spacing =
        screenWidth * 0.025;

    final isSystemDefined =
        challenge.specificBookMode ==
            SpecificBookMode.systemDefined;

    final isUserDefined =
        challenge.specificBookMode ==
            SpecificBookMode.userDefined;

    // =======================================================
    // RECORD PAGE DATA
    // =======================================================

    final Map<String, dynamic>
    recordPages = () {
      final record =
      challenge.attempts.isNotEmpty
          ? (challenge
          .attempts
          .last
          .recordData
      as Map?)
          ?.cast<
          String,
          dynamic>()
          : null;

      if (record == null) {
        return const <
            String,
            dynamic>{};
      }

      if (record['bookReadPages']
      is Map) {
        return Map<
            String,
            dynamic>.from(
          record['bookReadPages']
          as Map,
        );
      }

      if (record['recordData']
      is Map &&
          (record['recordData']
          as Map)[
          'bookReadPages'] is Map) {
        return Map<
            String,
            dynamic>.from(
          (record['recordData']
          as Map)[
          'bookReadPages'] as Map,
        );
      }

      return const <
          String,
          dynamic>{};
    }();

    // =======================================================
    // TARGET BOOKS
    // =======================================================

    List<BookModel> books;

    if (booksOverride != null &&
        booksOverride!.isNotEmpty) {
      books =
      booksOverride!;
    } else if (isSystemDefined &&
        challenge.requiredBooks
            ?.isNotEmpty ==
            true) {
      books =
      challenge.requiredBooks!;
    } else if (isUserDefined &&
        challenge.attempts.isNotEmpty &&
        challenge
            .attempts
            .last
            .participatedBooks
            ?.isNotEmpty ==
            true) {
      books = challenge
          .attempts
          .last
          .participatedBooks!;
    } else {
      books =
      const <BookModel>[];
    }

    books = _enrichWithSaved(
      books,
      savedBooks,
    );

    // =======================================================
    // LOADING
    // =======================================================

    if (isLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(
          vertical:
          screenWidth * 0.045,
        ),
        child: const Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child:
            CircularProgressIndicator(
              strokeWidth: 2.5,
              color:
              Colors.amberAccent,
            ),
          ),
        ),
      );
    }

    // =======================================================
    // EMPTY
    // =======================================================

    if (books.isEmpty) {
      return CardBox(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.all(
          screenWidth * 0.04,
        ),
        child: Row(
          children: [
            Icon(
              Icons
                  .menu_book_outlined,
              color:
              Colors.white38,
              size:
              screenWidth * 0.045,
            ),

            SizedBox(
              width:
              screenWidth * 0.025,
            ),

            Expanded(
              child: Text(
                '표시할 도서가 없어요.',
                style: TextStyle(
                  color:
                  Colors.white54,
                  fontFamily:
                  'kopub',
                  fontSize:
                  screenWidth *
                      0.029,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // =======================================================
    // BOOK LIST
    // =======================================================

    return Column(
      children: [
        ...books.map(
              (book) {
            final pageCount =
                book.pageCount;

            // savedBooks에서 현재 페이지
            final savedBook =
            savedBooks.firstWhere(
                  (saved) =>
              _keyForBook(saved) ==
                  _keyForBook(book),
              orElse:
                  () => book,
            );

            final readFromBook =
                savedBook.pageRead;

            // recordPages의 id/isbn 양쪽 검사
            final recordId =
                book.id;

            final recordIsbn =
                book.isbn ?? '';

            final readFromRecord = () {
              final byId =
              recordPages[
              recordId];

              if (byId != null) {
                return int.tryParse(
                  byId.toString(),
                ) ??
                    0;
              }

              final byIsbn =
              recordIsbn
                  .isNotEmpty
                  ? recordPages[
              recordIsbn]
                  : null;

              if (byIsbn != null) {
                return int.tryParse(
                  byIsbn
                      .toString(),
                ) ??
                    0;
              }

              return 0;
            }();

            final pageRead =
            isDoneMode
                ? pageCount
                : readFromBook >
                readFromRecord
                ? readFromBook
                : readFromRecord;

            final percentage =
            pageCount > 0
                ? (pageRead /
                pageCount *
                100)
                .clamp(
              0,
              100,
            )
                .toInt()
                : 0;

            final isDone =
                isDoneMode ||
                    book.isCompleted ==
                        true ||
                    (pageCount > 0 &&
                        pageRead >=
                            pageCount);

            return Padding(
              padding:
              EdgeInsets.only(
                bottom:
                spacing,
              ),
              child:
              _buildBookCard(
                book:
                book,
                pageRead:
                pageRead,
                pageCount:
                pageCount,
                percentage:
                percentage,
                isDone:
                isDone,
                screenWidth:
                screenWidth,
              ),
            );
          },
        ),
      ],
    );
  }

  // =========================================================
  // BOOK CARD
  // =========================================================

  Widget _buildBookCard({
    required BookModel book,
    required int pageRead,
    required int pageCount,
    required int percentage,
    required bool isDone,
    required double screenWidth,
  }) {
    final coverWidth =
        screenWidth * 0.14;

    final coverHeight =
        coverWidth * 1.42;

    return CardBox(
      margin:
      EdgeInsets.zero,
      padding:
      EdgeInsets.all(
        screenWidth * 0.03,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          // ===================================================
          // COVER
          // ===================================================

          Container(
            decoration:
            BoxDecoration(
              borderRadius:
              BorderRadius.circular(
                7,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withOpacity(0.20),
                  blurRadius: 7,
                  offset:
                  const Offset(
                    0,
                    3,
                  ),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius:
              BorderRadius.circular(
                7,
              ),
              child: _buildCover(
                book.imageUrl,
                coverWidth,
                coverHeight,
              ),
            ),
          ),

          SizedBox(
            width:
            screenWidth * 0.03,
          ),

          // ===================================================
          // BOOK INFO
          // ===================================================

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 2,
                  overflow:
                  TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                    Colors.white,
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth *
                        0.032,
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
                        0.007,
                  ),

                  Text(
                    book.author,
                    maxLines: 1,
                    overflow:
                    TextOverflow
                        .ellipsis,
                    style:
                    TextStyle(
                      color: Colors
                          .white54,
                      fontFamily:
                      'kopub',
                      fontSize:
                      screenWidth *
                          0.027,
                    ),
                  ),
                ],

                SizedBox(
                  height:
                  screenWidth *
                      0.018,
                ),

                if (isDoneMode)
                  _buildDoneResult(
                    pageCount:
                    pageCount,
                    screenWidth:
                    screenWidth,
                  )
                else
                  _buildOngoingProgress(
                    pageRead:
                    pageRead,
                    pageCount:
                    pageCount,
                    percentage:
                    percentage,
                    isDone:
                    isDone,
                    screenWidth:
                    screenWidth,
                  ),
              ],
            ),
          ),

          // ===================================================
          // COMPLETION BADGE
          // ===================================================

          if (isDone) ...[
            SizedBox(
              width:
              screenWidth * 0.02,
            ),

            _buildCompletedBadge(
              screenWidth,
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================
  // ONGOING MODE
  // =========================================================

  Widget _buildOngoingProgress({
    required int pageRead,
    required int pageCount,
    required int percentage,
    required bool isDone,
    required double screenWidth,
  }) {
    if (pageCount <= 0) {
      return Text(
        '페이지 정보 없음',
        style: TextStyle(
          color:
          Colors.white38,
          fontFamily:
          'kopub',
          fontSize:
          screenWidth * 0.027,
        ),
      );
    }

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$pageRead / '
                    '$pageCount 페이지',
                style: TextStyle(
                  color:
                  Colors.white60,
                  fontFamily:
                  'kopub',
                  fontSize:
                  screenWidth *
                      0.027,
                ),
              ),
            ),

            Text(
              '$percentage%',
              style: TextStyle(
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
                    0.027,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ],
        ),

        SizedBox(
          height:
          screenWidth * 0.014,
        ),

        ClipRRect(
          borderRadius:
          BorderRadius.circular(
            30,
          ),
          child:
          LinearProgressIndicator(
            value: (pageRead /
                pageCount)
                .clamp(
              0.0,
              1.0,
            )
                .toDouble(),
            minHeight:
            screenWidth * 0.015,
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
    );
  }

  // =========================================================
  // DONE MODE
  // =========================================================

  Widget _buildDoneResult({
    required int pageCount,
    required double screenWidth,
  }) {
    return Text(
      pageCount > 0
          ? '$pageCount페이지 완독'
          : '완독 완료',
      style: TextStyle(
        color:
        Colors.amberAccent,
        fontFamily:
        'kopub',
        fontSize:
        screenWidth * 0.028,
        fontWeight:
        FontWeight.w600,
      ),
    );
  }

  // =========================================================
  // COMPLETED BADGE
  // =========================================================

  Widget _buildCompletedBadge(
      double screenWidth,
      ) {
    return Container(
      width:
      screenWidth * 0.075,
      height:
      screenWidth * 0.075,
      decoration: BoxDecoration(
        color: Colors.amberAccent
            .withOpacity(0.12),
        shape:
        BoxShape.circle,
        border: Border.all(
          color: Colors.amberAccent
              .withOpacity(0.35),
        ),
      ),
      child: Icon(
        Icons.check_rounded,
        color:
        Colors.amberAccent,
        size:
        screenWidth * 0.045,
      ),
    );
  }
}