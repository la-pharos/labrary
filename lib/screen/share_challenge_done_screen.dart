import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/challenge_attempt_model.dart';
import 'package:dayverse_book/model/book_model.dart';

import 'package:dayverse_book/provider/saved_books_provider.dart';

import 'package:dayverse_book/service/challenge_record_service.dart';
import 'package:dayverse_book/service/book_api_service.dart';

import 'package:dayverse_book/utils/book_pool_loader.dart';
import 'package:dayverse_book/utils/challenge_check_utils.dart';

import 'package:dayverse_book/widget/card_box.dart';
import 'package:dayverse_book/widget/share_card_action_bar.dart';

import 'package:dayverse_book/widget/challenge/reading_book_section.dart';
import 'package:dayverse_book/widget/challenge/done_book_section.dart';
import 'package:dayverse_book/widget/challenge/stage_calendar.dart';
import 'package:dayverse_book/widget/challenge/repeatable_user_selected_book_done_section.dart';
import 'package:dayverse_book/widget/recurring_challenge_cover.dart';

class ShareChallengeDoneScreen extends StatefulWidget {
  final Challenge challenge;

  const ShareChallengeDoneScreen({
    super.key,
    required this.challenge,
  });

  @override
  State<ShareChallengeDoneScreen> createState() =>
      _ShareChallengeScreenState();
}

