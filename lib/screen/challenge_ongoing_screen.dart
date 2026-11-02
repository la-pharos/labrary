import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dayverse_book/main.dart';
import 'package:flutter/services.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/widget/challenge/challenge_progress_card.dart';
import 'package:dayverse_book/widget/challenge/stage_info_card.dart';
import 'package:dayverse_book/widget/challenge/stage_calendar.dart';
import 'package:dayverse_book/widget/challenge/reading_book_section.dart';
import 'package:dayverse_book/widget/challenge/done_book_section.dart';
import 'package:dayverse_book/widget/challenge/challenge_summary_card.dart';
import 'package:dayverse_book/widget/challenge/challenge_action_button.dart';
import 'package:dayverse_book/widget/challenge/challenge_completion_dialog.dart';
import 'package:dayverse_book/utils/challenge_check_utils.dart';
import 'package:dayverse_book/utils/challenge_progress_utils.dart';
import 'package:dayverse_book/utils/book_pool_loader.dart';
import 'package:dayverse_book/service/book_api_service.dart'; // ✅ BookApiService
import '../service/challenge_social_service.dart';
import '../widget/card_box.dart';
import 'challenge_done_screen.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:dayverse_book/widget/challenge/challenge_together_card.dart';
import 'package:dayverse_book/widget/challenge/challenge_friend_invite_sheet.dart';
import 'package:dayverse_book/service/friend_service.dart';
import 'dart:async';
import 'package:dayverse_book/widget/recurring_challenge_cover.dart';
import 'package:dayverse_book/service/challenge_share_service.dart';

class ChallengeOngoingScreen extends StatefulWidget {
  final Challenge challenge;

  const ChallengeOngoingScreen({super.key, required this.challenge});

  @override
  State<ChallengeOngoingScreen> createState() => _ChallengeOngoingScreenState();
}

