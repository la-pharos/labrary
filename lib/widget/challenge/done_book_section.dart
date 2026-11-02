import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/widget/card_box.dart';

/// 권수형 챌린지에서
/// 도전 기간 내 완독한 책을 보여주는 위젯
class DoneBookSection extends StatefulWidget {
  final Challenge challenge;
  final bool isDoneMode;
  final List<String>? completedBookIds;
  final List<BookModel>? booksOverride;

  const DoneBookSection({
    super.key,
    required this.challenge,
    this.isDoneMode = false,
    this.completedBookIds,
    this.booksOverride,
  });

  @override
  State<DoneBookSection> createState() =>
      _DoneBookSectionState();
}

class _DoneBookSectionState
    extends State<DoneBookSection> {
  bool _isExpanded = false;

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
  // TARGET BOOKS
  // =========================================================

  List<BookModel> _resolveTargetBooks() {
    if (widget.booksOverride != null &&
        widget.booksOverride!.isNotEmpty) {
      return widget.booksOverride!;
    }

    if ((widget.challenge.participatingBooks ?? [])
        .isNotEmpty) {
      return widget.challenge.participatingBooks!;
    }

    return widget.challenge.requiredBooks ??
        const <BookModel>[];
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    if (widget.challenge.method !=
        ChallengeMethod.quantityBased) {
      return const SizedBox.shrink();
    }

    final screenWidth =
        MediaQuery.of(context).size.width;

    final attempt =
    widget.challenge.attempts.isNotEmpty
        ? widget.challenge.attempts.last
        : null;

    if (attempt == null) {
      return const SizedBox.shrink();
    }

    final start =
        widget.challenge.startDate?.toLocal() ??
            attempt.startDate.toLocal();

    DateTime? end =
    widget.challenge.endDate?.toLocal();

    if (end == null) {
      if (attempt.endDate != null) {
        end = attempt.endDate!.toLocal();
      } else if (attempt.selectedDuration != null) {
        end = start.add(
          Duration(
            days:
            attempt.selectedDuration! - 1,
          ),
        );
      }
    }

    final savedBooks =
        context
            .read<SavedBooksProvider>()
            .savedBooks;

    final targets =
    _resolveTargetBooks();

    final targetKeys = targets
        .map(_keyForBook)
        .whereType<String>()
        .toSet();

    final hasTargetFilter =
        targetKeys.isNotEmpty;

    // =======================================================
    // 표시할 완독 도서 ID
    // =======================================================

    final booksToShowIds =
    widget.isDoneMode
        ? (widget.completedBookIds ??
        attempt.completedBookIds)
        : savedBooks
        .where(
          (book) {
        final completedAt =
        book.endDate?.toLocal();

        if (completedAt == null ||
            book.category != 'done') {
          return false;
        }

        final afterStart =
        !completedAt.isBefore(start);

        final beforeEnd =
            end == null ||
                !completedAt.isAfter(end);

        if (!afterStart ||
            !beforeEnd) {
          return false;
        }

        if (!hasTargetFilter) {
          return true;
        }

        final key =
        _keyForBook(book);

        return key != null &&
            targetKeys.contains(key);
      },
    )
        .map(
          (book) => book.id,
    )
        .toList();

    final completedBooksInPeriod =
    savedBooks
        .where(
          (book) =>
          booksToShowIds.contains(
            book.id,
          ),
    )
        .toList();

    final isOverflow =
        completedBooksInPeriod.length > 6;

    final booksToDisplay =
    _isExpanded || !isOverflow
        ? completedBooksInPeriod
        : completedBooksInPeriod
        .take(6)
        .toList();

    // =======================================================
    // EMPTY
    // =======================================================

    if (booksToDisplay.isEmpty) {
      return _buildEmptyState(
        screenWidth,
      );
    }

    // =======================================================
    // LIST
    // =======================================================

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        ...booksToDisplay.map(
              (book) => Padding(
            padding: EdgeInsets.only(
              bottom:
              screenWidth * 0.025,
            ),
            child: _buildBookCard(
              book,
              screenWidth,
            ),
          ),
        ),

        if (isOverflow)
          _buildMoreButton(
            screenWidth,
          ),
      ],
    );
  }

  // =========================================================
  // BOOK CARD
  // =========================================================

  Widget _buildBookCard(
      BookModel book,
      double screenWidth,
      ) {
    final coverWidth =
        screenWidth * 0.14;

    final coverHeight =
        coverWidth * 1.42;

    final completedAt =
    book.endDate?.toLocal();

    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(
        screenWidth * 0.03,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.center,
        children: [
          // ===================================================
          // COVER
          // ===================================================

          Container(
            decoration: BoxDecoration(
              borderRadius:
              BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withOpacity(0.20),
                  blurRadius: 7,
                  offset:
                  const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius:
              BorderRadius.circular(7),
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
          // INFO
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
                    screenWidth * 0.032,
                    fontWeight:
                    FontWeight.bold,
                    height: 1.35,
                  ),
                ),

                if (book.author
                    .trim()
                    .isNotEmpty) ...[
                  SizedBox(
                    height:
                    screenWidth * 0.007,
                  ),

                  Text(
                    book.author,
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                      Colors.white54,
                      fontFamily:
                      'kopub',
                      fontSize:
                      screenWidth * 0.027,
                    ),
                  ),
                ],

                SizedBox(
                  height:
                  screenWidth * 0.03,
                ),

                Row(
                  children: [
                    Icon(
                      Icons
                          .calendar_today_outlined,
                      color: Colors
                          .amberAccent
                          .withOpacity(0.75),
                      size:
                      screenWidth * 0.032,
                    ),

                    SizedBox(
                      width:
                      screenWidth * 0.012,
                    ),

                    Text(
                      completedAt != null
                          ? '${_formatDate(completedAt)} 완독'
                          : '완독 완료',
                      style: TextStyle(
                        color:
                        Colors.amberAccent,
                        fontFamily:
                        'kopub',
                        fontSize:
                        screenWidth * 0.027,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(
            width:
            screenWidth * 0.02,
          ),

          // ===================================================
          // COMPLETE BADGE
          // ===================================================

          _buildCompletedBadge(
            screenWidth,
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

  // =========================================================
  // EMPTY
  // =========================================================

  Widget _buildEmptyState(
      double screenWidth,
      ) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(
        screenWidth * 0.04,
      ),
      child: Row(
        children: [
          Container(
            width:
            screenWidth * 0.085,
            height:
            screenWidth * 0.085,
            decoration: BoxDecoration(
              color: Colors.white
                  .withOpacity(0.05),
              borderRadius:
              BorderRadius.circular(10),
            ),
            child: Icon(
              Icons
                  .menu_book_outlined,
              color:
              Colors.white38,
              size:
              screenWidth * 0.043,
            ),
          ),

          SizedBox(
            width:
            screenWidth * 0.025,
          ),

          Expanded(
            child: Text(
              widget.isDoneMode
                  ? '완독한 책 기록이 없어요.'
                  : '아직 도전 기간에 완독한 책이 없어요.',
              style: TextStyle(
                color:
                Colors.white54,
                fontFamily:
                'kopub',
                fontSize:
                screenWidth * 0.029,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MORE
  // =========================================================

  Widget _buildMoreButton(
      double screenWidth,
      ) {
    return Center(
      child: TextButton.icon(
        onPressed: () {
          setState(() {
            _isExpanded =
            !_isExpanded;
          });
        },
        icon: Icon(
          _isExpanded
              ? Icons
              .keyboard_arrow_up_rounded
              : Icons
              .keyboard_arrow_down_rounded,
          color:
          Colors.white54,
          size:
          screenWidth * 0.045,
        ),
        label: Text(
          _isExpanded
              ? '접기'
              : '더 보기',
          style: TextStyle(
            color:
            Colors.white60,
            fontFamily:
            'kopub',
            fontSize:
            screenWidth * 0.029,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // DATE
  // =========================================================

  String _formatDate(
      DateTime date,
      ) {
    final year =
    (date.year % 100)
        .toString()
        .padLeft(2, '0');

    final month =
    date.month
        .toString()
        .padLeft(2, '0');

    final day =
    date.day
        .toString()
        .padLeft(2, '0');

    return '$year.$month.$day';
  }

}