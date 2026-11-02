import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:collection/collection.dart';
import 'package:dayverse_book/main.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/challenge_attempt_model.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/utils/challenge_progress_utils.dart';
import 'package:dayverse_book/utils/challenge_check_utils.dart';
import 'package:dayverse_book/service/challenge_record_service.dart';
import 'package:dayverse_book/widget/challenge/challenge_summary_card.dart';
import 'package:dayverse_book/widget/challenge/challenge_description_card.dart';
import 'package:dayverse_book/widget/challenge/reading_book_section.dart';
import 'package:dayverse_book/widget/challenge/done_book_section.dart';
import 'package:dayverse_book/widget/challenge/stage_calendar.dart';
import 'package:dayverse_book/utils/book_pool_loader.dart';
import 'package:dayverse_book/service/book_api_service.dart'; // fetchBooksByIsbnList
import 'package:dayverse_book/widget/challenge/repeatable_user_selected_book_done_section.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:dayverse_book/widget/card_box.dart';
import 'package:dayverse_book/screen/share_challenge_done_screen.dart';
import 'package:dayverse_book/widget/recurring_challenge_cover.dart';

class ChallengeDoneScreen extends StatefulWidget {
  final Challenge challenge;

  const ChallengeDoneScreen({super.key, required this.challenge});

  @override
  State<ChallengeDoneScreen> createState() => _ChallengeDoneScreenState();
}

class _ChallengeDoneScreenState extends State<ChallengeDoneScreen> {
  bool showDetails = false;
  Map<String, dynamic>? recordData;

  // ✅ 풀 기반 로딩 상태/결과
  bool _isLoadingPoolBooks = false;
  List<BookModel> _poolBooks = [];

  // ✅ 화면에서 사용할 '타겟 도서' (override = 풀/참여도서)
  List<BookModel> get _displayTargetBooks {
    if (_poolBooks.isNotEmpty) return _poolBooks;
    if ((widget.challenge.participatingBooks ?? []).isNotEmpty) {
      return widget.challenge.participatingBooks!;
    }
    return widget.challenge.requiredBooks ?? const [];
  }

  ChallengeAttempt? _latestSuccessfulAttempt(Challenge challenge) {
    for (int i = challenge.attempts.length - 1; i >= 0; i--) {
      final attempt = challenge.attempts[i];
      if (attempt.completed && attempt.isSuccessful) {
        return attempt;
      }
    }
    return null;
  }

  int _successfulAttemptCount(Challenge challenge) {
    return challenge.attempts
        .where((a) => a.completed && a.isSuccessful)
        .length;
  }