class _ChallengeOngoingScreenState
    extends State<ChallengeOngoingScreen> {
  late Challenge _currentChallenge;
  Map<String, dynamic> _recordWithBooks = {};
  bool _hasCheckedCompletion = false;
  Timer? _togetherRefreshTimer;

  // ✅ 추가: 풀 기반 상세도서 / 로딩 표시
  bool _isLoadingPoolBooks = false;
  List<BookModel> _poolBooks = [];

  List<ChallengeTogetherMember>
  _togetherMembers = [];

  bool _isLoadingTogetherMembers = false;

  String? _challengeGroupId;

  // ✅ 공통: 화면에서 보여줄 타겟 도서 결정
  List<BookModel> get _displayTargetBooks {
    if (_poolBooks.isNotEmpty) return _poolBooks;
    if ((_currentChallenge.participatingBooks ?? []).isNotEmpty) {
      return _currentChallenge.participatingBooks!;
    }
    return _currentChallenge.requiredBooks ?? const [];
  }

  Future<void> _loadPoolBooksIfNeeded() async {
    final c = _currentChallenge;

    final isSystemDefinedPool =
        c.method == ChallengeMethod.specificBooks &&
            c.specificBookMode == SpecificBookMode.systemDefined &&
            (c.requiredBooksPoolId?.isNotEmpty ?? false);

    if (!isSystemDefinedPool) return;
    if (_poolBooks.isNotEmpty) return;

    try {
      setState(() => _isLoadingPoolBooks = true);

      // 1) 풀 엔트리 → ISBN 리스트 추출
      final entries = await BookPoolLoader.loadPoolEntries(c.requiredBooksPoolId!);
      final isbns = entries
          .map((e) => (e.isbn ?? e.isbn13 ?? '').trim())
          .where((s) => s.isNotEmpty)
          .toList();

      // 2) ISBN 있으면 상세 API, 없거나 실패하면 최소 표시용(BookPoolLoader→BookModel)
      List<BookModel> hydrated = [];
      if (isbns.isNotEmpty) {
        final fetched = await BookApiService.fetchBooksByIsbnList(isbns);

        // id/isbn 표준화(빈 값 보정)
        hydrated = fetched.map((b) {
          final newId   = (b.id.isNotEmpty) ? b.id : (b.isbn ?? '');
          final newIsbn = (b.isbn?.isNotEmpty == true) ? b.isbn! : newId;
          return b.copyWith(id: newId, isbn: newIsbn);
        }).toList();
      }
      if (hydrated.isEmpty) {
        hydrated = await BookPoolLoader.loadPoolAsBookModels(c.requiredBooksPoolId!);
      }

      if (!mounted) return;

      setState(() {
        _poolBooks = hydrated;

        // ⚠️ 핵심: 한 번만 하이드레이션해서 기존 위젯/유틸이 requiredBooks를 그대로 쓰도록
        _currentChallenge = _currentChallenge.copyWith(
          requiredBooks: (_currentChallenge.requiredBooks?.isNotEmpty ?? false)
              ? _currentChallenge.requiredBooks
              : hydrated,
        );
      });
    } catch (e) {
    } finally {
      if (mounted) setState(() => _isLoadingPoolBooks = false);
    }
  }

  @override
  void initState() {
    super.initState();

    _currentChallenge =
        widget.challenge;

    WidgetsBinding.instance
        .addPostFrameCallback((_) async {
      // =====================================================
      // 1. 최신 챌린지 상태 갱신
      //
      // 여기서 10 Minutes Habit의
      // 지난 날짜 미달 여부도 검사될 수 있음.
      // =====================================================

      await _refreshChallengeState();

      if (!mounted) {
        return;
      }

      // =====================================================
      // 2. refresh 중 자동 스테이지 실패가 발생했다면
      // 성공 판정으로 넘어가지 말고 실패 안내부터 처리
      // =====================================================

      final challengeProvider =
      context.read<
          ChallengeProvider
      >();

      final pendingFailure =
      challengeProvider
          .consumePendingStageFailure();

      if (pendingFailure != null) {
        await _showStageFailedDialog(
          pendingFailure,
        );

        // 실패한 Attempt가 제거된 상태이므로
        // 아래 완료 검사 절대 실행하지 않음
        return;
      }

      // =====================================================
      // 3. 도서 데이터 준비
      // =====================================================

      await _loadPoolBooksIfNeeded();

      if (!mounted) {
        return;
      }

      // =====================================================
      // 4. 함께 도전 정보
      // =====================================================

      if (_currentChallenge.stageType ==
          ChallengeStageType.single) {
        await _loadTogetherMembers();
      }

      if (!mounted) {
        return;
      }

      // =====================================================
      // 5. 정상적으로 살아있는 Attempt만 완료 여부 검사
      // =====================================================

      if (!_hasCheckedCompletion) {
        _hasCheckedCompletion =
        true;

        await _checkIfCompletedAndNavigate();
      }
    });
  }

  Future<void> _refreshChallengeState() async {
    final provider = Provider.of<ChallengeProvider>(context, listen: false);
    final savedBooks = Provider.of<SavedBooksProvider>(context, listen: false).savedBooks;
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    await provider.refreshChallengeStatus(
      _currentChallenge.id,
      savedBooks: savedBooks,
      userId: userId,
    );
    if (!mounted) return;

    final refreshed = provider.findChallengeById(_currentChallenge.id);
    if (refreshed != null) {
      final checkType = getChallengeCheckActionType(refreshed);
      final record = (checkType == ChallengeCheckActionType.libraryAuto)
          ? savedBooks
          : (refreshed.attempts.isNotEmpty ? refreshed.attempts.last.recordData ?? {} : {});

      setState(() {
        _currentChallenge = refreshed;
        _recordWithBooks = <String, dynamic>{
          ...(record is Map ? Map<String, dynamic>.from(record) : {}),
          'savedBooks': savedBooks,
        };
      });
    }
  }

  Future<void> _loadTogetherMembers() async {
    // 스테이지 챌린지는 함께 도전 미지원
    if (_currentChallenge.stageType ==
        ChallengeStageType.staged) {
      return;
    }

    final attempt =
        _currentChallenge.currentAttempt;

    if (attempt == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingTogetherMembers =
        true;
      });
    }

    try {
      // =====================================================
      // 1. 현재 Attempt가 속한 그룹 찾기
      // =====================================================


      String? groupId =
          _challengeGroupId;

// 아직 groupId를 모를 때만 서버에서 찾기
      if (groupId == null ||
          groupId.isEmpty) {
        groupId =
        await ChallengeSocialService.instance
            .getChallengeGroupForAttempt(
          challengeId:
          _currentChallenge.id,
          attemptId:
          attempt.attemptId,
        );
      }

      if (!mounted) return;

      _challengeGroupId =
          groupId;

      // 아직 함께 도전 그룹 자체가 없음
      if (groupId == null) {
        setState(() {
          _togetherMembers = [];
        });

        return;
      }

      // =====================================================
      // 2. 그룹 친구 데이터 조회
      // =====================================================

      final rawMembers =
      await ChallengeSocialService.instance
          .getChallengeGroupMembers(
        groupId:
        groupId,

        targetBookIds:
        _currentChallenge.method ==
            ChallengeMethod.specificBooks
            ? _displayTargetBooks
            .map((book) => book.id)
            .where((id) => id.isNotEmpty)
            .toList()
            : const [],
      );


      final members =
      <ChallengeTogetherMember>[];

      for (final rawMember
      in rawMembers) {
        try {
          final uid =
              rawMember['uid']
              as String? ??
                  '';

          final nickname =
              rawMember['nickname']
              as String? ??
                  '';

          final profileImageUrl =
              rawMember[
              'profileImageUrl']
              as String? ??
                  '';

          final rawChallenge =
          rawMember['challenge'];

          if (uid.isEmpty ||
              rawChallenge is! Map) {
            continue;
          }

          // =================================================
          // 친구의 "이번 그룹 Attempt만 가진 Challenge"
          // =================================================

          final friendChallenge =
          Challenge.fromMap(
            Map<String, dynamic>.from(
              rawChallenge,
            ),
          );

          // =================================================
          // 친구 savedBooks
          // =================================================

          final rawSavedBooks =
          rawMember['savedBooks'];

          final friendSavedBooks =
          rawSavedBooks is List
              ? rawSavedBooks
              .whereType<Map>()
              .map(
                (book) =>
                BookModel.fromMap(
                  Map<String,
                      dynamic>.from(
                    book,
                  ),
                ),
          )
              .toList()
              : <BookModel>[];

          // =================================================
          // ProgressUtils에 넘길 record
          // =================================================

          final friendAttempt =
              friendChallenge
                  .currentAttempt;

          final friendRecord =
          <String, dynamic>{
            ...(friendAttempt
                ?.recordData ??
                {}),
            'savedBooks':
            friendSavedBooks,

            // countBased에서
            // getTargetCount가 읽는 값
            'selectedDuration':
            friendAttempt
                ?.selectedDuration,
          };

          // =================================================
          // 타겟 도서
          //
          // 시스템 지정:
          // 현재 사용자 화면에서 이미 hydrate한 동일 도서 사용
          //
          // 사용자 지정:
          // 친구의 해당 Attempt에 저장된 책 사용
          // =================================================

          List<BookModel>?
          targetBooksOverride;

          if (friendChallenge.method ==
              ChallengeMethod
                  .specificBooks) {
            if (friendChallenge
                .specificBookMode ==
                SpecificBookMode
                    .userDefined) {
              targetBooksOverride =
                  friendAttempt
                      ?.participatedBooks ??
                      friendChallenge
                          .participatingBooks ??
                      const <BookModel>[];
            } else {
              targetBooksOverride =
                  _displayTargetBooks;
            }
          }

          double progress =
          ChallengeProgressUtils
              .getProgress(
            friendChallenge,
            friendRecord,
            targetBooksOverride:
            targetBooksOverride,
          );

// =====================================================
// 지정도서 + 페이지 자동 연동
//
// ProgressCard와 동일하게
// "완독 권수"가 아니라
// "읽은 페이지 / 전체 페이지"로 진행률 계산
// =====================================================

          final checkType =
          getChallengeCheckActionType(
            friendChallenge,
          );

          if (
          friendChallenge.method ==
              ChallengeMethod.specificBooks &&
              checkType ==
                  ChallengeCheckActionType.pageAuto
          ) {
            final targetBooks =
                targetBooksOverride ??
                    const <BookModel>[];

            final savedMap =
            <String, BookModel>{};

            for (final book
            in friendSavedBooks) {
              final key =
              _togetherBookKey(
                book,
              );

              if (key != null) {
                savedMap[key] =
                    book;
              }
            }

            int totalPages =
            0;

            int readPages =
            0;

            for (final target
            in targetBooks) {
              final key =
              _togetherBookKey(
                target,
              );

              if (key == null) {
                continue;
              }

              final savedBook =
              savedMap[key];

              final total =
              target.pageCount > 0
                  ? target.pageCount
                  : savedBook?.pageCount ?? 0;

              if (total <= 0) {
                continue;
              }

              final read =
                  savedBook?.pageRead ?? 0;

              totalPages +=
                  total;

              readPages +=
                  read.clamp(
                    0,
                    total,
                  );
            }

            if (totalPages > 0) {
              progress =
                  (readPages / totalPages)
                      .clamp(
                    0.0,
                    1.0,
                  );

            }
          }



          members.add(
            ChallengeTogetherMember(
              uid:
              uid,
              nickname:
              nickname.isNotEmpty
                  ? nickname
                  : 'Labrary 사용자',
              profileImageUrl:
              profileImageUrl,
              progress:
              progress,
            ),
          );
        } catch (e) {

        }
      }

      if (!mounted) return;


      setState(() {
        _togetherMembers =
            members;
      });
    } on FirebaseFunctionsException catch (e) {

    } catch (e) {

    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTogetherMembers =
          false;
        });
      }
    }
  }

  String? _togetherBookKey(
      BookModel book,
      ) {
    if (book.id.isNotEmpty) {
      return book.id;
    }

    final isbn =
        book.isbn;

    if (isbn != null &&
        isbn.isNotEmpty) {
      return isbn;
    }

    return null;
  }

  Future<void> _inviteFriends() async {
    if (_currentChallenge.stageType ==
        ChallengeStageType.staged) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            '스테이지 챌린지는 친구와 함께 도전할 수 없습니다.',
          ),
        ),
      );

      return;
    }

    final attempt =
        _currentChallenge.currentAttempt;

    if (attempt == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '현재 챌린지 도전 정보를 찾을 수 없습니다.',
          ),
        ),
      );

      return;
    }

    final selectedFriends =
    await showModalBottomSheet<List<FriendItem>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
      const ChallengeFriendInviteSheet(),
    );

    if (selectedFriends == null ||
        selectedFriends.isEmpty ||
        !mounted) {
      return;
    }

    try {
      final groupId =
      await ChallengeSocialService.instance
          .createChallengeGroup(
        challengeId:
        _currentChallenge.id,

        challengeTitle:
        _currentChallenge.title,

        ownerAttemptId:
        attempt.attemptId,

        startDate:
        attempt.startDate,

        endDate:
        attempt.endDate,

        selectedDuration:
        attempt.selectedDuration,

        stageIndex:
        attempt.stageIndex,

        participatingBooks:
        (attempt.participatedBooks ??
            const <BookModel>[])
            .map(
              (book) =>
              book.toMap(),
        )
            .toList(),

        invitedFriendUids:
        selectedFriends
            .map(
              (friend) =>
          friend.uid,
        )
            .toList(),
      );


      _challengeGroupId =
          groupId;

      // 현재 그룹 상태 갱신
      await _loadTogetherMembers();

      if (!mounted) return;

      await _showChallengeInviteSuccessDialog(
        invitedCount:
        selectedFriends.length,
      );

    } on FirebaseFunctionsException catch (e) {


      if (!mounted) return;

      String message =
          '챌린지 초대를 보내지 못했습니다.';

      if (e.code ==
          'already-exists') {
        message =
        '이미 참여 중이거나 초대된 친구입니다.';
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } catch (e) {


      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            '챌린지 초대를 보내지 못했습니다.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width;

    final screenHeight =
        MediaQuery.of(context).size.height;

    final challengeProvider =
    context.watch<ChallengeProvider>();

    final savedBooks =
        context.watch<SavedBooksProvider>().savedBooks;

    final latestChallenge =
    challengeProvider.findChallengeById(
      _currentChallenge.id,
    );

    if (latestChallenge != null &&
        latestChallenge != _currentChallenge) {
      _currentChallenge =
          latestChallenge;

      final latestAttempt =
      _currentChallenge.attempts.isNotEmpty
          ? _currentChallenge.attempts.last
          : null;

      _recordWithBooks = {
        ...(latestAttempt?.recordData ?? {}),
        'savedBooks': savedBooks,
      };
    }

    final checkType =
    getChallengeCheckActionType(
      _currentChallenge,
    );

    final shouldShowReadingBookSection =
        _currentChallenge.method ==
            ChallengeMethod.specificBooks &&
            checkType ==
                ChallengeCheckActionType.pageAuto;

    final shouldShowReadDoneSection =
        _currentChallenge.method ==
            ChallengeMethod.quantityBased;

    final shouldShowRoutineCalendar =
        _currentChallenge.category ==
            ChallengeCategory.routine &&
            checkType !=
                ChallengeCheckActionType.libraryAuto;

    final hasProgressRecordSection =
        shouldShowRoutineCalendar ||
            shouldShowReadingBookSection ||
            shouldShowReadDoneSection;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,

      onHorizontalDragEnd: (details) {
        final velocity =
            details.primaryVelocity ?? 0;

        if (velocity > 500) {
          _goToChallengeHome();
        }
      },

      child: Scaffold(
        backgroundColor:
        const Color(0xFF013328),

        appBar: _buildAppBar(
          screenWidth,
        ),

        body: Stack(
          children: [
            SingleChildScrollView(
              physics:
              const BouncingScrollPhysics(),

              padding: EdgeInsets.fromLTRB(
                screenWidth * 0.05,
                screenHeight * 0.015,
                screenWidth * 0.05,

                // ActionButton 공간
                screenHeight * 0.16,
              ),

              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  // =================================================
                  // 1. 대표 이미지
                  // =================================================

                  _buildChallengeImage(
                    _currentChallenge,
                    screenWidth,
                  ),

                  SizedBox(
                    height:
                    screenHeight * 0.025,
                  ),

                  // =================================================
                  // 2. 제목
                  // =================================================

                  _buildChallengeHeading(
                    _currentChallenge,
                    screenWidth,
                  ),

                  SizedBox(
                    height:
                    screenHeight * 0.015,
                  ),

                  const Divider(color: Colors.white24),

                  SizedBox(
                    height:
                    screenHeight * 0.015,
                  ),


                  // =================================================
                  // 3. 진행 현황
                  // =================================================

                  _buildSectionTitle(
                    screenWidth,
                    'CHALLENGE PROGRESS',
                  ),

                  SizedBox(
                    height:
                    screenHeight * 0.015,
                  ),

                  if (_currentChallenge.stageType ==
                      ChallengeStageType.staged) ...[
                    StageInfoCard(
                      challenge:
                      _currentChallenge,
                    ),

                    SizedBox(
                      height:
                      screenHeight * 0.015,
                    ),
                  ],

                  ProgressCard(
                    challenge:
                    _currentChallenge,
                    savedBooks:
                    savedBooks,
                    record:
                    _recordWithBooks,
                    targetBooksOverride:
                    _displayTargetBooks,
                  ),

                  // =================================================
                  // 4. 챌린지별 진행 현황
                  // =================================================

                  SizedBox(
                    height:
                    screenHeight * 0.02,
                  ),

                  if (_currentChallenge.stageType ==
                      ChallengeStageType.single) ...[
                    ChallengeTogetherCard(
                      members:
                      _togetherMembers,
                      isLoading:
                      _isLoadingTogetherMembers,
                      onInviteTap:
                      _inviteFriends,
                    ),
                  ],

                  if (hasProgressRecordSection) ...[
                    SizedBox(
                      height:
                      screenHeight * 0.04,
                    ),

                    _buildSectionTitle(
                      screenWidth,
                      'CHALLENGE TO-DO',
                    ),

                    SizedBox(
                      height:
                      screenHeight * 0.015,
                    ),

                    if (shouldShowRoutineCalendar)
                      StageCalendar(
                        challenge:
                        _currentChallenge,
                        recordDataOrBooks:
                        _recordWithBooks,
                      ),

                    if (shouldShowReadingBookSection)
                      Consumer<SavedBooksProvider>(
                        builder: (
                            context,
                            savedBooksProvider,
                            _,
                            ) {
                          return ReadingBookSection(
                            challenge:
                            _currentChallenge,
                            savedBooks:
                            savedBooksProvider
                                .savedBooks,
                            booksOverride:
                            _displayTargetBooks,
                            isLoading:
                            _isLoadingPoolBooks,
                          );
                        },
                      ),

                    if (shouldShowReadDoneSection)
                      DoneBookSection(
                        challenge:
                        _currentChallenge,
                        booksOverride:
                        _displayTargetBooks,
                      ),
                  ],

                  // =================================================
                  // 5. 챌린지 정보
                  // =================================================

                  SizedBox(
                    height:
                    screenHeight * 0.04,
                  ),

                  _buildSectionTitle(
                    screenWidth,
                    'CHALLENGE SUMMARY',
                  ),

                  SizedBox(
                    height:
                    screenHeight * 0.015,
                  ),

                  SummaryCard(
                    challenge:
                    _currentChallenge,
                  ),
                ],
              ),
            ),

            // =====================================================
            // 하단 액션
            // =====================================================

            ActionButton(
              challenge:
              _currentChallenge,
              record:
              _recordWithBooks,
              targetBooksOverride:
              _displayTargetBooks,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChallengeInviteSuccessDialog({
    required int invitedCount,
  }) async {
    if (!mounted) return;

    final screenWidth =
        MediaQuery.of(context).size.width;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor:
          Colors.transparent,
          insetPadding:
          EdgeInsets.symmetric(
            horizontal:
            screenWidth * 0.09,
          ),
          child: Container(
            width:
            double.infinity,
            padding:
            EdgeInsets.symmetric(
              horizontal:
              screenWidth * 0.055,
              vertical:
              screenWidth * 0.055,
            ),
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
              mainAxisSize:
              MainAxisSize.min,
              children: [
                Container(
                  width:
                  screenWidth *
                      0.17,
                  height:
                  screenWidth *
                      0.17,
                  decoration:
                  BoxDecoration(
                    color:
                    Colors
                        .amberAccent
                        .withOpacity(
                      0.11,
                    ),
                    shape:
                    BoxShape.circle,
                    border:
                    Border.all(
                      color:
                      Colors
                          .amberAccent
                          .withOpacity(
                        0.28,
                      ),
                    ),
                  ),
                  child:
                  Icon(
                    Icons
                        .group_add_rounded,
                    color:
                    Colors
                        .amberAccent,
                    size:
                    screenWidth *
                        0.075,
                  ),
                ),

                SizedBox(
                  height:
                  screenWidth *
                      0.025,
                ),

                Text(
                  'INVITATION SENT',
                  style:
                  TextStyle(
                    color:
                    Colors
                        .amberAccent,
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth *
                        0.024,
                    fontWeight:
                    FontWeight
                        .bold,
                    letterSpacing:
                    1.8,
                  ),
                ),

                SizedBox(
                  height:
                  screenWidth *
                      0.023,
                ),

                Text(
                  '초대 완료!',
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
                      0.018,
                ),

                Text(
                  '$invitedCount명에게 챌린지 초대를 보냈어요.\n'
                      '친구가 참여하면 진행률을 함께 확인할 수 있어요.',
                  textAlign:
                  TextAlign.center,
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
                        0.029,
                    height:
                    1.55,
                  ),
                ),

                SizedBox(
                  height:
                  screenWidth *
                      0.04,
                ),

                SizedBox(
                  width:
                  double.infinity,
                  child:
                  ElevatedButton(
                    onPressed:
                        () {
                      Navigator.of(
                        dialogContext,
                      ).pop();
                    },
                    style:
                    ElevatedButton
                        .styleFrom(
                      backgroundColor:
                      Colors
                          .amberAccent,
                      foregroundColor:
                      const Color(
                        0xFF013328,
                      ),
                      elevation:
                      0,
                      padding:
                      EdgeInsets
                          .symmetric(
                        vertical:
                        screenWidth *
                            0.033,
                      ),
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius
                            .circular(
                          12,
                        ),
                      ),
                    ),
                    child:
                    Text(
                      '확인',
                      style:
                      TextStyle(
                        fontFamily:
                        'kopub',
                        fontSize:
                        screenWidth *
                            0.031,
                        fontWeight:
                        FontWeight
                            .bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            _goToChallengeHome();
          }
        },
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: Colors.white,
        ),
      ),

      title: Text(
        '진행 중인 챌린지',
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

          icon: Icon(
            Icons.more_vert_rounded,
            color: Colors.white70,
            size:
            screenWidth * 0.055,
          ),

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

          onSelected: (value) {
            if (value == 'share') {
              _shareChallenge();
            } else if (value == 'give_up') {
              _showGiveUpDialog();
            }
          },

          itemBuilder: (_) => [
            const PopupMenuItem<String>(
              value: 'share',
              child: Row(
                children: [
                  Icon(
                    Icons.ios_share_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                  SizedBox(width: 12),
                  Text(
                    '챌린지 공유하기',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'kopub',
                    ),
                  ),
                ],
              ),
            ),

            const PopupMenuItem<String>(
              value: 'give_up',
              child: Row(
                children: [
                  Icon(
                    Icons.flag_outlined,
                    color: Colors.redAccent,
                    size: 19,
                  ),
                  SizedBox(width: 12),
                  Text(
                    '챌린지 포기하기',
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

  void _goToChallengeHome() {
    Navigator.of(context)
        .pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
        const MainScreen(
          initialTabIndex: 2,
        ),
      ),
          (route) => false,
    );
  }

  Future<void> _shareChallenge() async {
    try {
      await ChallengeShareService.shareChallenge(
        context: context,
        challengeId: _currentChallenge.id,
        challengeTitle: _currentChallenge.title,
        challengeDescription: _currentChallenge.shortDescription,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('챌린지를 공유하지 못했습니다.'),
        ),
      );
    }
  }

  Widget _buildChallengeImage(
      Challenge challenge,
      double screenWidth,
      ) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: AspectRatio(
        aspectRatio: 0.9,
        child: ClipRRect(
          borderRadius:
          BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 정기 챌린지는 Flutter 위젯으로 자동 렌더링
              // 일반 챌린지는 기존 이미지를 그대로 사용
              RecurringChallengeCover.supports(challenge)
                  ? RecurringChallengeCover(
                challenge: challenge,
              )
                  : _buildImageContent(
                challenge.imageUrl,
                screenWidth,
              ),

              // 살짝만 어둡게
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient:
                    LinearGradient(
                      begin:
                      Alignment.topCenter,
                      end:
                      Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black
                            .withOpacity(
                          0.18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 진행 중임을 나타내는 작은 상태 badge
              Positioned(
                right:
                screenWidth * 0.03,
                bottom:
                screenWidth * 0.03,
                child: Container(
                  padding:
                  EdgeInsets.symmetric(
                    horizontal:
                    screenWidth * 0.025,
                    vertical:
                    screenWidth * 0.012,
                  ),
                  decoration:
                  BoxDecoration(
                    color: const Color(
                      0xFF013328,
                    ).withOpacity(
                      0.88,
                    ),
                    borderRadius:
                    BorderRadius.circular(
                      30,
                    ),
                    border:
                    Border.all(
                      color: Colors
                          .amberAccent
                          .withOpacity(
                        0.3,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration:
                        const BoxDecoration(
                          color: Colors
                              .amberAccent,
                          shape:
                          BoxShape.circle,
                        ),
                      ),

                      SizedBox(
                        width:
                        screenWidth *
                            0.015,
                      ),

                      Text(
                        '진행 중',
                        style:
                        TextStyle(
                          color: Colors
                              .amberAccent,
                          fontFamily:
                          'kopub',
                          fontSize:
                          screenWidth *
                              0.026,
                          fontWeight:
                          FontWeight
                              .bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageContent(
      String url,
      double screenWidth,
      ) {
    if (url.isEmpty) {
      return _buildImageFallback(
        screenWidth,
      );
    }

    if (url.startsWith('http')) {
      return Image.network(
        url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (
            _,
            __,
            ___,
            ) {
          return _buildImageFallback(
            screenWidth,
          );
        },
      );
    }

    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (
            _,
            __,
            ___,
            ) {
          return _buildImageFallback(
            screenWidth,
          );
        },
      );
    }

    return Image.file(
      File(url),
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (
          _,
          __,
          ___,
          ) {
        return _buildImageFallback(
          screenWidth,
        );
      },
    );
  }

  Widget _buildImageFallback(
      double screenWidth,
      ) {
    return Container(
      color: Colors.white
          .withOpacity(0.055),
      alignment:
      Alignment.center,
      child: Icon(
        Icons.flag_outlined,
        color:
        Colors.white38,
        size:
        screenWidth * 0.11,
      ),
    );
  }

  Widget _buildChallengeHeading(
      Challenge challenge,
      double screenWidth,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          challenge.title,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'kopub',
            fontSize:
            screenWidth * 0.052,
            fontWeight:
            FontWeight.bold,
            height: 1.35,
          ),
        ),

        if (challenge.shortDescription
            .trim()
            .isNotEmpty) ...[
          SizedBox(
            height:
            screenWidth * 0.018,
          ),

          Text(
            challenge.shortDescription,
            style: TextStyle(
              color: Colors.white
                  .withOpacity(0.55),
              fontFamily:
              'kopub',
              fontSize:
              screenWidth * 0.032,
              height: 1.55,
            ),
          ),
        ],
      ],
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

  Future<void> _checkIfCompletedAndNavigate() async {
    if (!mounted) return;

    final provider =
    Provider.of<ChallengeProvider>(
      context,
      listen: false,
    );

    final savedBooks =
        Provider.of<SavedBooksProvider>(
          context,
          listen: false,
        ).savedBooks;

    final userId =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    // refresh 전 현재 Attempt 기억
    final beforeAttempt =
        _currentChallenge.currentAttempt;

    final beforeAttemptId =
        beforeAttempt?.attemptId;

    await provider.refreshChallengeStatus(
      _currentChallenge.id,
      savedBooks: savedBooks,
      userId: userId,
    );

    // ✅ await 이후 반드시 체크
    if (!mounted) return;

    final refreshed =
    provider.findChallengeById(
      _currentChallenge.id,
    );

    if (refreshed == null) {
      return;
    }

    // =====================================================
    // refresh 도중 자동 스테이지 실패 여부 확인
    // =====================================================

    final originalAttemptStillExists =
        beforeAttemptId == null ||
            refreshed.attempts.any(
                  (attempt) =>
              attempt.attemptId ==
                  beforeAttemptId,
            );

    if (!originalAttemptStillExists) {
      if (!mounted) return;

      setState(() {
        _currentChallenge =
            refreshed;
      });

      final failure =
      provider.consumePendingStageFailure();

      if (!mounted) return;

      if (failure != null) {
        await _showStageFailedDialog(
          failure,
        );
      }

      return;
    }

    // ✅ 이미 완료되었거나 참여가 종료된 챌린지는
    // 성공/실패 판정을 다시 실행하지 않음
    if (!refreshed.isJoined ||
        refreshed.attempts.isEmpty ||
        refreshed.attempts.last.completed) {
      return;
    }

    final checkType =
    getChallengeCheckActionType(
      refreshed,
    );

    final record =
    checkType ==
        ChallengeCheckActionType
            .libraryAuto
        ? savedBooks
        : refreshed.attempts.isNotEmpty
        ? refreshed
        .attempts
        .last
        .recordData ??
        {}
        : {};

    if (!mounted) return;

    setState(() {
      _currentChallenge =
          refreshed;

      _recordWithBooks =
      <String, dynamic>{
        ...(record is Map
            ? Map<String, dynamic>.from(
          record,
        )
            : {}),
        'savedBooks': savedBooks,
      };
    });

    final completed =
    ChallengeProgressUtils
        .isChallengeCompleted(
      refreshed,
      _recordWithBooks,
      targetBooksOverride:
      _displayTargetBooks,
    );

    final failed =
    ChallengeProgressUtils
        .isChallengeFailed(
      refreshed,
      _recordWithBooks,
      targetBooksOverride:
      _displayTargetBooks,
    );

    if (completed) {
      await provider.markChallengeAsCompleted(
        refreshed.id,
        userId,
      );

      // ✅ 또 await 뒤
      if (!mounted) return;

      final finalRefreshed =
      provider.findChallengeById(
        refreshed.id,
      );

      if (finalRefreshed == null || !mounted) {
        return;
      }

// ✅ 실제 성공 확정 여부 검사
      final latestAttempt = finalRefreshed.attempts.isNotEmpty
          ? finalRefreshed.attempts.last
          : null;

      if (latestAttempt == null ||
          !latestAttempt.completed ||
          !latestAttempt.isSuccessful) {
        // 성공 처리 요청이 실패/만료로 변경된 경우
        // 성공 다이얼로그를 표시하지 않음
        setState(() {
          _currentChallenge = finalRefreshed;
        });

        _goToChallengeHome();
        return;
      }

      setState(() {
        _currentChallenge = finalRefreshed;
      });

      if (!mounted) return;

      final isStaged =
          _currentChallenge.stageType ==
              ChallengeStageType.staged;

      final isFinalStageCompleted =
      isStaged
          ? _currentChallenge
          .isFinalStageCompleted
          : _currentChallenge
          .isCompleted;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            ChallengeCompletionDialog(
              challenge:
              _currentChallenge,
            ),
      );

      // ✅ dialog 기다리는 동안 화면 사라질 수 있음
      if (!mounted) return;

      if (isStaged &&
          !isFinalStageCompleted) {
        Navigator.of(context)
            .pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) =>
            const MainScreen(
              initialTabIndex: 2,
            ),
          ),
              (route) => false,
        );

        return;
      }

      Navigator.of(context)
          .pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              ChallengeDoneScreen(
                challenge:
                _currentChallenge,
              ),
        ),
      );
    } else if (failed) {
      await provider.markChallengeAsFailed(
        _currentChallenge.id,
        userId,
      );

      // ✅ await 뒤
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (ctx) {
          final screenWidth =
              MediaQuery.of(ctx).size.width;

          final titleFontSize =
              screenWidth * 0.045;

          final contentFontSize =
              screenWidth * 0.038;

          return AlertDialog(
            backgroundColor:
            const Color(
              0xFF1B2C2E,
            ),
            shape:
            RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(
                16,
              ),
            ),
            title: Text(
              '챌린지를 실패했어요',
              style: TextStyle(
                fontFamily: 'kopub',
                fontWeight:
                FontWeight.bold,
                fontSize:
                titleFontSize,
                color: Colors.white,
              ),
            ),
            content: Text(
              '도전 기간 내에 목표를 달성하지 못했어요.\n'
                  '다음에 다시 도전해보세요!',
              style: TextStyle(
                fontFamily: 'kopub',
                fontSize:
                contentFontSize,
                height: 1.4,
                color: Colors.white70,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // ✅ dialog context 사용
                  Navigator.of(ctx).pop();

                  if (!mounted) return;

                  Navigator.of(context)
                      .pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) =>
                      const MainScreen(
                        initialTabIndex:
                        2,
                      ),
                    ),
                        (route) => false,
                  );
                },
                child: const Text(
                  '확인',
                  style: TextStyle(
                    color:
                    Colors.amberAccent,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _showStageFailedDialog(
      Map<String, dynamic> failure,
      ) async {
    if (!mounted) return;

    final stageIndex =
        failure['stageIndex'] as int? ??
            0;

    final stageNumber =
        stageIndex + 1;

    final challengeTitle =
        failure['challengeTitle']
        as String? ??
            '챌린지';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final screenWidth =
            MediaQuery.of(ctx).size.width;

        return AlertDialog(
          backgroundColor:
          const Color(
            0xFF1B2C2E,
          ),
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              16,
            ),
          ),
          title: Text(
            '$stageNumber단계 도전에 실패했어요',
            style: TextStyle(
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
          content: Text(
            '$challengeTitle\n\n'
                '하루라도 10분의 독서 목표를 채우지 못하면 '
                '현재 스테이지는 실패하게 돼요.\n\n'
                '${stageNumber == 1 ? '다시 1단계부터 도전할 수 있어요.' : '이전 스테이지의 성공 기록은 유지되며, $stageNumber단계부터 다시 도전할 수 있어요.'}',
            style: TextStyle(
              color:
              Colors.white70,
              fontFamily:
              'kopub',
              fontSize:
              screenWidth *
                  0.034,
              height:
              1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx)
                    .pop();
              },
              child:
              const Text(
                '확인',
                style:
                TextStyle(
                  color:
                  Colors.amberAccent,
                  fontFamily:
                  'kopub',
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    Navigator.of(context)
        .pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
        const MainScreen(
          initialTabIndex:
          2,
        ),
      ),
          (route) => false,
    );
  }

  /// 챌린지 포기하기
  Future<void> _showGiveUpDialog() async {
    final isCustom = _currentChallenge.isCustom == true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final screenWidth = MediaQuery.of(ctx).size.width;
        final titleFontSize = screenWidth * 0.045;
        final contentFontSize = screenWidth * 0.035;

        return AlertDialog(
          backgroundColor: const Color(0xFF1B2C2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "정말 포기하시겠어요?",
            style: TextStyle(
              fontFamily: 'kopub',
              fontWeight: FontWeight.bold,
              fontSize: titleFontSize,
              color: Colors.white,
            ),
          ),
          content: Text(
            isCustom
                ? "이 사용자 챌린지는 포기하면 리스트에서 완전히 삭제돼요.\n그래도 포기하시겠어요?"
                : "지금까지의 챌린지 기록이 모두 삭제됩니다.\n그래도 포기하시겠어요?",
            style: TextStyle(
              fontFamily: 'kopub',
              fontSize: contentFontSize,
              height: 1.4,
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("계속 도전할래요", style: TextStyle(color: Colors.amberAccent)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("네, 포기할게요", style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      final provider = context.read<ChallengeProvider>();
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

      // ✅ 타입별 분기는 Provider가 내부에서 처리 (커스텀이면 삭제)
      await provider.giveUpChallenge(_currentChallenge, userId);

      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen(initialTabIndex: 2)),
            (route) => false,
      );
    }
  }

}