class _ShareChallengeScreenState
    extends State<ShareChallengeDoneScreen> {

  final GlobalKey _shareCardKey =
  GlobalKey();

  Map<String, dynamic>? recordData;

  bool _isProcessing = false;
  bool _isLoadingPoolBooks = false;

  List<BookModel> _poolBooks = [];


  // =========================================================
  // TARGET BOOKS
  // =========================================================

  List<BookModel> get _displayTargetBooks {
    if (_poolBooks.isNotEmpty) {
      return _poolBooks;
    }

    if ((widget.challenge.participatingBooks ?? [])
        .isNotEmpty) {
      return widget.challenge.participatingBooks!;
    }

    return widget.challenge.requiredBooks ??
        const [];
  }


  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();

    _loadChallengeRecord();

    WidgetsBinding.instance
        .addPostFrameCallback(
          (_) {
        _loadPoolBooksIfNeeded();
      },
    );
  }


  // =========================================================
  // RECORD
  // =========================================================

  Future<void> _loadChallengeRecord() async {
    try {
      final data =
      await ChallengeRecordService
          .fetchChallengeRecord(
        widget.challenge.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        recordData = data;
      });
    } catch (e) {
      debugPrint(
        '[ShareChallengeScreen] '
            '챌린지 기록 로드 실패: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        recordData = {};
      });
    }
  }


  // =========================================================
  // POOL BOOKS
  // =========================================================

  Future<void> _loadPoolBooksIfNeeded() async {
    final challenge =
        widget.challenge;

    final usePool =
        challenge.method ==
            ChallengeMethod.specificBooks &&
            challenge.specificBookMode ==
                SpecificBookMode.systemDefined &&
            (challenge.requiredBooksPoolId
                ?.isNotEmpty ??
                false);

    if (!usePool) {
      return;
    }

    if (_poolBooks.isNotEmpty) {
      return;
    }

    try {
      setState(() {
        _isLoadingPoolBooks = true;
      });

      var poolBooks =
      await BookPoolLoader
          .loadPoolAsBookModels(
        challenge.requiredBooksPoolId!,
      );

      poolBooks = poolBooks.map(
            (book) {
          final newId =
          book.id.isNotEmpty
              ? book.id
              : (book.isbn ?? '');

          final newIsbn =
          (book.isbn != null &&
              book.isbn!.isNotEmpty)
              ? book.isbn!
              : newId;

          return book.copyWith(
            id: newId,
            isbn: newIsbn,
          );
        },
      ).toList();

      final isbns = poolBooks
          .map(
            (book) => book.isbn,
      )
          .whereType<String>()
          .where(
            (isbn) => isbn.isNotEmpty,
      )
          .toSet()
          .toList();

      if (isbns.isNotEmpty) {
        final fetched =
        await BookApiService
            .fetchBooksByIsbnList(
          isbns,
        );

        final byIsbn = {
          for (final book in fetched)
            if ((book.isbn ?? '').isNotEmpty)
              book.isbn!: book,
        };

        poolBooks = poolBooks.map(
              (book) {
            final fetchedBook =
            byIsbn[book.isbn];

            if (fetchedBook == null) {
              return book;
            }

            return book.copyWith(
              title:
              fetchedBook.title.isNotEmpty
                  ? fetchedBook.title
                  : book.title,
              author:
              fetchedBook.author.isNotEmpty
                  ? fetchedBook.author
                  : book.author,
              pageCount:
              fetchedBook.pageCount > 0
                  ? fetchedBook.pageCount
                  : book.pageCount,
              imageUrl:
              fetchedBook.imageUrl ??
                  book.imageUrl,
              publisher:
              fetchedBook.publisher ??
                  book.publisher,
              itemId:
              fetchedBook.itemId ??
                  book.itemId,
              description:
              fetchedBook.description ??
                  book.description,
            );
          },
        ).toList();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _poolBooks = poolBooks;
      });
    } catch (e) {
      debugPrint(
        '[ShareChallengeScreen] '
            '풀 도서 로딩 실패: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPoolBooks = false;
        });
      }
    }
  }


  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final size =
        MediaQuery.of(context).size;

    final screenWidth =
        size.width;

    final screenHeight =
        size.height;

    final savedBooks =
        context
            .watch<SavedBooksProvider>()
            .savedBooks;

    final isLoading =
        recordData == null ||
            _isLoadingPoolBooks;

    return Scaffold(
      backgroundColor:
      const Color(0xFF013328),

      appBar: AppBar(
        backgroundColor:
        Colors.transparent,
        elevation: 0,
        foregroundColor:
        Colors.white,
        centerTitle: true,
        title: Text(
          '챌린지 완료 공유',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'kopub',
            fontSize:
            screenWidth * 0.045,
            fontWeight:
            FontWeight.bold,
          ),
        ),
      ),

      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: isLoading
                  ? const Center(
                child:
                CircularProgressIndicator(
                  color:
                  Colors.amberAccent,
                  strokeWidth: 2,
                ),
              )
                  : SingleChildScrollView(
                physics:
                const BouncingScrollPhysics(),
                padding:
                EdgeInsets.fromLTRB(
                  screenWidth * 0.05,
                  screenHeight * 0.015,
                  screenWidth * 0.05,
                  screenHeight * 0.04,
                ),
                child:
                RepaintBoundary(
                  key:
                  _shareCardKey,
                  child:
                  Container(
                    width:
                    double.infinity,
                    color:
                    const Color(
                      0xFF013328,
                    ),
                    padding:
                    EdgeInsets.fromLTRB(
                      screenWidth *
                          0.035,
                      screenWidth *
                          0.04,
                      screenWidth *
                          0.035,
                      screenWidth *
                          0.045,
                    ),
                    child:
                    Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [

                        // 1. COMPLETED HERO
                        _buildAchievementCover(
                          widget.challenge,
                          screenWidth,
                        ),

                        SizedBox(
                          height:
                          screenHeight *
                              0.035,
                        ),

                        // 2. RECORD
                        _buildSectionTitle(
                          screenWidth,
                          'CHALLENGE RECORD',
                        ),

                        SizedBox(
                          height:
                          screenHeight *
                              0.015,
                        ),

                        _buildChallengeRecordCard(
                          widget.challenge,
                          screenWidth,
                        ),

                        SizedBox(
                          height:
                          screenHeight *
                              0.04,
                        ),

                        // 3. TO-DO
                        _buildSectionTitle(
                          screenWidth,
                          'CHALLENGE TO-DO',
                        ),

                        SizedBox(
                          height:
                          screenHeight *
                              0.015,
                        ),

                        _buildChallengeResultSection(
                          widget.challenge,
                          recordData!,
                          savedBooks,
                        ),

                        SizedBox(
                          height:
                          screenWidth *
                              0.055,
                        ),

                        // 4. FOOTER
                        _buildShareFooter(
                          screenWidth,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            ShareCardActionBar(
              isProcessing:
              _isProcessing ||
                  isLoading,
              onSave:
              _saveImage,
              onShare:
              _shareImage,
            ),
          ],
        ),
      ),
    );
  }


  // =========================================================
  // ACHIEVEMENT COVER
  // =========================================================

  Widget _buildAchievementCover(
      Challenge challenge,
      double screenWidth,
      ) {
    final successfulCount =
    _successfulAttemptCount(
      challenge,
    );

    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: AspectRatio(
        aspectRatio: 0.9,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius:
                BorderRadius.circular(
                  16,
                ),
                child: _buildChallengeImage(
                  challenge,
                ),
              ),
            ),

            Positioned.fill(
              child: Container(
                decoration:
                BoxDecoration(
                  borderRadius:
                  BorderRadius.circular(
                    16,
                  ),
                  color:
                  Colors.black.withOpacity(
                    0.38,
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: Container(
                decoration:
                BoxDecoration(
                  borderRadius:
                  BorderRadius.circular(
                    16,
                  ),
                  gradient:
                  LinearGradient(
                    begin:
                    Alignment.topCenter,
                    end:
                    Alignment.bottomCenter,
                    colors: [
                      Colors.black
                          .withOpacity(
                        0.28,
                      ),
                      Colors.black
                          .withOpacity(
                        0.15,
                      ),
                      Colors.black
                          .withOpacity(
                        0.45,
                      ),
                    ],
                    stops: const [
                      0.0,
                      0.45,
                      1.0,
                    ],
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: Padding(
                padding:
                EdgeInsets.symmetric(
                  horizontal:
                  screenWidth * 0.06,
                  vertical:
                  screenWidth * 0.06,
                ),
                child: Column(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Container(
                      width:
                      screenWidth * 0.18,
                      height:
                      screenWidth * 0.18,
                      decoration:
                      BoxDecoration(
                        color:
                        Colors.amberAccent
                            .withOpacity(
                          0.16,
                        ),
                        shape:
                        BoxShape.circle,
                        border:
                        Border.all(
                          color:
                          Colors.amberAccent
                              .withOpacity(
                            0.45,
                          ),
                        ),
                      ),
                      child: Icon(
                        Icons
                            .emoji_events_rounded,
                        color:
                        Colors.amberAccent,
                        size:
                        screenWidth *
                            0.09,
                      ),
                    ),

                    SizedBox(
                      height:
                      screenWidth * 0.03,
                    ),

                    Text(
                      'COMPLETED',
                      style: TextStyle(
                        color:
                        Colors.amberAccent,
                        fontFamily:
                        'kopub',
                        fontSize:
                        screenWidth *
                            0.025,
                        fontWeight:
                        FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),

                    SizedBox(
                      height:
                      screenWidth * 0.03,
                    ),

                    Text(
                      challenge.title,
                      textAlign:
                      TextAlign.center,
                      style:
                      TextStyle(
                        color:
                        Colors.white,
                        fontFamily:
                        'kopub',
                        fontSize:
                        screenWidth *
                            0.052,
                        fontWeight:
                        FontWeight.bold,
                        height: 1.35,
                      ),
                    ),

                    if (successfulCount >
                        1) ...[
                      SizedBox(
                        height:
                        screenWidth *
                            0.03,
                      ),

                      Container(
                        padding:
                        EdgeInsets.symmetric(
                          horizontal:
                          screenWidth *
                              0.028,
                          vertical:
                          screenWidth *
                              0.012,
                        ),
                        decoration:
                        BoxDecoration(
                          color:
                          Colors.amberAccent
                              .withOpacity(
                            0.14,
                          ),
                          borderRadius:
                          BorderRadius.circular(
                            30,
                          ),
                          border:
                          Border.all(
                            color:
                            Colors.amberAccent
                                .withOpacity(
                              0.35,
                            ),
                          ),
                        ),
                        child: Text(
                          '$successfulCount회 달성',
                          style:
                          TextStyle(
                            color:
                            Colors.amberAccent,
                            fontFamily:
                            'kopub',
                            fontSize:
                            screenWidth *
                                0.028,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ),
                    ],

                    SizedBox(
                      height:
                      screenWidth * 0.03,
                    ),

                    Text(
                      _getCompletionMessage(
                        successfulCount,
                      ),
                      textAlign:
                      TextAlign.center,
                      style:
                      TextStyle(
                        color:
                        Colors.white
                            .withOpacity(
                          0.82,
                        ),
                        fontFamily:
                        'kopub',
                        fontSize:
                        screenWidth *
                            0.03,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              right:
              screenWidth * 0.035,
              bottom:
              screenWidth * 0.035,
              child: Container(
                width:
                screenWidth * 0.11,
                height:
                screenWidth * 0.11,
                decoration:
                BoxDecoration(
                  color:
                  const Color(
                    0xFF013328,
                  ).withOpacity(
                    0.92,
                  ),
                  shape:
                  BoxShape.circle,
                  border:
                  Border.all(
                    color:
                    Colors.amberAccent,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.check_rounded,
                  color:
                  Colors.amberAccent,
                  size:
                  screenWidth *
                      0.065,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  String _getCompletionMessage(
      int successfulCount,
      ) {
    if (successfulCount >= 10) {
      return '꾸준한 도전이 멋진 기록으로 쌓였어요.';
    }

    if (successfulCount >= 5) {
      return '같은 목표를 여러 번 끝까지 완주했어요.';
    }

    if (successfulCount >= 2) {
      return '또 하나의 완주 기록을 만들어냈어요.';
    }

    return '하나의 도전을 끝까지 완주했어요.';
  }


  // =========================================================
  // IMAGE
  // =========================================================

  Widget _buildChallengeImage(
      Challenge challenge,
      ) {
    // 정기 챌린지는 Flutter 커버로 표시
    if (RecurringChallengeCover.supports(challenge)) {
      return RecurringChallengeCover(
        challenge: challenge,
      );
    }

    // 일반 챌린지는 기존 이미지 사용
    final url = challenge.imageUrl;

    if (url.isEmpty) {
      return _buildImageFallback();
    }

    if (url.startsWith('http')) {
      return Image.network(
        url,
        width:
        double.infinity,
        height:
        double.infinity,
        fit:
        BoxFit.cover,
        errorBuilder:
            (_, __, ___) =>
            _buildImageFallback(),
      );
    }

    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        width:
        double.infinity,
        height:
        double.infinity,
        fit:
        BoxFit.cover,
        errorBuilder:
            (_, __, ___) =>
            _buildImageFallback(),
      );
    }

    return Image.file(
      File(url),
      width:
      double.infinity,
      height:
      double.infinity,
      fit:
      BoxFit.cover,
      errorBuilder:
          (_, __, ___) =>
          _buildImageFallback(),
    );
  }


  Widget _buildImageFallback() {
    return Container(
      color:
      Colors.white.withOpacity(
        0.055,
      ),
      child:
      const Center(
        child: Icon(
          Icons
              .emoji_events_outlined,
          color:
          Colors.white38,
          size: 48,
        ),
      ),
    );
  }


  // =========================================================
  // RECORD
  // =========================================================

  Widget _buildChallengeRecordCard(
      Challenge challenge,
      double screenWidth,
      ) {
    final attempt =
    _latestSuccessfulAttempt(
      challenge,
    );

    final startedAt =
        attempt?.startDate;

    final completedAt =
        attempt?.completedAt ??
            (
                attempt?.completed ==
                    true &&
                    attempt
                        ?.isSuccessful ==
                        true
                    ? attempt?.endDate
                    : null
            );

    final hasSeparateAttemptHistory =
    _isRepeatableUserSelectedPageChallenge(
      challenge,
    );

    if (hasSeparateAttemptHistory) {
      final successfulCount =
      _successfulAttemptCount(
        challenge,
      );

      return CardBox(
        margin:
        EdgeInsets.zero,
        padding:
        EdgeInsets.symmetric(
          vertical:
          screenWidth * 0.04,
          horizontal:
          screenWidth * 0.035,
        ),
        child: Row(
          children: [
            Expanded(
              child:
              _buildRecordItem(
                value:
                '$successfulCount회',
                label:
                '누적 달성',
                screenWidth:
                screenWidth,
              ),
            ),

            _buildRecordDivider(
              screenWidth,
            ),

            Expanded(
              child:
              _buildRecordItem(
                value:
                completedAt != null
                    ? _formatShortDate(
                  completedAt,
                )
                    : '-',
                label:
                '최근 완료',
                screenWidth:
                screenWidth,
              ),
            ),
          ],
        ),
      );
    }

    final duration =
    startedAt != null &&
        completedAt != null
        ? _calculateChallengeDays(
      startedAt,
      completedAt,
    )
        : null;

    return CardBox(
      margin:
      EdgeInsets.zero,
      padding:
      EdgeInsets.symmetric(
        vertical:
        screenWidth * 0.04,
        horizontal:
        screenWidth * 0.02,
      ),
      child: Row(
        children: [
          Expanded(
            child:
            _buildRecordItem(
              value:
              startedAt != null
                  ? _formatShortDate(
                startedAt,
              )
                  : '-',
              label:
              '시작',
              screenWidth:
              screenWidth,
            ),
          ),

          _buildRecordDivider(
            screenWidth,
          ),

          Expanded(
            child:
            _buildRecordItem(
              value:
              completedAt != null
                  ? _formatShortDate(
                completedAt,
              )
                  : '-',
              label:
              '완료',
              screenWidth:
              screenWidth,
            ),
          ),

          _buildRecordDivider(
            screenWidth,
          ),

          Expanded(
            child:
            _buildRecordItem(
              value:
              duration != null
                  ? '$duration일'
                  : '-',
              label:
              '도전 기간',
              screenWidth:
              screenWidth,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildRecordItem({
    required String value,
    required String label,
    required double screenWidth,
  }) {
    return Column(
      mainAxisSize:
      MainAxisSize.min,
      children: [
        Text(
          value,
          textAlign:
          TextAlign.center,
          style:
          TextStyle(
            color:
            Colors.white,
            fontFamily:
            'kopub',
            fontSize:
            screenWidth *
                0.035,
            fontWeight:
            FontWeight.bold,
          ),
        ),

        SizedBox(
          height:
          screenWidth * 0.012,
        ),

        Text(
          label,
          textAlign:
          TextAlign.center,
          style:
          TextStyle(
            color:
            Colors.white38,
            fontFamily:
            'kopub',
            fontSize:
            screenWidth *
                0.026,
          ),
        ),
      ],
    );
  }


  Widget _buildRecordDivider(
      double screenWidth,
      ) {
    return Container(
      width: 1,
      height:
      screenWidth * 0.09,
      color:
      Colors.white.withOpacity(
        0.08,
      ),
    );
  }


  // =========================================================
  // CHALLENGE TO-DO
  // =========================================================

  Widget _buildChallengeResultSection(
      Challenge challenge,
      Map<String, dynamic> record,
      List<BookModel> savedBooks,
      ) {
    final checkAction =
    getChallengeCheckActionType(
      challenge,
    );

    final attempt =
    _isRepeatableUserSelectedPageChallenge(
      challenge,
    )
        ? _latestSuccessfulAttempt(
      challenge,
    )
        : (
        challenge.attempts.isNotEmpty
            ? challenge.attempts.last
            : null
    );

    final completedBookIds =
        attempt?.completedBookIds ??
            [];

    // 반복형 + 사용자 지정 도서
    if (_isRepeatableUserSelectedPageChallenge(
      challenge,
    )) {
      final successAttempt =
      _latestSuccessfulAttempt(
        challenge,
      );

      if (successAttempt == null) {
        return const SizedBox();
      }

      return RepeatableUserSelectedBookDoneSection(
        challenge:
        challenge,
        attempt:
        successAttempt,
        savedBooks:
        savedBooks,
      );
    }

    // 지정 도서
    if (challenge.method ==
        ChallengeMethod.specificBooks) {
      return ReadingBookSection(
        challenge:
        challenge,
        savedBooks:
        savedBooks,
        completedBookIds:
        completedBookIds,
        isDoneMode:
        true,
        booksOverride:
        _displayTargetBooks,
      );
    }

    // 지정 권수
    if (challenge.method ==
        ChallengeMethod.quantityBased) {
      return DoneBookSection(
        challenge:
        challenge,
        completedBookIds:
        completedBookIds,
        isDoneMode:
        true,
        booksOverride:
        _displayTargetBooks,
      );
    }

    // 루틴
    if (challenge.category ==
        ChallengeCategory.routine &&
        checkAction !=
            ChallengeCheckActionType
                .libraryAuto) {
      return StageCalendar(
        challenge:
        challenge,
        recordDataOrBooks:
        record,
        isDoneMode:
        true,
      );
    }

    return const SizedBox();
  }


  // =========================================================
  // FOOTER
  // =========================================================

  Widget _buildShareFooter(
      double screenWidth,
      ) {
    return Padding(
      padding:
      EdgeInsets.symmetric(
        horizontal:
        screenWidth * 0.01,
      ),
      child: Row(
        children: [
          Text(
            'Labrary',
            style:
            TextStyle(
              color:
              Colors.white,
              fontFamily:
              'kopub',
              fontSize:
              screenWidth *
                  0.034,
              fontWeight:
              FontWeight.bold,
              letterSpacing:
              0.4,
            ),
          ),

          const Spacer(),

          Text(
            'Read. Challenge. Grow.',
            style:
            TextStyle(
              color:
              Colors.white.withOpacity(
                0.42,
              ),
              fontFamily:
              'kopub',
              fontSize:
              screenWidth *
                  0.023,
            ),
          ),
        ],
      ),
    );
  }


  // =========================================================
  // SECTION TITLE
  // =========================================================

  Widget _buildSectionTitle(
      double screenWidth,
      String title,
      ) {
    return Text(
      title,
      style:
      TextStyle(
        color:
        Colors.white.withOpacity(
          0.72,
        ),
        fontFamily:
        'kopub',
        fontSize:
        screenWidth * 0.032,
        fontWeight:
        FontWeight.w600,
        letterSpacing:
        1.5,
      ),
    );
  }


  // =========================================================
  // ATTEMPT UTILS
  // =========================================================

  ChallengeAttempt? _latestSuccessfulAttempt(
      Challenge challenge,
      ) {
    for (
    int i =
        challenge.attempts.length - 1;
    i >= 0;
    i--
    ) {
      final attempt =
      challenge.attempts[i];

      if (attempt.completed &&
          attempt.isSuccessful) {
        return attempt;
      }
    }

    return null;
  }


  int _successfulAttemptCount(
      Challenge challenge,
      ) {
    return challenge.attempts
        .where(
          (attempt) =>
      attempt.completed &&
          attempt.isSuccessful,
    )
        .length;
  }


  bool _isRepeatableUserSelectedPageChallenge(
      Challenge challenge,
      ) {
    return challenge.stageType ==
        ChallengeStageType.single &&
        challenge.method ==
            ChallengeMethod.specificBooks &&
        challenge.specificBookMode ==
            SpecificBookMode.userDefined &&
        challenge.isRepeatable ==
            true;
  }


  // =========================================================
  // DATE
  // =========================================================

  String _formatShortDate(
      DateTime date,
      ) {
    return DateFormat(
      'yy.MM.dd',
    ).format(date);
  }


  int _calculateChallengeDays(
      DateTime startedAt,
      DateTime completedAt,
      ) {
    final startDate =
    DateTime(
      startedAt.year,
      startedAt.month,
      startedAt.day,
    );

    final completionDate =
    DateTime(
      completedAt.year,
      completedAt.month,
      completedAt.day,
    );

    return completionDate
        .difference(
      startDate,
    )
        .inDays +
        1;
  }


  // =========================================================
  // CAPTURE
  // =========================================================

  Future<Uint8List>
  _captureShareCard() async {
    await WidgetsBinding
        .instance.endOfFrame;

    final cardContext =
        _shareCardKey
            .currentContext;

    if (cardContext == null) {
      throw Exception(
        '챌린지 완료 카드를 찾을 수 없습니다.',
      );
    }

    final renderObject =
    cardContext
        .findRenderObject();

    if (renderObject
    is! RenderRepaintBoundary) {
      throw Exception(
        '챌린지 완료 카드를 이미지로 변환할 수 없습니다.',
      );
    }

    final boundary =
        renderObject;

    const preferredPixelRatio =
    3.0;

    const maxOutputDimension =
    8000.0;

    final logicalWidth =
        boundary.size.width;

    final logicalHeight =
        boundary.size.height;

    if (logicalWidth <= 0 ||
        logicalHeight <= 0) {
      throw Exception(
        '공유 이미지의 크기를 확인할 수 없습니다.',
      );
    }

    final widthRatio =
        maxOutputDimension /
            logicalWidth;

    final heightRatio =
        maxOutputDimension /
            logicalHeight;

    final pixelRatio =
    math.min(
      preferredPixelRatio,
      math.min(
        widthRatio,
        heightRatio,
      ),
    );

    final safePixelRatio =
    math.max(
      pixelRatio,
      0.1,
    );

    final ui.Image image =
    await boundary.toImage(
      pixelRatio:
      safePixelRatio,
    );

    final byteData =
    await image.toByteData(
      format:
      ui.ImageByteFormat.png,
    );

    image.dispose();

    if (byteData == null) {
      throw Exception(
        '이미지 데이터를 생성하지 못했습니다.',
      );
    }

    return byteData.buffer
        .asUint8List();
  }


  // =========================================================
  // SAVE
  // =========================================================

  Future<void> _saveImage() async {
    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      bool hasAccess =
      await Gal.hasAccess();

      if (!hasAccess) {
        hasAccess =
        await Gal.requestAccess();
      }

      if (!hasAccess) {
        throw Exception(
          '사진 앨범 접근 권한이 필요합니다.',
        );
      }

      final imageBytes =
      await _captureShareCard();

      final timestamp =
          DateTime.now()
              .millisecondsSinceEpoch;

      await Gal.putImageBytes(
        imageBytes,
        name:
        'labrary_challenge_${widget.challenge.id}_$timestamp',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content:
            Text(
              '챌린지 완료 카드를 사진 앨범에 저장했어요.',
              style:
              TextStyle(
                fontFamily:
                'kopub',
              ),
            ),
          ),
        );
    } on GalException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content:
            Text(
              _galErrorMessage(
                e,
              ),
              style:
              const TextStyle(
                fontFamily:
                'kopub',
              ),
            ),
            backgroundColor:
            Colors.redAccent,
          ),
        );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content:
            Text(
              e
                  .toString()
                  .replaceFirst(
                'Exception: ',
                '',
              ),
              style:
              const TextStyle(
                fontFamily:
                'kopub',
              ),
            ),
            backgroundColor:
            Colors.redAccent,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }


  // =========================================================
  // SHARE
  // =========================================================

  Future<void> _shareImage(
      BuildContext shareContext,
      ) async {
    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final imageBytes =
      await _captureShareCard();

      final file =
      XFile.fromData(
        imageBytes,
        mimeType:
        'image/png',
        name:
        'labrary_challenge.png',
      );

      final renderBox =
      shareContext
          .findRenderObject()
      as RenderBox?;

      final shareOrigin =
      renderBox != null
          ? renderBox
          .localToGlobal(
        Offset.zero,
      ) &
      renderBox.size
          : const Rect
          .fromLTWH(
        0,
        0,
        1,
        1,
      );

      await Share.shareXFiles(
        [file],
        fileNameOverrides:
        const [
          'labrary_challenge.png',
        ],
        sharePositionOrigin:
        shareOrigin,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content:
            Text(
              '공유 준비 중 오류가 발생했습니다.\n$e',
              style:
              const TextStyle(
                fontFamily:
                'kopub',
              ),
            ),
            backgroundColor:
            Colors.redAccent,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }


  // =========================================================
  // GAL ERROR
  // =========================================================

  String _galErrorMessage(
      GalException exception,
      ) {
    switch (exception.type) {
      case GalExceptionType.accessDenied:
        return '사진 앨범 접근 권한이 거부되었습니다.';

      case GalExceptionType.notEnoughSpace:
        return '기기의 저장 공간이 부족합니다.';

      case GalExceptionType.notSupportedFormat:
        return '지원하지 않는 이미지 형식입니다.';

      case GalExceptionType.unexpected:
        return '이미지를 저장하는 중 오류가 발생했습니다.';
    }
  }
}
