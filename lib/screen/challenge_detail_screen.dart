import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/provider/user_data_provider.dart';
import 'package:dayverse_book/screen/challenge_ongoing_screen.dart';
import 'package:dayverse_book/utils/challenge_check_utils.dart';
import 'package:dayverse_book/utils/challenge_stage_utils.dart';
import 'package:dayverse_book/service/book_api_service.dart';
import 'package:dayverse_book/service/challenge_record_service.dart';
import 'package:dayverse_book/widget/login_please_dialog.dart';
import 'package:dayverse_book/widget/calendar_widget.dart';
import 'package:dayverse_book/widget/challenge/challege_book_selection_box.dart';
import 'package:dayverse_book/widget/challenge/challenge_summary_card.dart';
import 'package:dayverse_book/widget/challenge/challenge_description_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dayverse_book/utils/book_pool_loader.dart';

import '../widget/card_box.dart'; // ✅ 추가
import 'package:dayverse_book/service/friend_service.dart';
import 'package:dayverse_book/widget/challenge/challenge_friend_invite_sheet.dart';
import 'package:dayverse_book/service/challenge_social_service.dart';
import 'package:dayverse_book/model/challenge_group_invitation_model.dart';
import 'package:dayverse_book/widget/recurring_challenge_cover.dart';
import 'package:dayverse_book/service/challenge_share_service.dart';

class ChallengeDetailScreen extends StatefulWidget {
  final Challenge challenge;

  /// 친구의 챌린지 초대를 통해 들어온 경우에만 존재.
  ///
  /// null:
  /// 일반 챌린지 상세 진입
  ///
  /// not null:
  /// 친구와 함께 도전하기 위한 초대 진입
  final ChallengeGroupInvitationModel? invitation;

  const ChallengeDetailScreen({
    super.key,
    required this.challenge,
    this.invitation,
  });

  @override
  State<ChallengeDetailScreen> createState() =>
      _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState
    extends State<ChallengeDetailScreen> {
  List<BookModel> detailedRequiredBooks = [];

  @override
  void initState() {
    super.initState();

    _loadRequiredBookDetails();
  }

  Future<void> _loadRequiredBookDetails() async {
    try {
      // 1. Book Pool 기반
      if (widget.challenge.requiredBooksPoolId != null &&
          widget.challenge.requiredBooksPoolId!.isNotEmpty) {
        final entries =
        await BookPoolLoader.loadPoolEntries(
          widget.challenge.requiredBooksPoolId!,
        );

        final isbnsFromPool = entries
            .map(
              (e) =>
              (e.isbn ?? e.isbn13 ?? '').trim(),
        )
            .where(
              (isbn) => isbn.isNotEmpty,
        )
            .toList();

        if (isbnsFromPool.isNotEmpty) {
          final result =
          await BookApiService.fetchBooksByIsbnList(
            isbnsFromPool,
          );

          if (mounted && result.isNotEmpty) {
            setState(() {
              detailedRequiredBooks = result;
            });

            return;
          }
        }

        final fallback =
        await BookPoolLoader.loadPoolAsBookModels(
          widget.challenge.requiredBooksPoolId!,
        );

        if (mounted && fallback.isNotEmpty) {
          setState(() {
            detailedRequiredBooks = fallback;
          });

          return;
        }
      }

      // 2. 기존 requiredBooks 기반
      List<String> isbns = [];

      if (widget.challenge.requiredBooks != null &&
          widget.challenge.requiredBooks!.isNotEmpty) {
        isbns = widget.challenge.requiredBooks!
            .map(
              (book) =>
              (book.isbn ?? '').trim(),
        )
            .where(
              (isbn) => isbn.isNotEmpty,
        )
            .toList();
      }

      // 3. ISBN 상세 조회
      if (isbns.isNotEmpty) {
        final result =
        await BookApiService.fetchBooksByIsbnList(
          isbns,
        );

        if (mounted && result.isNotEmpty) {
          setState(() {
            detailedRequiredBooks = result;
          });

          return;
        }
      }

      // 4. 최종 fallback
      final baseBooks =
          widget.challenge.requiredBooks ?? [];

      if (baseBooks.isNotEmpty) {
        final result =
        await BookApiService.fetchRequiredBooksFromApi(
          baseBooks,
        );

        if (mounted) {
          setState(() {
            detailedRequiredBooks = result;
          });
        }
      }
    } catch (e) {
      debugPrint(
        '⚠️ _loadRequiredBookDetails error: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width;

    final screenHeight =
        MediaQuery.of(context).size.height;

    final challenge =
        widget.challenge;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,

      onHorizontalDragEnd: (details) {
        final velocity =
            details.primaryVelocity ?? 0;

        if (velocity > 500) {
          Navigator.pop(context);
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
                screenHeight * 0.17,
              ),

              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  // 1. 대표 이미지
                  _buildChallengeImage(
                    challenge,
                    screenWidth,
                  ),

                  SizedBox(
                    height:
                    screenHeight * 0.025,
                  ),

                  // 2. 제목
                  _buildChallengeHeading(
                    challenge,
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

                  // 3. 요약
                  _buildSectionTitle(
                    screenWidth,
                    'CHALLENGE SUMMARY',
                  ),

                  SizedBox(
                    height:
                    screenHeight * 0.015,
                  ),

                  SummaryCard(
                    challenge: challenge,
                  ),

                  // 4. 지정 도서
                  if (challenge.method ==
                      ChallengeMethod.specificBooks &&
                      detailedRequiredBooks
                          .isNotEmpty) ...[
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

                    _buildSpecificBookSection(
                      challenge,
                      screenWidth,
                    ),
                  ],

                  // 5. 상세 설명
                  if (_hasDescriptionContent(
                    challenge,
                  )) ...[
                    SizedBox(
                      height:
                      screenHeight * 0.04,
                    ),

                    _buildSectionTitle(
                      screenWidth,
                      'CHALLENGE DETAIL',
                    ),

                    SizedBox(
                      height:
                      screenHeight * 0.015,
                    ),

                    _buildDescriptionSections(
                      challenge,
                      screenWidth,
                    ),
                  ],
                ],
              ),
            ),

            // 6. CTA
            _buildJoinButton(
              context,
              screenWidth,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // APP BAR
  // =========================================================

  PreferredSizeWidget _buildAppBar(double screenWidth) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,

      leading: IconButton(
        onPressed: () {
          Navigator.pop(context);
        },
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: Colors.white,
        ),
      ),

      title: Text(
        '챌린지 상세',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'kopub',
          fontSize: screenWidth * 0.045,
          fontWeight: FontWeight.bold,
        ),
      ),

      // 챌린지 공유 버튼
      actions: [
        IconButton(
          tooltip: '챌린지 공유하기',
          icon: Icon(
            Icons.ios_share_rounded,
            color: Colors.white,
            size: screenWidth * 0.055,
          ),
          onPressed: _shareChallenge,
        ),
        SizedBox(width: screenWidth * 0.01),
      ],
    );
  }