  @override
  void initState() {
    super.initState();
    _loadChallengeRecord();

    // ✅ 스테이지 다음단계 안내 기존 로직 그대로 유지
    final challenge = widget.challenge;
    if (challenge.stageDurations != null && challenge.stageDurations!.isNotEmpty) {
      final totalStages = challenge.stageDurations!.length;
      final completedStages = challenge.attempts.where((a) => a.completed).length;
      if (completedStages < totalStages) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showNextStageDialog(challenge);
        });
      }
    }

    // ✅ 풀 로딩
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPoolBooksIfNeeded();
    });
  }

  Future<void> _loadPoolBooksIfNeeded() async {
    final c = widget.challenge; // ✅ 여기로 수정

    final usePool = c.method == ChallengeMethod.specificBooks &&
        c.specificBookMode == SpecificBookMode.systemDefined &&
        (c.requiredBooksPoolId?.isNotEmpty ?? false);

    if (!usePool) return;
    if (_poolBooks.isNotEmpty) return;

    try {
      setState(() => _isLoadingPoolBooks = true);

      // 1) 풀 → BookModel 로드
      var poolBooks = await BookPoolLoader.loadPoolAsBookModels(c.requiredBooksPoolId!);

      // 2) id/isbn 표준화
      poolBooks = poolBooks.map((b) {
        final newId   = b.id.isNotEmpty ? b.id : (b.isbn ?? '');
        final newIsbn = (b.isbn != null && b.isbn!.isNotEmpty) ? b.isbn! : newId;
        return b.copyWith(id: newId, isbn: newIsbn);
      }).toList();

      // 3) (선택) ISBN 메타데이터 보강
      final isbns = poolBooks
          .map((b) => b.isbn)
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();

      if (isbns.isNotEmpty) {
        final fetched = await BookApiService.fetchBooksByIsbnList(isbns);
        final byIsbn = {
          for (final f in fetched)
            if ((f.isbn ?? '').isNotEmpty) f.isbn!: f
        };

        poolBooks = poolBooks.map((b) {
          final f = byIsbn[b.isbn];
          if (f == null) return b;
          return b.copyWith(
            title: (f.title.isNotEmpty) ? f.title : b.title,
            author: (f.author.isNotEmpty) ? f.author : b.author,
            pageCount: (f.pageCount > 0) ? f.pageCount : b.pageCount,
            imageUrl: f.imageUrl ?? b.imageUrl,
            publisher: f.publisher ?? b.publisher,
            itemId: f.itemId ?? b.itemId,
            description: f.description ?? b.description,
          );
        }).toList();
      }

      if (!mounted) return;
      setState(() => _poolBooks = poolBooks);
    } catch (e) {
      debugPrint('⚠️ _loadPoolBooksIfNeeded error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPoolBooks = false);
    }
  }

  Future<void> _loadChallengeRecord() async {
    try {
      final data =
      await ChallengeRecordService.fetchChallengeRecord(widget.challenge.id);

      if (!mounted) return;

      setState(() {
        recordData = data;
      });
    } catch (e) {
      debugPrint('❌ 챌린지 기록 불러오기 실패: $e');

      if (!mounted) return;

      setState(() {
        recordData = {};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;

    final savedBooks =
        context.watch<SavedBooksProvider>().savedBooks;

    final screenWidth =
        MediaQuery.of(context).size.width;

    final screenHeight =
        MediaQuery.of(context).size.height;

    final horizontalPadding =
        screenWidth * 0.05;

    if (recordData == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF013328),
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.amberAccent,
            strokeWidth: 2,
          ),
        ),
      );
    }

    final record = recordData!;

    final enrichedRecord = {
      ...record,
      'savedBooks': savedBooks,
    };

    // 기존 계산 로직 유지
    ChallengeProgressUtils.getCompletedCount(
      challenge,
      enrichedRecord,
      targetBooksOverride:
      _displayTargetBooks,
    );

    ChallengeProgressUtils.getTargetCount(
      challenge,
      enrichedRecord,
      targetBooksOverride:
      _displayTargetBooks,
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity =
            details.primaryVelocity ?? 0;

        if (velocity > 500) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor:
        const Color(0xFF013328),

        appBar: _buildAppBar(
          screenWidth,
        ),

        body: SingleChildScrollView(
          physics:
          const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            screenHeight * 0.015,
            horizontalPadding,
            screenHeight * 0.1,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [

              /// 1. 성취 커버
              _buildAchievementCover(
                challenge,
                screenWidth,
                screenHeight,
              ),

              SizedBox(
                height:
                screenHeight * 0.035,
              ),

              /// 2. 기록
              _buildSectionTitle(
                screenWidth,
                'CHALLENGE RECORD',
              ),

              SizedBox(
                height:
                screenHeight * 0.015,
              ),

              _buildChallengeRecordCard(
                challenge,
                screenWidth,
              ),

              SizedBox(
                height:
                screenHeight * 0.04,
              ),

              /// 4. 달성 결과
              _buildSectionTitle(
                screenWidth,
                'CHALLENGE TO-DO',
              ),

              SizedBox(
                height:
                screenHeight * 0.015,
              ),

              _buildChallengeResultSection(
                challenge,
                record,
                savedBooks,
              ),

              SizedBox(
                height:
                screenHeight * 0.04,
              ),

              /// 5. 기본 챌린지 정보
              _buildSectionTitle(
                screenWidth,
                'ABOUT CHALLENGE',
              ),

              SizedBox(
                height:
                screenHeight * 0.015,
              ),

              SummaryCard(
                challenge: challenge,
              ),

              if (!challenge.isCustom) ...[
                SizedBox(
                  height:
                  screenHeight * 0.015,
                ),

                _buildDetailSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      double screenWidth,
      ) {
    return AppBar(
      backgroundColor:
      Colors.transparent,
      elevation: 0,
      centerTitle: true,

      leading: IconButton(
        onPressed: _handleBack,
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: Colors.white,
        ),
      ),

      title: Text(
        '챌린지 완료',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'kopub',
          fontSize:
          screenWidth * 0.045,
          fontWeight:
          FontWeight.bold,
        ),
      ),

      actions: [
        PopupMenuButton<String>(
          tooltip: '챌린지 메뉴',
          color:
          const Color(0xFF1B2C2E),
          elevation: 10,
          offset:
          const Offset(0, 8),
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(14),
            side: BorderSide(
              color: Colors.white
                  .withOpacity(0.08),
            ),
          ),

          icon: Icon(
            Icons.more_vert_rounded,
            color: Colors.white70,
            size:
            screenWidth * 0.055,
          ),

          onSelected: (value) {
            if (value == 'share') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShareChallengeDoneScreen(
                    challenge: widget.challenge,
                  ),
                ),
              );
            } else if (value == 'reset') {
              _showResetDialog(
                context,
                widget.challenge,
              );
            }
          },

          itemBuilder: (_) => [
            const PopupMenuItem<String>(
              value: 'share',
              child: Row(
                children: [
                  Icon(
                    Icons.ios_share_rounded,
                    color: Colors.white70,
                    size: 19,
                  ),

                  SizedBox(width: 12),

                  Text(
                    '공유하기',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'kopub',
                    ),
                  ),
                ],
              ),
            ),

            const PopupMenuItem<String>(
              value: 'reset',
              child: Row(
                children: [
                  Icon(
                    Icons.restart_alt_rounded,
                    color: Colors.redAccent,
                    size: 19,
                  ),

                  SizedBox(width: 12),

                  Text(
                    '챌린지 초기화',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontFamily: 'kopub',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        SizedBox(
          width:
          screenWidth * 0.01,
        ),
      ],
    );
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context)
        .pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
        const MainScreen(
          initialTabIndex: 2,
        ),
      ),
    );
  }

  Widget _buildAchievementCover(
      Challenge challenge,
      double screenWidth,
      double screenHeight,
      ) {
    final successfulCount =
    _successfulAttemptCount(challenge);

    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: AspectRatio(
        aspectRatio: 0.9,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildChallengeImage(
                  challenge,
                ),
              ),
            ),

            // 전체 어두운 오버레이
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black.withOpacity(0.38),
                ),
              ),
            ),

            // 위아래 그라데이션
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.28),
                      Colors.black.withOpacity(0.15),
                      Colors.black.withOpacity(0.45),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),

            // 메인 컨텐츠
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.06,
                  vertical: screenWidth * 0.06,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: screenWidth * 0.18,
                      height: screenWidth * 0.18,
                      decoration: BoxDecoration(
                        color: Colors.amberAccent.withOpacity(0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.amberAccent.withOpacity(0.45),
                        ),
                      ),
                      child: Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.amberAccent,
                        size: screenWidth * 0.09,
                      ),
                    ),

                    SizedBox(height: screenWidth * 0.03),

                    Text(
                      'COMPLETED',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontFamily: 'kopub',
                        fontSize: screenWidth * 0.025,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),

                    SizedBox(height: screenWidth * 0.03),

                    Text(
                      challenge.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'kopub',
                        fontSize: screenWidth * 0.052,
                        fontWeight: FontWeight.bold,
                        height: 1.35,
                      ),
                    ),

                    if (successfulCount > 1) ...[
                      SizedBox(height: screenWidth * 0.03),

                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.028,
                          vertical: screenWidth * 0.012,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.amberAccent.withOpacity(0.35),
                          ),
                        ),
                        child: Text(
                          '$successfulCount회 달성',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontFamily: 'kopub',
                            fontSize: screenWidth * 0.028,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],

                    SizedBox(height: screenWidth * 0.03),

                    Text(
                      _getCompletionMessage(successfulCount),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontFamily: 'kopub',
                        fontSize: screenWidth * 0.03,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 완료 체크 뱃지
            Positioned(
              right: screenWidth * 0.035,
              bottom: screenWidth * 0.035,
              child: Container(
                width: screenWidth * 0.11,
                height: screenWidth * 0.11,
                decoration: BoxDecoration(
                  color: const Color(0xFF013328).withOpacity(0.92),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.amberAccent,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: Colors.amberAccent,
                  size: screenWidth * 0.065,
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

  Widget _buildChallengeImage(
      Challenge challenge,
      ) {
    if (RecurringChallengeCover.supports(challenge)) {
      return RecurringChallengeCover(
        challenge: challenge,
        borderRadius: BorderRadius.zero,
      );
    }

    final url = challenge.imageUrl;

    if (url.isEmpty) {
      return _buildImageFallback();
    }

    if (url.startsWith('http')) {
      return Image.network(
        url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) =>
            _buildImageFallback(),
      );
    }

    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) =>
            _buildImageFallback(),
      );
    }

    return Image.file(
      File(url),
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
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
      child: const Center(
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
                attempt?.completed == true &&
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
        margin: EdgeInsets.zero,
        padding: EdgeInsets.symmetric(
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
                value: completedAt != null
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
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(
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
              value: startedAt != null
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
              value: completedAt != null
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
              value: duration != null
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
      children: [
        Text(
          value,
          textAlign:
          TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontFamily:
            'kopub',
            fontSize:
            screenWidth * 0.035,
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
          style: TextStyle(
            color:
            Colors.white38,
            fontFamily:
            'kopub',
            fontSize:
            screenWidth * 0.026,
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

  Widget _buildSectionTitle(
      double screenWidth,
      String title,
      ) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white
            .withOpacity(0.72),
        fontFamily: 'kopub',
        fontSize:
        screenWidth * 0.032,
        fontWeight:
        FontWeight.w600,
        letterSpacing: 1.5,
      ),
    );
  }

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
    final startDate = DateTime(
      startedAt.year,
      startedAt.month,
      startedAt.day,
    );

    final completionDate = DateTime(
      completedAt.year,
      completedAt.month,
      completedAt.day,
    );

    return completionDate.difference(startDate).inDays + 1;
  }

  Widget _buildChallengeResultSection(
      Challenge challenge,
      Map<String, dynamic> record,
      List<BookModel> savedBooks,
      ) {
    final checkAction = getChallengeCheckActionType(challenge);
    final attempt = _isRepeatableUserSelectedPageChallenge(challenge)
        ? _latestSuccessfulAttempt(challenge)
        : (challenge.attempts.isNotEmpty ? challenge.attempts.last : null);

    final completedBookIds = attempt?.completedBookIds ?? [];

    // 0. 반복형 + 사용자지정도서 + 페이지연동 완료 전용
    if (_isRepeatableUserSelectedPageChallenge(challenge)) {
      final successAttempt = _latestSuccessfulAttempt(challenge);

      if (successAttempt == null) {
        return const SizedBox(); // 또는 fallback UI
      }

      return RepeatableUserSelectedBookDoneSection(
        challenge: challenge,
        attempt: successAttempt,
        savedBooks: savedBooks,
      );
    }

    // 1. 사용자지정/운영자지정 도서 기반 챌린지
    if (challenge.method == ChallengeMethod.specificBooks) {
      return ReadingBookSection(
        challenge: challenge,
        savedBooks: savedBooks,
        completedBookIds: completedBookIds,
        isDoneMode: true,
        booksOverride: _displayTargetBooks,
      );
    }

    // 2. 지정권수 도전
    if (challenge.method == ChallengeMethod.quantityBased) {
      return DoneBookSection(
        challenge: challenge,
        completedBookIds: completedBookIds,
        isDoneMode: true,
        booksOverride: _displayTargetBooks,
      );
    }

    // 3. 루틴형
    if (challenge.category == ChallengeCategory.routine &&
        checkAction != ChallengeCheckActionType.libraryAuto) {
      return StageCalendar(
        challenge: challenge,
        recordDataOrBooks: record,
        isDoneMode: true,
      );
    }

    return const SizedBox();
  }

  Widget _buildDetailSection() {
    final screenWidth =
        MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        CardBox(
          margin: EdgeInsets.zero,
          padding: EdgeInsets.symmetric(
            horizontal:
            screenWidth * 0.035,
            vertical:
            screenWidth * 0.012,
          ),
          onTap: () {
            setState(() {
              showDetails =
              !showDetails;
            });
          },
          child: Row(
            children: [
              Icon(
                Icons
                    .info_outline_rounded,
                color:
                Colors.white54,
                size:
                screenWidth * 0.045,
              ),

              SizedBox(
                width:
                screenWidth * 0.02,
              ),

              Expanded(
                child: Text(
                  showDetails
                      ? '챌린지 상세내용 접기'
                      : '챌린지 상세보기',
                  style:
                  TextStyle(
                    color:
                    Colors.white70,
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth *
                        0.031,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),

              Icon(
                showDetails
                    ? Icons
                    .expand_less_rounded
                    : Icons
                    .expand_more_rounded,
                color:
                Colors.white38,
              ),
            ],
          ),
        ),

        if (showDetails) ...[
          SizedBox(
            height:
            screenWidth * 0.025,
          ),

          if (widget.challenge
              .longDescription !=
              null)
            DescriptionCard(
              title:
              '챌린지 소개',
              content: widget
                  .challenge
                  .longDescription!,
            ),

          if (widget.challenge
              .goalDescription !=
              null)
            DescriptionCard(
              title:
              '챌린지 목표',
              content: widget
                  .challenge
                  .goalDescription!,
            ),

          if (widget.challenge
              .recommendedFor !=
              null)
            DescriptionCard(
              title:
              '이런 분께 추천',
              content: widget
                  .challenge
                  .recommendedFor!,
            ),

          if (widget.challenge
              .guideText !=
              null)
            DescriptionCard(
              title:
              '진행 방법',
              content: widget
                  .challenge
                  .guideText!,
            ),
        ],
      ],
    );
  }

  void _showNextStageDialog(Challenge challenge) {
    final totalStages = challenge.stageDurations?.length ?? 0;
    final completedStages = challenge.attempts
        .where((a) => a.completed && a.isSuccessful)
        .length;

    if (completedStages >= totalStages) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final titleFontSize = screenWidth * 0.045; // ≈18
        final contentFontSize = screenWidth * 0.035; // ≈15

        return AlertDialog(
          backgroundColor: const Color(0xFF1B2C2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "🚀 다음 단계가 준비되어 있어요!",
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontWeight: FontWeight.bold,
              fontSize: titleFontSize,
            ),
          ),
          content: Text(
            "이 챌린지는 단계적으로 성장해요.\n\n"
                "지금은 ${completedStages}단계 / 총 ${totalStages}단계까지 도전했어요.\n"
                "남은 단계에도 도전해보세요!",
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'kopub',
              fontSize: contentFontSize,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("확인", style: TextStyle(color: Colors.amberAccent, fontSize: contentFontSize)),
            ),
          ],
        );
      },
    );
  }

  void _showResetDialog(BuildContext context, Challenge challenge) {
    showDialog(
      context: context,
      builder: (ctx) {
        final screenWidth = MediaQuery.of(ctx).size.width;
        final titleFontSize = screenWidth * 0.045; // ≈18
        final contentFontSize = screenWidth * 0.035; // ≈15

        return AlertDialog(
          backgroundColor: const Color(0xFF1B2C2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "챌린지를 초기화할까요?",
            style: TextStyle(
              fontFamily: 'kopub',
              fontWeight: FontWeight.bold,
              fontSize: titleFontSize,
              color: Colors.white,
            ),
          ),
          content: Text(
            "이 챌린지의 모든 기록이 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.",
            style: TextStyle(
              fontFamily: 'kopub',
              fontSize: contentFontSize,
              height: 1.4,
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              child: Text("초기화", style: TextStyle(color: Colors.red, fontSize: contentFontSize)),
              onPressed: () async {
                Navigator.pop(ctx);
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await context.read<ChallengeProvider>().resetChallengeForUser(challenge.id, user.uid);
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainScreen(initialTabIndex: 2)),
                        (route) => false,
                  );
                }
              },
            ),
            TextButton(
              child: Text("취소", style: TextStyle(color: Colors.amberAccent, fontSize: contentFontSize)),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        );
      },
    );
  }

  bool _isRepeatableUserSelectedPageChallenge(Challenge c) {
    return c.stageType == ChallengeStageType.single &&
        c.method == ChallengeMethod.specificBooks &&
        c.specificBookMode == SpecificBookMode.userDefined &&
        c.isRepeatable == true;
  }

}

//📎
