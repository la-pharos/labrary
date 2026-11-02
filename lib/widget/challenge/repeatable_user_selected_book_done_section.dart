import 'package:flutter/material.dart';

import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/challenge_attempt_model.dart';
import 'package:dayverse_book/widget/card_box.dart';

/// 단일 + 사용자 지정도서 + 페이지 연동
/// 반복 가능 챌린지 완료 기록 위젯
class RepeatableUserSelectedBookDoneSection
    extends StatefulWidget {
  final Challenge challenge;
  final ChallengeAttempt? attempt;
  final List<BookModel> savedBooks;

  const RepeatableUserSelectedBookDoneSection({
    super.key,
    required this.challenge,
    required this.attempt,
    required this.savedBooks,
  });

  @override
  State<RepeatableUserSelectedBookDoneSection>
  createState() =>
      _RepeatableUserSelectedBookDoneSectionState();
}

class _RepeatableUserSelectedBookDoneSectionState
    extends State<
        RepeatableUserSelectedBookDoneSection> {
  final Set<String> _expandedAttemptIds = {};

  @override
  void initState() {
    super.initState();

    // 현재 완료한 도전은 기본 펼침
    if (widget.attempt != null) {
      _expandedAttemptIds.add(
        widget.attempt!.attemptId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final attempt = widget.attempt;
    final savedBooks = widget.savedBooks;

    final screenWidth =
        MediaQuery.of(context).size.width;

    // =========================================================
    // 성공한 attempt만 표시
    // ⚠️ 기존 로직 유지
    // =========================================================

    final successAttempts = challenge.attempts
        .where(
          (a) =>
      a.completed &&
          a.isSuccessful,
    )
        .toList();

    if (successAttempts.isEmpty) {
      return _buildEmptyState(
        screenWidth,
      );
    }

    // =========================================================
    // 현재 보고 있는 attempt를 가장 위로
    // 이후 성공 attempt는 최신순
    // ⚠️ 기존 로직 유지
    // =========================================================

    final List<ChallengeAttempt>
    orderedAttempts = [];

    if (attempt != null &&
        successAttempts.any(
              (a) =>
          a.attemptId ==
              attempt.attemptId,
        )) {
      orderedAttempts.add(
        attempt,
      );
    }

    final rest = successAttempts
        .where(
          (a) =>
      attempt == null ||
          a.attemptId !=
              attempt.attemptId,
    )
        .toList()
      ..sort(
            (a, b) =>
            b.startDate.compareTo(
              a.startDate,
            ),
      );

    orderedAttempts.addAll(rest);

    // =========================================================
    // UI
    // =========================================================

    return Column(
      children: [
        ...orderedAttempts.map(
              (currentAttempt) {
            final isCurrent =
                attempt != null &&
                    currentAttempt.attemptId ==
                        attempt.attemptId;

            final attemptNumber =
            _getAttemptNumber(
              challenge,
              currentAttempt,
            );

            final books =
            _resolveAttemptBooks(
              currentAttempt,
              savedBooks,
            );

            final isExpanded =
            _expandedAttemptIds.contains(
              currentAttempt.attemptId,
            );

            return _buildAttemptCard(
              attempt: currentAttempt,
              books: books,
              attemptNumber:
              attemptNumber,
              isCurrent:
              isCurrent,
              isExpanded:
              isExpanded,
              screenWidth:
              screenWidth,
            );
          },
        ),
      ],
    );
  }

  // =========================================================
  // ATTEMPT NUMBER
  // ⚠️ 기존 로직 유지
  // =========================================================

  int _getAttemptNumber(
      Challenge challenge,
      ChallengeAttempt target,
      ) {
    final index =
    challenge.attempts.indexWhere(
          (a) =>
      a.attemptId ==
          target.attemptId,
    );

    return index >= 0
        ? index + 1
        : 1;
  }

  // =========================================================
  // ATTEMPT BOOKS
  // ⚠️ 기존 우선순위 유지
  // =========================================================

  List<BookModel> _resolveAttemptBooks(
      ChallengeAttempt attempt,
      List<BookModel> savedBooks,
      ) {
    // 1순위: attempt에 저장된 참여 도서
    final participatedBooks =
        attempt.participatedBooks ?? [];

    if (participatedBooks.isNotEmpty) {
      return participatedBooks;
    }

    // 2순위: completedBookIds로 savedBooks 매칭
    final completedIds =
        attempt.completedBookIds;

    if (completedIds.isEmpty) {
      return [];
    }

    return savedBooks
        .where(
          (book) =>
          completedIds.contains(
            book.id,
          ),
    )
        .toList();
  }

  // =========================================================
  // ATTEMPT CARD
  // =========================================================

  Widget _buildAttemptCard({
    required ChallengeAttempt attempt,
    required List<BookModel> books,
    required int attemptNumber,
    required bool isCurrent,
    required bool isExpanded,
    required double screenWidth,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        bottom:
        screenWidth * 0.025,
      ),
      child: CardBox(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // =================================================
            // HEADER
            // =================================================

            InkWell(
              borderRadius:
              BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedAttemptIds.remove(
                      attempt.attemptId,
                    );
                  } else {
                    _expandedAttemptIds.add(
                      attempt.attemptId,
                    );
                  }
                });
              },
              child: Padding(
                padding: EdgeInsets.all(
                  screenWidth * 0.035,
                ),
                child: Row(
                  children: [
                    // 완료 아이콘
                    Container(
                      width:
                      screenWidth * 0.085,
                      height:
                      screenWidth * 0.085,
                      decoration:
                      BoxDecoration(
                        color: Colors.amberAccent
                            .withOpacity(
                          0.10,
                        ),
                        shape:
                        BoxShape.circle,
                        border: Border.all(
                          color:
                          Colors.amberAccent
                              .withOpacity(
                            0.25,
                          ),
                        ),
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        color:
                        Colors.amberAccent,
                        size:
                        screenWidth *
                            0.046,
                      ),
                    ),

                    SizedBox(
                      width:
                      screenWidth * 0.025,
                    ),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '$attemptNumber번째 도전',
                                  style:
                                  TextStyle(
                                    color:
                                    Colors.white,
                                    fontSize:
                                    screenWidth *
                                        0.034,
                                    fontWeight:
                                    FontWeight
                                        .bold,
                                    fontFamily:
                                    'kopub',
                                  ),
                                ),
                              ),

                              if (isCurrent) ...[
                                SizedBox(
                                  width:
                                  screenWidth *
                                      0.018,
                                ),

                                _buildCurrentBadge(
                                  screenWidth,
                                ),
                              ],
                            ],
                          ),

                          SizedBox(
                            height:
                            screenWidth *
                                0.009,
                          ),

                          Text(
                            _buildPeriodText(
                              attempt,
                            ),
                            style:
                            TextStyle(
                              color:
                              Colors.white
                                  .withOpacity(
                                0.48,
                              ),
                              fontSize:
                              screenWidth *
                                  0.027,
                              fontFamily:
                              'kopub',
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(
                      width:
                      screenWidth * 0.015,
                    ),

                    Icon(
                      isExpanded
                          ? Icons
                          .keyboard_arrow_up_rounded
                          : Icons
                          .keyboard_arrow_down_rounded,
                      color:
                      Colors.white38,
                      size:
                      screenWidth * 0.055,
                    ),
                  ],
                ),
              ),
            ),

            // =================================================
            // EXPANDED CONTENT
            // =================================================

            AnimatedCrossFade(
              firstChild:
              const SizedBox.shrink(),
              secondChild:
              _buildExpandedContent(
                attempt:
                attempt,
                books:
                books,
                screenWidth:
                screenWidth,
              ),
              crossFadeState:
              isExpanded
                  ? CrossFadeState
                  .showSecond
                  : CrossFadeState
                  .showFirst,
              duration:
              const Duration(
                milliseconds: 220,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // EXPANDED CONTENT
  // =========================================================

  Widget _buildExpandedContent({
    required ChallengeAttempt attempt,
    required List<BookModel> books,
    required double screenWidth,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        screenWidth * 0.035,
        0,
        screenWidth * 0.035,
        screenWidth * 0.035,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Divider(
            color:
            Colors.white.withOpacity(
              0.07,
            ),
            height: 1,
          ),

          SizedBox(
            height:
            screenWidth * 0.03,
          ),

          // 도전 정보
          _buildInfoRow(
            label:
            '도전 기간',
            value:
            _buildPeriodText(
              attempt,
            ),
            screenWidth:
            screenWidth,
          ),

          if (attempt.selectedDuration !=
              null) ...[
            SizedBox(
              height:
              screenWidth * 0.018,
            ),

            _buildInfoRow(
              label:
              '선택 기간',
              value:
              '${attempt.selectedDuration}일',
              screenWidth:
              screenWidth,
            ),
          ],

          SizedBox(
            height:
            screenWidth * 0.035,
          ),

          // 완료 도서 개수
          Row(
            children: [


              Text(
                '완료한 도서',
                style: TextStyle(
                  color:
                  Colors.white70,
                  fontSize:
                  screenWidth * 0.029,
                  fontWeight:
                  FontWeight.w600,
                  fontFamily:
                  'kopub',
                ),
              ),

              const Spacer(),

              Text(
                '${books.length}권',
                style: TextStyle(
                  color:
                  Colors.amberAccent,
                  fontSize:
                  screenWidth * 0.029,
                  fontWeight:
                  FontWeight.bold,
                  fontFamily:
                  'kopub',
                ),
              ),
            ],
          ),

          SizedBox(
            height:
            screenWidth * 0.022,
          ),

          if (books.isEmpty)
            _buildBooksEmptyState(
              screenWidth,
            )
          else
            ...books.map(
                  (book) =>
                  _buildBookCard(
                    book:
                    book,
                    screenWidth:
                    screenWidth,
                  ),
            ),
        ],
      ),
    );
  }

  // =========================================================
  // INFO ROW
  // =========================================================

  Widget _buildInfoRow({
    required String label,
    required String value,
    required double screenWidth,
  }) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        SizedBox(
          width:
          screenWidth * 0.18,
          child: Text(
            label,
            style: TextStyle(
              color:
              Colors.white38,
              fontFamily:
              'kopub',
              fontSize:
              screenWidth * 0.027,
            ),
          ),
        ),

        Expanded(
          child: Text(
            value,
            textAlign:
            TextAlign.right,
            style: TextStyle(
              color:
              Colors.white70,
              fontFamily:
              'kopub',
              fontSize:
              screenWidth * 0.027,
              fontWeight:
              FontWeight.w500,
            ),
          ),
        ),
      ],
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

    return Container(
      margin: EdgeInsets.only(
        bottom:
        screenWidth * 0.02,
      ),
      padding: EdgeInsets.all(
        screenWidth * 0.025,
      ),
      decoration:
      BoxDecoration(
        color: Colors.white
            .withOpacity(0.035),
        borderRadius:
        BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white
              .withOpacity(0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.center,
        children: [
          // COVER
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
                      .withOpacity(0.18),
                  blurRadius: 6,
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
                imageWidth,
                imageHeight,
              ),
            ),
          ),

          SizedBox(
            width:
            screenWidth * 0.027,
          ),

          // INFO
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
                    fontSize:
                    screenWidth *
                        0.03,
                    fontWeight:
                    FontWeight.bold,
                    fontFamily:
                    'kopub',
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
                    maxLines: 1,
                    overflow:
                    TextOverflow
                        .ellipsis,
                    style:
                    TextStyle(
                      color:
                      Colors.white54,
                      fontSize:
                      screenWidth *
                          0.026,
                      fontFamily:
                      'kopub',
                    ),
                  ),
                ],

                if (book.pageCount > 0) ...[
                  SizedBox(
                    height:
                    screenWidth *
                        0.014,
                  ),

                  Text(
                    '${book.pageCount}페이지 완독',
                    style:
                    TextStyle(
                      color:
                      Colors.amberAccent,
                      fontSize:
                      screenWidth *
                          0.026,
                      fontWeight:
                      FontWeight.w600,
                      fontFamily:
                      'kopub',
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

          _buildCompletedBadge(
            screenWidth,
          ),
        ],
      ),
    );
  }

  // =========================================================
  // CURRENT BADGE
  // =========================================================

  Widget _buildCurrentBadge(
      double screenWidth,
      ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal:
        screenWidth * 0.018,
        vertical:
        screenWidth * 0.008,
      ),
      decoration:
      BoxDecoration(
        color: Colors.amberAccent
            .withOpacity(0.11),
        borderRadius:
        BorderRadius.circular(30),
        border: Border.all(
          color: Colors.amberAccent
              .withOpacity(0.28),
        ),
      ),
      child: Text(
        '최근 완료',
        style: TextStyle(
          color:
          Colors.amberAccent,
          fontSize:
          screenWidth * 0.023,
          fontWeight:
          FontWeight.bold,
          fontFamily:
          'kopub',
        ),
      ),
    );
  }

  // =========================================================
  // COMPLETE BADGE
  // =========================================================

  Widget _buildCompletedBadge(
      double screenWidth,
      ) {
    return Container(
      width:
      screenWidth * 0.068,
      height:
      screenWidth * 0.068,
      decoration:
      BoxDecoration(
        color: Colors.amberAccent
            .withOpacity(0.10),
        shape:
        BoxShape.circle,
        border: Border.all(
          color: Colors.amberAccent
              .withOpacity(0.30),
        ),
      ),
      child: Icon(
        Icons.check_rounded,
        color:
        Colors.amberAccent,
        size:
        screenWidth * 0.04,
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
            (_, __, ___) =>
            _buildCoverFallback(
              width,
              height,
            ),
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
            (_, __, ___) =>
            _buildCoverFallback(
              width,
              height,
            ),
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
  // EMPTY STATES
  // =========================================================

  Widget _buildEmptyState(
      double screenWidth,
      ) {
    return CardBox(
      margin:
      EdgeInsets.zero,
      padding:
      EdgeInsets.all(
        screenWidth * 0.04,
      ),
      child: Row(
        children: [
          Icon(
            Icons
                .history_rounded,
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
              '완료 기록을 찾을 수 없어요.',
              style:
              TextStyle(
                color:
                Colors.white54,
                fontSize:
                screenWidth * 0.029,
                fontFamily:
                'kopub',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBooksEmptyState(
      double screenWidth,
      ) {
    return Container(
      width:
      double.infinity,
      padding:
      EdgeInsets.all(
        screenWidth * 0.03,
      ),
      decoration:
      BoxDecoration(
        color: Colors.white
            .withOpacity(0.03),
        borderRadius:
        BorderRadius.circular(12),
      ),
      child: Text(
        '이 도전의 도서 정보를 찾을 수 없어요.',
        style:
        TextStyle(
          color:
          Colors.white38,
          fontSize:
          screenWidth * 0.027,
          fontFamily:
          'kopub',
        ),
      ),
    );
  }

  // =========================================================
  // PERIOD
  // =========================================================

  String _buildPeriodText(
      ChallengeAttempt? attempt,
      ) {
    if (attempt == null) {
      return '-';
    }

    final start =
        attempt.startDate;

    final end =
        attempt.endDate;

    if (start == null &&
        end == null) {
      return '-';
    }

    if (start != null &&
        end != null) {
      return '${_formatDate(start)} ~ '
          '${_formatDate(end)}';
    }

    if (start != null) {
      return _formatDate(start);
    }

    return _formatDate(end!);
  }

  String _formatDate(
      DateTime date,
      ) {
    final local =
    date.toLocal();

    final year =
    (local.year % 100)
        .toString()
        .padLeft(2, '0');

    final month =
    local.month
        .toString()
        .padLeft(2, '0');

    final day =
    local.day
        .toString()
        .padLeft(2, '0');

    return '$year.$month.$day';
  }
}