  Future<void> _shareChallenge() async {
    try {
      await ChallengeShareService.shareChallenge(
        context: context,
        challengeId: widget.challenge.id,
        challengeTitle: widget.challenge.title,
        challengeDescription:
        widget.challenge.shortDescription,
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

  // =========================================================
  // IMAGE
  // =========================================================

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
              RecurringChallengeCover.supports(challenge)
                  ? RecurringChallengeCover(
                challenge: challenge,
                borderRadius: BorderRadius.zero,
              )
                  : Image.asset(
                challenge.imageUrl,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) {
                  return Container(
                    color: Colors.white.withOpacity(0.055),
                    child: Icon(
                      Icons.flag_outlined,
                      color: Colors.white38,
                      size: screenWidth * 0.11,
                    ),
                  );
                },
              ),

              // 이미지 하단을 아주 살짝 어둡게
              // 제목 카드와 시각적으로 자연스럽게 연결
              Positioned.fill(
                child: Container(
                  decoration:
                  BoxDecoration(
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
                          0.16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // HEADING
  // =========================================================

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

        if (challenge.goalDescription != null &&
            challenge.goalDescription!
                .trim()
                .isNotEmpty) ...[
          SizedBox(
            height:
            screenWidth * 0.018,
          ),

          Text(
            challenge.goalDisplayText ??
                challenge.goalDescription!,
            style: TextStyle(
              color: Colors.white
                  .withOpacity(0.55),
              fontFamily: 'kopub',
              fontSize:
              screenWidth * 0.032,
              height: 1.55,
            ),
          ),
        ],
      ],
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

  // =========================================================
  // SPECIFIC BOOKS
  // =========================================================

  Widget _buildSpecificBookSection(
      Challenge challenge,
      double screenWidth,
      ) {
    final savedBooks =
        context
            .read<SavedBooksProvider>()
            .savedBooks;

    final readBookIds = savedBooks
        .where(
          (book) =>
      book.category == 'done',
    )
        .map(
          (book) => book.id,
    )
        .toSet();

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        // 안내
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal:
            screenWidth * 0.035,
            vertical:
            screenWidth * 0.028,
          ),
          decoration: BoxDecoration(
            color: Colors.amberAccent
                .withOpacity(0.07),
            borderRadius:
            BorderRadius.circular(12),
            border: Border.all(
              color: Colors.amberAccent
                  .withOpacity(0.14),
            ),
          ),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Icon(
                Icons
                    .info_outline_rounded,
                color:
                Colors.amberAccent
                    .withOpacity(0.8),
                size:
                screenWidth * 0.042,
              ),

              SizedBox(
                width:
                screenWidth * 0.02,
              ),

              Expanded(
                child: Text(
                  '읽은 책도 챌린지 참여 시 '
                      '처음부터 다시 읽기 상태로 전환됩니다.',
                  style: TextStyle(
                    color: Colors.white
                        .withOpacity(0.58),
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth *
                        0.027,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(
          height:
          screenWidth * 0.025,
        ),

        ...detailedRequiredBooks.map(
              (book) {
            final isRead =
            readBookIds.contains(
              book.id,
            );

            return Padding(
              padding: EdgeInsets.only(
                bottom:
                screenWidth * 0.025,
              ),

              child: _buildRequiredBookCard(
                book: book,
                isRead: isRead,
                screenWidth:
                screenWidth,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRequiredBookCard({
    required BookModel book,
    required bool isRead,
    required double screenWidth,
  }) {
    final imageWidth =
        screenWidth * 0.14;

    final imageHeight =
        imageWidth * 1.42;

    return CardBox(
      margin: EdgeInsets.zero,

      padding: EdgeInsets.all(
        screenWidth * 0.03,
      ),

      child: Row(
        children: [
          // 표지
          Container(
            decoration:
            BoxDecoration(
              borderRadius:
              BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withOpacity(0.2),
                  blurRadius: 7,
                  offset:
                  const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius:
              BorderRadius.circular(7),

              child: (book.imageUrl
                  ?.isNotEmpty ==
                  true)
                  ? Image.network(
                book.imageUrl!,
                width:
                imageWidth,
                height:
                imageHeight,
                fit: BoxFit.cover,

                loadingBuilder: (
                    context,
                    child,
                    progress,
                    ) {
                  if (progress ==
                      null) {
                    return child;
                  }

                  return Container(
                    width:
                    imageWidth,
                    height:
                    imageHeight,
                    color: Colors
                        .white
                        .withOpacity(
                      0.05,
                    ),
                    alignment:
                    Alignment
                        .center,
                    child:
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                      CircularProgressIndicator(
                        color: Colors
                            .amberAccent,
                        strokeWidth:
                        2,
                      ),
                    ),
                  );
                },

                errorBuilder: (
                    _,
                    __,
                    ___,
                    ) {
                  return _buildBookCoverFallback(
                    imageWidth,
                    imageHeight,
                  );
                },
              )
                  : _buildBookCoverFallback(
                imageWidth,
                imageHeight,
              ),
            ),
          ),

          SizedBox(
            width:
            screenWidth * 0.03,
          ),

          // 정보
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  book.title,
                  maxLines: 2,
                  overflow:
                  TextOverflow
                      .ellipsis,
                  style: TextStyle(
                    color:
                    Colors.white,
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth *
                        0.033,
                    fontWeight:
                    FontWeight
                        .bold,
                    height: 1.35,
                  ),
                ),

                if (book.author
                    .trim()
                    .isNotEmpty) ...[
                  SizedBox(
                    height:
                    screenWidth *
                        0.008,
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
                          0.028,
                    ),
                  ),
                ],

                if (book.pageCount >
                    0) ...[
                  SizedBox(
                    height:
                    screenWidth *
                        0.018,
                  ),

                  Text(
                    '${book.pageCount}페이지',
                    style:
                    TextStyle(
                      color: Colors
                          .white38,
                      fontFamily:
                      'kopub',
                      fontSize:
                      screenWidth *
                          0.027,
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (isRead) ...[
            SizedBox(
              width:
              screenWidth * 0.02,
            ),

            Container(
              padding:
              EdgeInsets.symmetric(
                horizontal:
                screenWidth * 0.022,
                vertical:
                screenWidth * 0.011,
              ),
              decoration:
              BoxDecoration(
                color: Colors
                    .amberAccent
                    .withOpacity(
                  0.10,
                ),
                borderRadius:
                BorderRadius.circular(
                  30,
                ),
                border: Border.all(
                  color: Colors
                      .amberAccent
                      .withOpacity(
                    0.25,
                  ),
                ),
              ),
              child: Text(
                '읽음',
                style:
                TextStyle(
                  color: Colors
                      .amberAccent,
                  fontFamily:
                  'kopub',
                  fontSize:
                  screenWidth *
                      0.025,
                  fontWeight:
                  FontWeight
                      .bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBookCoverFallback(
      double width,
      double height,
      ) {
    return Container(
      width: width,
      height: height,
      color:
      Colors.white.withOpacity(
        0.055,
      ),
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
  // DESCRIPTION
  // =========================================================

  bool _hasDescriptionContent(
      Challenge challenge,
      ) {
    return (challenge.longDescription
        ?.trim()
        .isNotEmpty ??
        false) ||
        (challenge.goalDescription
            ?.trim()
            .isNotEmpty ??
            false) ||
        (challenge.recommendedFor
            ?.trim()
            .isNotEmpty ??
            false) ||
        (challenge.guideText
            ?.trim()
            .isNotEmpty ??
            false);
  }

  Widget _buildDescriptionSections(
      Challenge challenge,
      double screenWidth,
      ) {
    return Column(
      children: [
        if (challenge.longDescription !=
            null)
          DescriptionCard(
            title:
            '챌린지 소개',
            content:
            challenge
                .longDescription!,
          ),

        if (challenge.goalDescription !=
            null)
          DescriptionCard(
            title:
            '챌린지 목표',
            content:
            challenge
                .goalDisplayText ??
                challenge
                    .goalDescription!,
          ),

        if (challenge.recommendedFor !=
            null)
          DescriptionCard(
            title:
            '이런 분께 추천',
            content:
            challenge
                .recommendedFor!,
          ),

        if (challenge.guideText != null)
          DescriptionCard(
            title:
            '진행 방법',
            content:
            challenge.guideText!,
          ),
      ],
    );
  }

  // =========================================================
  // JOIN BUTTON
  // =========================================================

  Widget _buildJoinButton(
      BuildContext context,
      double screenWidth,
      ) {
    return Positioned(
      left:
      screenWidth * 0.05,
      right:
      screenWidth * 0.05,
      bottom: 24,

      child: SafeArea(
        top: false,

        child: Container(
          decoration:
          BoxDecoration(
            borderRadius:
            BorderRadius.circular(
              16,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withOpacity(0.28),
                blurRadius: 14,
                offset:
                const Offset(0, 6),
              ),
            ],
          ),

          child: ElevatedButton(
            onPressed: () async {
              final user =
                  FirebaseAuth
                      .instance
                      .currentUser;

              if (user == null) {
                ScaffoldMessenger
                    .of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text(
                        '사용자 정보를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.',
                      ),
                    ),
                  );

                return;
              }

              final result =
              await showDialog<
                  Challenge>(
                context:
                context,
                barrierDismissible:
                true,
                builder: (_) =>
                    ChallengeParticipationDialog(
                      challenge:
                      widget.challenge,

                      invitation:
                      widget.invitation,
                    ),
              );

              if (result != null &&
                  mounted) {
                // =====================================================
                // 친구 초대를 통해 들어온 챌린지라면
                // 실제 개인 챌린지 참여 성공 후
                // 함께 도전 그룹에도 합류
                // =====================================================

                final invitation =
                    widget.invitation;

                if (invitation != null) {
                  try {
                    if (result.attempts.isEmpty) {
                      throw StateError(
                        '참여한 챌린지의 Attempt 정보를 찾을 수 없습니다.',
                      );
                    }

                    final joinedAttempt =
                        result.attempts.last;

                    final memberAttemptId =
                    joinedAttempt.attemptId.trim();

                    if (memberAttemptId.isEmpty) {
                      throw StateError(
                        '참여한 챌린지의 Attempt ID를 확인할 수 없습니다.',
                      );
                    }

                    await ChallengeSocialService.instance
                        .acceptChallengeInvite(
                      groupId:
                      invitation.groupId,

                      memberAttemptId:
                      memberAttemptId,
                    );

                    debugPrint(
                      '✅ 챌린지 초대 수락 완료: '
                          'groupId=${invitation.groupId}, '
                          'memberAttemptId=$memberAttemptId',
                    );
                  } on FirebaseFunctionsException catch (e) {
                    debugPrint(
                      '⚠️ 챌린지에는 참여했지만 '
                          '그룹 합류 실패: '
                          '${e.code} / ${e.message}',
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            '챌린지에는 참여했지만 '
                                '함께 도전 그룹에 합류하지 못했습니다.',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    debugPrint(
                      '⚠️ 챌린지에는 참여했지만 '
                          '그룹 합류 실패: $e',
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            '챌린지에는 참여했지만 '
                                '함께 도전 그룹에 합류하지 못했습니다.',
                          ),
                        ),
                      );
                    }
                  }
                }

                if (!mounted) return;

                Navigator.of(context)
                    .pushReplacement(
                  MaterialPageRoute(
                    builder: (_) =>
                        ChallengeOngoingScreen(
                          challenge:
                          result,
                        ),
                  ),
                );
              }
            },

            style:
            ElevatedButton
                .styleFrom(
              backgroundColor:
              Colors.amberAccent,
              foregroundColor:
              const Color(
                0xFF013328,
              ),
              elevation: 0,

              padding:
              EdgeInsets.symmetric(
                vertical:
                screenWidth *
                    0.043,
              ),

              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(
                  16,
                ),
              ),
            ),

            child: Text(
              widget.invitation != null
                  ? '함께 도전하기'
                  : '챌린지 참여하기',
              style: TextStyle(
                color:
                const Color(0xFF013328),
                fontWeight:
                FontWeight.bold,
                fontFamily:
                'kopub',
                fontSize:
                screenWidth * 0.04,
              ),
            ),
          ),
        ),
      ),
    );
  }

}



/// 참여 다이얼로그
const bool kAllowSameDayStageAdvanceForDebug = false;


class ChallengeParticipationDialog extends StatefulWidget {
  final Challenge challenge;

  /// 친구와 함께 도전 초대로 진입한 경우에만 존재
  final ChallengeGroupInvitationModel? invitation;

  const ChallengeParticipationDialog({
    super.key,
    required this.challenge,
    this.invitation,
  });

  @override
  State<ChallengeParticipationDialog> createState() =>
      _ChallengeParticipationDialogState();
}

class _ChallengeParticipationDialogState extends State<ChallengeParticipationDialog> {
  int? selectedDuration;
  DateTime? selectedStartDate;
  List<BookModel> searchResults = [];
  List<BookModel> selectedBooks = [];
  final TextEditingController searchController = TextEditingController();
  bool _isJoining = false;
  bool _isLoadingBooks = false;            // ← 목록 로딩 상태
  List<BookModel> detailedRequiredBooks = [];
  final ScrollController _scrollController = ScrollController();
  bool get isInvitationMode =>
      widget.invitation != null;

  bool get isDaily10MinHabit =>
      widget.challenge.id ==
          'daily_10min_habit';

  int _getNextStageIndex(Challenge challenge) {
    if (challenge.stageType != ChallengeStageType.staged) return 0;

    final completedStages = challenge.attempts
        .where((a) => a.completed == true && a.isSuccessful == true)
        .length;

    final maxIndex = challenge.stageDurations.length - 1;
    return completedStages.clamp(0, maxIndex);
  }

  int? _getStageDurationForJoin(Challenge challenge) {
    if (challenge.stageType != ChallengeStageType.staged ||
        challenge.stageDurations.isEmpty) {
      return null;
    }

    final nextStageIndex = _getNextStageIndex(challenge);
    return challenge.stageDurations[nextStageIndex];
  }

  @override
  void initState() {
    super.initState();

    final c = widget.challenge;
    final invitation = widget.invitation;

    // =====================================================
    // 친구 초대 참여
    //
    // 초대한 사람의 설정값을 그대로 사용한다.
    // =====================================================
    if (invitation != null) {
      selectedStartDate =
          invitation.startDate;

      selectedDuration =
          invitation.selectedDuration;

      selectedBooks =
      List<BookModel>.from(
        invitation.participatingBooks,
      );
    } else {
      // =====================================================
      // 일반 참여
      // =====================================================

      final stageDuration =
      _getStageDurationForJoin(c);

      // 10 Minutes Habit은
      // 참여하는 오늘이 곧 시작일
      if (c.id ==
          'daily_10min_habit') {
        final now =
        DateTime.now();

        selectedStartDate =
            DateTime(
              now.year,
              now.month,
              now.day,
            );
      }

      if (stageDuration != null) {
        selectedDuration =
            stageDuration;
      } else if (
      c.durationOptions?.isNotEmpty ==
          true) {
        selectedDuration =
            c.durationOptions!.first;
      } else if (
      c.checkCountOptions?.isNotEmpty ==
          true) {
        selectedDuration =
            c.checkCountOptions!.first;
      }
    }

    // 시스템 지정 도서는
    // 초대 여부와 관계없이 동일 챌린지의 지정 도서를 사용
    if (c.method ==
        ChallengeMethod.specificBooks &&
        c.specificBookMode ==
            SpecificBookMode.systemDefined) {
      _loadBooksForSystemDefined();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBooksForSystemDefined() async {
    try {
      setState(() => _isLoadingBooks = true);

      // 1) 풀 기반: ISBN 있으면 상세 API, 없거나 실패하면 풀→BookModel로 표시
      if ((widget.challenge.requiredBooksPoolId ?? '').isNotEmpty) {
        final entries = await BookPoolLoader.loadPoolEntries(widget.challenge.requiredBooksPoolId!);
        final isbns = entries
            .map((e) => (e.isbn ?? e.isbn13 ?? '').trim())
            .where((s) => s.isNotEmpty)
            .toList();

        if (isbns.isNotEmpty) {
          final result = await BookApiService.fetchBooksByIsbnList(isbns);
          if (mounted && result.isNotEmpty) {
            setState(() {
              detailedRequiredBooks = result;
              _isLoadingBooks = false;
            });
            return;
          }
        }

        // ISBN 기반 상세가 비었을 때 최소 표시용
        final fallback = await BookPoolLoader.loadPoolAsBookModels(widget.challenge.requiredBooksPoolId!);
        if (mounted) {
          setState(() {
            detailedRequiredBooks = fallback;
            _isLoadingBooks = false;
          });
        }
        return;
      }

      // 2) 구버전(풀 없음): requiredBooks 기반
      final base = widget.challenge.requiredBooks ?? const <BookModel>[];
      if (base.isNotEmpty) {
        final result = await BookApiService.fetchRequiredBooksFromApi(base);
        if (mounted) {
          setState(() {
            detailedRequiredBooks = result;
            _isLoadingBooks = false;
          });
        }
        return;
      }

      if (mounted) setState(() => _isLoadingBooks = false);
    } catch (e) {
      debugPrint('⚠️ _loadBooksForSystemDefined error: $e');
      if (mounted) setState(() => _isLoadingBooks = false);
    }
  }

  bool get needsStartDate =>
      widget.challenge.category == ChallengeCategory.routine &&
          widget.challenge.period == ChallengePeriod.daysBased;

  bool get allowsUserBookSelection =>
      widget.challenge.method == ChallengeMethod.specificBooks &&
          widget.challenge.specificBookMode == SpecificBookMode.userDefined;

  Future<void> _handleJoin() async {
    setState(() => _isJoining = true); // ✅ 로딩 시작

    try {
      final isPremiumActive = context.read<UserDataProvider>().isPremiumActive;
      final challenge = widget.challenge;

      if (challenge.isPremium && !isPremiumActive) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1B2C2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("프리미엄 전용",
                style: TextStyle(fontFamily: 'kopub', fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
            content: const Text(
              "이 챌린지는 프리미엄 회원만 참여할 수 있어요.\n프리미엄으로 업그레이드해보세요!",
              style: TextStyle(color: Colors.white70, fontFamily: 'kopub', fontSize: 14, height: 1.4),
            ),
            actions: [
              TextButton(
                child: const Text("확인", style: TextStyle(color: Colors.amberAccent)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
        return;
      }

      final savedBooksProvider = context.read<SavedBooksProvider>();
      final challengeProvider = context.read<ChallengeProvider>();

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _showSnackBar(
          "사용자 정보를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.",
        );
        return;
      }

      final userId = user.uid;
      Challenge challengeToJoin = challenge;

      final invitation =
          widget.invitation;

// =====================================================
// 친구 초대인 경우 그룹 설정 유효성 확인
// =====================================================

      if (invitation != null) {
        if (challenge.stageType ==
            ChallengeStageType.staged) {
          final expectedStageIndex =
          _getNextStageIndex(
            challenge,
          );

          if (invitation.stageIndex !=
              expectedStageIndex) {
            _showSnackBar(
              '현재 참여 가능한 챌린지 단계와 '
                  '친구의 도전 단계가 달라 함께 참여할 수 없습니다.',
            );

            return;
          }
        }

        if (allowsUserBookSelection &&
            invitation.participatingBooks.isEmpty) {
          _showSnackBar(
            '초대받은 챌린지의 도서 정보를 확인할 수 없습니다.',
          );

          return;
        }
      } else {
        // 일반 참여일 때만 직접 입력값 검사
        if (needsStartDate &&
            selectedStartDate == null) {
          _showSnackBar(
            '도전 시작일을 선택해주세요.',
          );

          return;
        }

        if (allowsUserBookSelection &&
            selectedBooks.isEmpty) {
          _showSnackBar(
            '도전에 사용할 책을 선택해주세요.',
          );

          return;
        }
      }

      final now =
      DateTime.now();

      final today =
      DateTime(
        now.year,
        now.month,
        now.day,
      );

      final startDate =
          invitation?.startDate ??
              (isDaily10MinHabit
                  ? today
                  : selectedStartDate ??
                  today);

      final duration =
          invitation?.selectedDuration ??
              selectedDuration;

// ✅ 스테이지 n 달성 당일에는 스테이지 n+1 참여 불가
      if (!kAllowSameDayStageAdvanceForDebug &&
          challenge.stageType == ChallengeStageType.staged &&
          challenge.attempts.isNotEmpty) {
        final prev = challenge.attempts.last;
        final prevEndDate = prev.endDate?.toLocal();

        if (prevEndDate != null) {
          final prevDay = DateTime(prevEndDate.year, prevEndDate.month, prevEndDate.day);
          final joinDay = DateTime(startDate.year, startDate.month, startDate.day);

          if (!joinDay.isAfter(prevDay)) {
            _showSnackBar("다음 스테이지는 다음 날부터 참여할 수 있어요.");
            return;
          }
        }
      }

      List<BookModel> booksToJoin = [];

      if (allowsUserBookSelection) {
        for (final book in selectedBooks) {
          BookModel updatedBook = book;


          // 페이지수가 없으면 YES24 ISBN 상세 조회
          final isbn = book.isbn?.trim();

          if (book.pageCount <= 0 &&
              isbn != null &&
              isbn.replaceAll(RegExp(r'[^0-9Xx]'), '').length == 13) {
            try {
              final fetched =
              await BookApiService.fetchBookDetailByIsbn(isbn);

              if (fetched != null && fetched.pageCount > 0) {
                updatedBook = book.copyWith(
                  pageCount: fetched.pageCount,
                );
              }
            } catch (e) {
              debugPrint('[챌린지 선택 도서 페이지수 조회 실패] $e');
            }
          }

          booksToJoin.add(updatedBook);

          await savedBooksProvider.addOrUpdateBook(
            updatedBook.copyWith(
              category: 'reading',
              startDate: startDate,
              pageRead: (updatedBook.pageRead > 0 && updatedBook.pageRead < (updatedBook.pageCount))
                  ? updatedBook.pageRead
                  : 1,
            ),
          );
        }
      } else if (challenge.method == ChallengeMethod.specificBooks &&
          challenge.specificBookMode == SpecificBookMode.systemDefined) {

        // 1) 다이얼로그에서 이미 로드했다면 그걸 우선 사용
        List<BookModel> sourceBooks = List<BookModel>.from(detailedRequiredBooks);

        // 2) 비어 있으면: 풀 → ISBN 상세 → 실패 시 풀→BookModel 최소세트
        if (sourceBooks.isEmpty) {
          if ((challenge.requiredBooksPoolId ?? '').isNotEmpty) {
            final entries = await BookPoolLoader.loadPoolEntries(challenge.requiredBooksPoolId!);
            final isbns = entries
                .map((e) => (e.isbn ?? e.isbn13 ?? '').trim())
                .where((s) => s.isNotEmpty)
                .toList();

            if (isbns.isNotEmpty) {
              sourceBooks = await BookApiService.fetchBooksByIsbnList(isbns);
            }
            if (sourceBooks.isEmpty) {
              sourceBooks = await BookPoolLoader.loadPoolAsBookModels(challenge.requiredBooksPoolId!);
            }
          }

          // 최종 fallback: 구버전 requiredBooks → API
          if (sourceBooks.isEmpty) {
            sourceBooks = await BookApiService.fetchRequiredBooksFromApi(challenge.requiredBooks ?? []);
          }
        }

        // 3) 사용자 서재 등록
        for (final book in sourceBooks) {

          // 지정 도서의 페이지수가 없으면 YES24에서 보완
          BookModel updated = book;
          final isbn = updated.isbn?.trim();

          if (updated.pageCount <= 0 &&
              isbn != null &&
              isbn.replaceAll(RegExp(r'[^0-9Xx]'), '').length == 13) {
            try {
              final fetched =
              await BookApiService.fetchBookDetailByIsbn(isbn);

              if (fetched != null && fetched.pageCount > 0) {
                updated = updated.copyWith(
                  pageCount: fetched.pageCount,
                );
              }
            } catch (e) {
              debugPrint('[챌린지 지정 도서 페이지수 조회 실패] $e');
            }
          }

          booksToJoin.add(updated);
          await savedBooksProvider.addOrUpdateBook(
            updated.copyWith(
              category: 'reading',
              startDate: startDate,
              pageRead: (updated.pageRead > 0 && updated.pageRead < updated.pageCount) ? updated.pageRead : 1,
            ),
          );
        }
      }



      // =====================================================
      // 챌린지 참여
      // =====================================================

      Challenge? updated;

// =====================================================
// 친구 초대를 통한 참여
// =====================================================

      if (invitation != null) {
        updated =
        await challengeProvider
            .joinChallengeFromInvitation(
          challenge:
          challengeToJoin,

          invitation:
          invitation,

          userId:
          userId,
        );
      }

// =====================================================
// 일반 참여
// =====================================================

      else {
        await challengeProvider.joinChallenge(
          challenge:
          challengeToJoin,

          startDate:
          startDate,

          duration:
          duration,

          participatingBooks:
          allowsUserBookSelection
              ? booksToJoin
              : null,

          userId:
          userId,
        );

        updated =
            challengeProvider.findChallengeById(
              challenge.id,
            );
      }

// =====================================================
// 참여 결과
// =====================================================

      if (updated != null) {
        _showCheerUpDialogAndPop(
          updated,
        );
      } else {
        _showSnackBar(
          '참여한 챌린지를 찾을 수 없습니다.',
        );
      }

    } catch (e) {
      debugPrint("❌ 챌린지 참여 오류: $e");
      _showSnackBar("도전 중 문제가 발생했습니다.");
    } finally {
      if (mounted) {
        setState(() => _isJoining = false); // ✅ 로딩 종료
      }
    }
  }

  void _showCheerUpDialogAndPop(
      Challenge updated,
      ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final screenWidth =
            MediaQuery.of(dialogContext)
                .size
                .width;

        Future.delayed(
          const Duration(seconds: 2),
              () {
            if (!mounted) return;

            Navigator.of(dialogContext)
                .pop();

            Navigator.of(context)
                .pop(updated);
          },
        );

        return Dialog(
          backgroundColor:
          Colors.transparent,
          insetPadding:
          EdgeInsets.symmetric(
            horizontal:
            screenWidth * 0.09,
          ),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal:
              screenWidth * 0.055,
              vertical:
              screenWidth * 0.055,
            ),
            decoration: BoxDecoration(
              color:
              const Color(0xFF16483F),
              borderRadius:
              BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white
                    .withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withOpacity(0.30),
                  blurRadius: 24,
                  offset:
                  const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                Container(
                  width:
                  screenWidth * 0.17,
                  height:
                  screenWidth * 0.17,
                  decoration: BoxDecoration(
                    color: Colors.amberAccent
                        .withOpacity(0.11),
                    shape:
                    BoxShape.circle,
                    border: Border.all(
                      color:
                      Colors.amberAccent
                          .withOpacity(
                        0.28,
                      ),
                    ),
                  ),
                  child: Icon(
                    Icons
                        .flag_rounded,
                    color:
                    Colors.amberAccent,
                    size:
                    screenWidth * 0.08,
                  ),
                ),

                SizedBox(
                  height:
                  screenWidth * 0.025,
                ),

                Text(
                  'CHALLENGE STARTED',
                  style: TextStyle(
                    color:
                    Colors.amberAccent,
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth * 0.024,
                    fontWeight:
                    FontWeight.bold,
                    letterSpacing: 1.8,
                  ),
                ),

                SizedBox(
                  height:
                  screenWidth * 0.025,
                ),

                Text(
                  updated.title,
                  textAlign:
                  TextAlign.center,
                  style: TextStyle(
                    color:
                    Colors.white,
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth * 0.04,
                    fontWeight:
                    FontWeight.bold,
                    height: 1.4,
                  ),
                ),

                SizedBox(
                  height:
                  screenWidth * 0.018,
                ),

                Text(
                  '도전을 시작했어요.\n'
                      '목표를 향해 한 걸음씩 나아가보세요.',
                  textAlign:
                  TextAlign.center,
                  style: TextStyle(
                    color: Colors.white
                        .withOpacity(0.60),
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth * 0.029,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void onSearchChanged(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() => searchResults = []);
      return;
    }

    try {
      final results = await BookApiService.searchBooks(keyword);
      setState(() => searchResults = results);
    } catch (_) {
      _showSnackBar("도서 검색 중 문제가 발생했습니다.");
    }
  }

  void onBookSelected(BookModel book) {
    setState(() {
      if (!selectedBooks.any((b) => b.id == book.id)) {
        selectedBooks.add(book);
      }
    });
  }

  void onBookRemoved(BookModel book) {
    setState(() => selectedBooks.removeWhere((b) => b.id == book.id));
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final screenWidth =
        MediaQuery.of(context).size.width;
    final screenHeight =
        MediaQuery.of(context).size.height;

    return WillPopScope(
      onWillPop: () async => !_isJoining,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05,
          vertical: screenHeight * 0.055,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.89,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF16483F),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.30),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // =================================================
              // HEADER
              // =================================================

              Padding(
                padding: EdgeInsets.fromLTRB(
                  screenWidth * 0.045,
                  screenWidth * 0.045,
                  screenWidth * 0.025,
                  screenWidth * 0.025,
                ),
                child: Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            isInvitationMode
                                ? '함께 도전하기'
                                : '챌린지 참여하기',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'kopub',
                              fontSize:
                              screenWidth * 0.047,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),

                          SizedBox(
                            height:
                            screenWidth * 0.012,
                          ),

                          Text(
                            isInvitationMode
                                ? '친구가 설정한 조건으로 함께 도전합니다.'
                                : '도전을 시작하기 전에 설정을 확인해주세요.',
                            style: TextStyle(
                              color: Colors.white
                                  .withOpacity(0.50),
                              fontFamily: 'kopub',
                              fontSize:
                              screenWidth * 0.028,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),

                    IconButton(
                      tooltip: '닫기',
                      onPressed: _isJoining
                          ? null
                          : () {
                        Navigator.pop(context);
                      },
                      icon: Icon(
                        Icons.close_rounded,
                        color: _isJoining
                            ? Colors.white24
                            : Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),

              Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withOpacity(0.07),
              ),

              // =================================================
              // CONTENT
              // =================================================

              Flexible(
                child: RawScrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  thumbColor:
                  Colors.white.withOpacity(0.22),
                  trackColor: Colors.transparent,
                  trackBorderColor:
                  Colors.transparent,
                  thickness: 3,
                  radius:
                  const Radius.circular(20),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      screenWidth * 0.045,
                      screenWidth * 0.035,
                      screenWidth * 0.05,
                      screenWidth * 0.035,
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        _buildChallengeOptions(
                          challenge,
                          screenWidth,
                        ),

                        if (allowsUserBookSelection ||
                            challenge.specificBookMode ==
                                SpecificBookMode.systemDefined) ...[
                          SizedBox(
                            height:
                            screenWidth * 0.04,
                          ),

                          _buildBookSection(
                            screenWidth,
                          ),
                        ],

                        SizedBox(
                          height:
                          screenWidth * 0.04,
                        ),

                      ],
                    ),
                  ),
                ),
              ),

              // =================================================
              // BOTTOM CTA
              // =================================================

              Container(
                padding: EdgeInsets.fromLTRB(
                  screenWidth * 0.045,
                  screenWidth * 0.025,
                  screenWidth * 0.045,
                  screenWidth * 0.04,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white
                          .withOpacity(0.07),
                    ),
                  ),
                ),
                child: _buildJoinButton(
                  screenWidth,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeOptions(
      Challenge challenge,
      double screenWidth,
      ) {
    if (isInvitationMode) {
      return _buildInvitationOptions(
        challenge,
        screenWidth,
      );
    }

    final hasStageDurations =
        challenge.stageDurations.isNotEmpty;

    final hasDurationOptions =
        challenge.durationOptions?.isNotEmpty ??
            false;

    final hasCheckCountOptions =
        challenge.checkCountOptions?.isNotEmpty ??
            false;

    final currentStageIndex =
    _getNextStageIndex(challenge);

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        if (challenge.period ==
            ChallengePeriod.periodBased &&
            challenge.startDate != null &&
            challenge.endDate != null)
          _buildDurationText(
            '${_formatDate(challenge.startDate!)} ~ '
                '${_formatDate(challenge.endDate!)}',
            screenWidth,
            icon:
            Icons.date_range_outlined,
          ),

        if (hasStageDurations)
          _buildDurationText(
            '${challenge.stageDurations[currentStageIndex]}일',
            screenWidth,
            title:
            '${currentStageIndex + 1}단계 도전 기간',
            icon:
            Icons.show_chart_rounded,
          ),

        if (!hasStageDurations &&
            hasDurationOptions &&
            challenge.durationOptions!.length >
                1)
          _buildDurationSelection(
            challenge.durationOptions!,
            screenWidth,
            unit: '일',
          )
        else if (!hasStageDurations &&
            hasDurationOptions)
          _buildDurationText(
            '${challenge.durationOptions!.first}일',
            screenWidth,
            icon:
            Icons.schedule_rounded,
          )
        else if (!hasStageDurations &&
              hasCheckCountOptions &&
              challenge.checkCountOptions!.length >
                  1)
            _buildDurationSelection(
              challenge.checkCountOptions!,
              screenWidth,
              unit: '회',
            )
          else if (!hasStageDurations &&
                hasCheckCountOptions)
              _buildDurationText(
                '${challenge.checkCountOptions!.first}회',
                screenWidth,
                title: '목표 횟수',
                icon:
                Icons.check_circle_outline_rounded,
              ),

        if (challenge.period ==
            ChallengePeriod.infinite)
          _buildDurationText(
            '책을 모두 읽을 때까지 자유롭게 진행하세요.',
            screenWidth,
            title: '도전 기간',
            icon:
            Icons.all_inclusive_rounded,
          ),

        if (needsStartDate) ...[
          SizedBox(
            height:
            screenWidth * 0.035,
          ),

          if (isDaily10MinHabit)
            _buildDurationText(
              _formatDate(
                selectedStartDate ??
                    DateTime.now(),
              ),
              screenWidth,
              title:
              '도전 시작일',
              icon:
              Icons.calendar_today_outlined,
            )
          else
            _buildStartDateSelection(
              screenWidth,
            ),
        ],
      ],
    );
  }

  Widget _buildInvitationOptions(
      Challenge challenge,
      double screenWidth,
      ) {
    final invitation =
    widget.invitation!;

    final children =
    <Widget>[];

    // 시작일
    children.add(
      _buildDurationText(
        _formatDate(
          invitation.startDate,
        ),
        screenWidth,
        title:
        '도전 시작일',
        icon:
        Icons.calendar_today_outlined,
      ),
    );

    // 기간 / 횟수
    if (invitation.selectedDuration !=
        null) {
      children.add(
        SizedBox(
          height:
          screenWidth * 0.035,
        ),
      );

      final isCountTarget =
          challenge.stageType !=
              ChallengeStageType.staged &&
              challenge.checkCountOptions
                  ?.isNotEmpty ==
                  true &&
              challenge.durationOptions
                  ?.isNotEmpty !=
                  true;

      children.add(
        _buildDurationText(
          isCountTarget
              ? '${invitation.selectedDuration}회'
              : '${invitation.selectedDuration}일',
          screenWidth,
          title:
          isCountTarget
              ? '목표 횟수'
              : challenge.stageType ==
              ChallengeStageType.staged
              ? '${(invitation.stageIndex ?? 0) + 1}단계 도전 기간'
              : '도전 기간',
          icon:
          isCountTarget
              ? Icons
              .check_circle_outline_rounded
              : Icons
              .schedule_rounded,
        ),
      );
    }

    // 종료일이 실제로 존재하는 챌린지
    if (invitation.endDate != null) {
      children.add(
        SizedBox(
          height:
          screenWidth * 0.035,
        ),
      );

      children.add(
        _buildDurationText(
          _formatDate(
            invitation.endDate!,
          ),
          screenWidth,
          title:
          '도전 종료일',
          icon:
          Icons.event_available_outlined,
        ),
      );
    }

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children:
      children,
    );
  }

  String _formatDate(DateTime date) {
    return "${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}";
  }

  Widget _buildDurationText(
      String text,
      double screenWidth, {
        String title = '도전 기간',
        IconData icon =
            Icons.calendar_today_outlined,
      }) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(
          title,
          screenWidth,
        ),

        SizedBox(
          height:
          screenWidth * 0.018,
        ),

        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal:
            screenWidth * 0.035,
            vertical:
            screenWidth * 0.032,
          ),
          decoration: BoxDecoration(
            color:
            Colors.white.withOpacity(0.04),
            borderRadius:
            BorderRadius.circular(14),
            border: Border.all(
              color:
              Colors.white.withOpacity(0.07),
            ),
          ),
          child: Row(
            children: [
              Container(
                width:
                screenWidth * 0.08,
                height:
                screenWidth * 0.08,
                decoration: BoxDecoration(
                  color: Colors.amberAccent
                      .withOpacity(0.09),
                  borderRadius:
                  BorderRadius.circular(9),
                ),
                child: Icon(
                  icon,
                  color:
                  Colors.amberAccent,
                  size:
                  screenWidth * 0.04,
                ),
              ),

              SizedBox(
                width:
                screenWidth * 0.025,
              ),

              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color:
                    Colors.white,
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth * 0.032,
                    fontWeight:
                    FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(
      String title,
      double screenWidth, {
        String? trailing,
      }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color:
              Colors.white.withOpacity(0.72),
              fontFamily: 'kopub',
              fontSize:
              screenWidth * 0.03,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ),

        if (trailing != null)
          Text(
            trailing,
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
    );
  }

  Widget _buildDurationSelection(
      List<int> options,
      double screenWidth, {
        String unit = '일',
      }) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(
          unit == '회'
              ? '목표 횟수'
              : '도전 기간',
          screenWidth,
        ),

        SizedBox(
          height:
          screenWidth * 0.02,
        ),

        Wrap(
          spacing:
          screenWidth * 0.02,
          runSpacing:
          screenWidth * 0.02,
          children: options.map(
                (value) {
              final isSelected =
                  selectedDuration == value;

              return InkWell(
                borderRadius:
                BorderRadius.circular(12),
                onTap: () {
                  setState(() {
                    selectedDuration = value;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 150,
                  ),
                  padding:
                  EdgeInsets.symmetric(
                    horizontal:
                    screenWidth * 0.04,
                    vertical:
                    screenWidth * 0.025,
                  ),
                  decoration:
                  BoxDecoration(
                    color: isSelected
                        ? Colors.amberAccent
                        .withOpacity(0.11)
                        : Colors.white
                        .withOpacity(0.035),
                    borderRadius:
                    BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Colors.amberAccent
                          .withOpacity(0.5)
                          : Colors.white
                          .withOpacity(0.07),
                    ),
                  ),
                  child: Row(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        Icon(
                          Icons.check_rounded,
                          color:
                          Colors.amberAccent,
                          size:
                          screenWidth * 0.035,
                        ),

                        SizedBox(
                          width:
                          screenWidth * 0.012,
                        ),
                      ],

                      Text(
                        '$value$unit',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.amberAccent
                              : Colors.white70,
                          fontFamily:
                          'kopub',
                          fontSize:
                          screenWidth * 0.03,
                          fontWeight:
                          isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ).toList(),
        ),
      ],
    );
  }

  Widget _buildStartDateSelection(
      double screenWidth,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(
          '도전 시작일',
          screenWidth,
        ),

        SizedBox(
          height:
          screenWidth * 0.018,
        ),

        InkWell(
          borderRadius:
          BorderRadius.circular(14),
          onTap: () async {
            final now =
            DateTime.now();

            final today =
            DateTime(
              now.year,
              now.month,
              now.day,
            );

            DateTime effectiveMinDate =
                today;

            DateTime? disabledDate;

            // ⚠️ 기존 스테이지 날짜 제한 로직 그대로
            if (!kAllowSameDayStageAdvanceForDebug &&
                widget.challenge.stageType ==
                    ChallengeStageType.staged &&
                widget.challenge.attempts
                    .isNotEmpty) {
              final prev =
                  widget.challenge.attempts.last;

              final prevEndDate =
              prev.endDate?.toLocal();

              if (prevEndDate != null) {
                final localPrev =
                DateTime(
                  prevEndDate.year,
                  prevEndDate.month,
                  prevEndDate.day,
                );

                disabledDate =
                    localPrev;

                effectiveMinDate =
                    localPrev.add(
                      const Duration(days: 1),
                    );
              }
            }

            await showCalendarDialog(
              context: context,
              selectedDate:
              selectedStartDate != null &&
                  selectedStartDate!
                      .isAfter(
                    effectiveMinDate.subtract(
                      const Duration(
                        days: 1,
                      ),
                    ),
                  )
                  ? selectedStartDate!
                  : effectiveMinDate,
              minDate:
              effectiveMinDate,
              maxDate:
              today.add(
                const Duration(
                  days: 365,
                ),
              ),
              onDatePicked: (picked) {
                setState(() {
                  selectedStartDate =
                      picked;
                });
              },
              isStartDate: true,
              disabledDates:
              disabledDate != null
                  ? [disabledDate]
                  : [],
            );
          },
          child: Container(
            width: double.infinity,
            padding:
            EdgeInsets.symmetric(
              horizontal:
              screenWidth * 0.035,
              vertical:
              screenWidth * 0.032,
            ),
            decoration:
            BoxDecoration(
              color: Colors.white
                  .withOpacity(0.04),
              borderRadius:
              BorderRadius.circular(14),
              border: Border.all(
                color: selectedStartDate !=
                    null
                    ? Colors.amberAccent
                    .withOpacity(0.25)
                    : Colors.white
                    .withOpacity(0.07),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width:
                  screenWidth * 0.08,
                  height:
                  screenWidth * 0.08,
                  decoration:
                  BoxDecoration(
                    color: Colors.amberAccent
                        .withOpacity(0.09),
                    borderRadius:
                    BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons
                        .calendar_today_outlined,
                    color:
                    Colors.amberAccent,
                    size:
                    screenWidth * 0.038,
                  ),
                ),

                SizedBox(
                  width:
                  screenWidth * 0.025,
                ),

                Expanded(
                  child: Text(
                    selectedStartDate != null
                        ? _formatDate(
                      selectedStartDate!,
                    )
                        : '시작일을 선택해주세요',
                    style:
                    TextStyle(
                      color: selectedStartDate !=
                          null
                          ? Colors.white
                          : Colors.white38,
                      fontFamily:
                      'kopub',
                      fontSize:
                      screenWidth * 0.031,
                      fontWeight:
                      selectedStartDate !=
                          null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),

                Icon(
                  Icons.chevron_right_rounded,
                  color:
                  Colors.white38,
                  size:
                  screenWidth * 0.05,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookSection(
      double screenWidth,
      ) {
    final challenge =
        widget.challenge;

    // =========================================================
    // 사용자 지정 도서
    // =========================================================

    if (allowsUserBookSelection) {
      // =====================================================
      // 친구 초대 참여
      // 초대한 사람이 선택한 책 그대로 표시
      // =====================================================

      if (isInvitationMode) {
        return Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            _buildSectionLabel(
              '읽을 책',
              screenWidth,
              trailing:
              selectedBooks.isNotEmpty
                  ? '${selectedBooks.length}권'
                  : null,
            ),

            SizedBox(
              height:
              screenWidth * 0.02,
            ),

            if (selectedBooks.isNotEmpty)
              ...selectedBooks.map(
                    (book) => Padding(
                  padding: EdgeInsets.only(
                    bottom:
                    screenWidth * 0.02,
                  ),
                  child: _bookRow(
                    book,
                    screenWidth,
                  ),
                ),
              )
            else
              Container(
                width:
                double.infinity,
                padding:
                EdgeInsets.all(
                  screenWidth * 0.035,
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
                child: Text(
                  '도서 정보를 불러올 수 없어요.',
                  style: TextStyle(
                    color:
                    Colors.white54,
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth * 0.028,
                  ),
                ),
              ),
          ],
        );
      }

      // =====================================================
      // 일반 참여
      // 사용자가 직접 책 선택
      // =====================================================

      return Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(
            '읽을 책',
            screenWidth,
          ),

          SizedBox(
            height:
            screenWidth * 0.02,
          ),

          ChallegeBookSelectionBox(
            initialSelectedBook:
            selectedBooks.isNotEmpty
                ? selectedBooks.first
                : null,
            onBookChanged: (book) {
              setState(() {
                selectedBooks =
                book != null
                    ? [book]
                    : [];
              });
            },
          ),
        ],
      );
    }

    // =========================================================
    // 시스템 지정 도서
    // =========================================================

    if (challenge.method ==
        ChallengeMethod.specificBooks &&
        challenge.specificBookMode ==
            SpecificBookMode.systemDefined) {
      final books =
      _effectiveSystemBooks();

      return Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(
            '읽을 책',
            screenWidth,
            trailing: !_isLoadingBooks &&
                books.isNotEmpty
                ? '${books.length}권'
                : null,
          ),

          SizedBox(
            height:
            screenWidth * 0.02,
          ),

          if (_isLoadingBooks)
            Padding(
              padding:
              EdgeInsets.symmetric(
                vertical:
                screenWidth * 0.05,
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
            )
          else if (books.isNotEmpty)
            ...books.map(
                  (book) => Padding(
                padding: EdgeInsets.only(
                  bottom:
                  screenWidth * 0.02,
                ),
                child: _bookRow(
                  book,
                  screenWidth,
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(
                screenWidth * 0.035,
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
                    screenWidth * 0.02,
                  ),

                  Expanded(
                    child: Text(
                      '도서 정보를 불러올 수 없어요.',
                      style:
                      TextStyle(
                        color:
                        Colors.white54,
                        fontFamily:
                        'kopub',
                        fontSize:
                        screenWidth * 0.028,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  // detailedRequiredBooks가 비면 구버전 requiredBooks라도 돌려주기
  List<BookModel> _effectiveSystemBooks() {
    if (detailedRequiredBooks.isNotEmpty) return detailedRequiredBooks;
    // 풀 로딩 전이라면 표시할 게 없을 수 있음 → 기존 requiredBooks로 폴백
    return widget.challenge.requiredBooks ?? const [];
  }

  Widget _bookRow(
      BookModel book,
      double screenWidth,
      ) {
    final imageWidth =
        screenWidth * 0.13;

    final imageHeight =
        imageWidth * 1.42;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        screenWidth * 0.025,
      ),
      decoration: BoxDecoration(
        color:
        Colors.white.withOpacity(0.035),
        borderRadius:
        BorderRadius.circular(12),
        border: Border.all(
          color:
          Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius:
              BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withOpacity(0.18),
                  blurRadius: 6,
                  offset:
                  const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius:
              BorderRadius.circular(7),
              child: _buildBookCover(
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
                    screenWidth * 0.03,
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
                    screenWidth * 0.006,
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
                      screenWidth * 0.026,
                    ),
                  ),
                ],

                if (book.pageCount > 0) ...[
                  SizedBox(
                    height:
                    screenWidth * 0.014,
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
                      screenWidth * 0.025,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookCover(
      String? url,
      double width,
      double height,
      ) {
    if (url == null ||
        url.isEmpty) {
      return _buildBookCoverFallback(
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
            (_, __, ___) =>
            _buildBookCoverFallback(
              width,
              height,
            ),
      );
    }

    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) =>
            _buildBookCoverFallback(
              width,
              height,
            ),
      );
    }

    return _buildBookCoverFallback(
      width,
      height,
    );
  }

  Widget _buildBookCoverFallback(
      double width,
      double height,
      ) {
    return Container(
      width: width,
      height: height,
      color:
      Colors.white.withOpacity(0.055),
      alignment:
      Alignment.center,
      child: const Icon(
        Icons.book_rounded,
        color:
        Colors.white38,
      ),
    );
  }

  Widget _buildJoinButton(
      double screenWidth,
      ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed:
        _isJoining
            ? null
            : _handleJoin,
        style: ElevatedButton.styleFrom(
          backgroundColor:
          Colors.amberAccent,
          disabledBackgroundColor:
          Colors.amberAccent.withOpacity(
            0.45,
          ),
          foregroundColor:
          const Color(0xFF013328),
          elevation: 0,
          padding: EdgeInsets.symmetric(
            vertical:
            screenWidth * 0.038,
          ),
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(14),
          ),
        ),
        child: _isJoining
            ? SizedBox(
          width:
          screenWidth * 0.05,
          height:
          screenWidth * 0.05,
          child:
          const CircularProgressIndicator(
            strokeWidth: 2.2,
            color:
            Color(0xFF013328),
          ),
        )
            : Row(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Text(
              '도전 시작하기',
              style: TextStyle(
                fontFamily:
                'kopub',
                fontSize:
                screenWidth * 0.034,
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }



}
