import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/screen/challenge_done_screen.dart';
import 'package:dayverse_book/screen/challenge_screen.dart';
import 'package:dayverse_book/widget/card_box.dart';
import 'package:dayverse_book/screen/share_chart_challenge_done_screen.dart';
import 'package:dayverse_book/widget/recurring_challenge_cover.dart';

class ChartChallengeDoneScreen
    extends StatelessWidget {
  const ChartChallengeDoneScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final size =
        MediaQuery.of(context).size;

    final screenWidth =
        size.width;

    final screenHeight =
        size.height;

    final challengeProvider =
    context.watch<ChallengeProvider>();

    final completedChallenges =
        challengeProvider.completedChallenges;

    final totalCompletedCount =
        completedChallenges.length;

    final totalSuccessfulAttempts =
    _getTotalSuccessfulAttempts(
      completedChallenges,
    );

    final repeatedChallengeCount =
    _getRepeatedChallengeCount(
      completedChallenges,
    );

    return Scaffold(
      backgroundColor:
      const Color(0xFF013328),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,

        title: Text(
          '달성한 챌린지',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'kopub',
            fontSize: screenWidth * 0.045,
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          if (completedChallenges.isNotEmpty)
            IconButton(
              tooltip: '공유하기',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ShareChartChallengeDoneScreen(
                          challenges: completedChallenges,
                        ),
                  ),
                );
              },
              icon: Icon(
                Icons.ios_share_rounded,
                color: Colors.white,
                size: screenWidth * 0.055,
              ),
            ),

          SizedBox(
            width: screenWidth * 0.01,
          ),
        ],
      ),

      body: completedChallenges.isEmpty
          ? _buildEmptyState(
        screenWidth,
        screenHeight,
      )
          : SingleChildScrollView(
        physics:
        const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          screenWidth * 0.05,
          screenHeight * 0.015,
          screenWidth * 0.05,
          screenHeight * 0.08,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            /// HERO
            _buildAchievementHero(
              completedCount:
              totalCompletedCount,
              screenWidth:
              screenWidth,
            ),

            SizedBox(
              height:
              screenHeight * 0.018,
            ),

            /// 요약 통계
            _buildAchievementSummary(
              completedCount:
              totalCompletedCount,
              successfulAttempts:
              totalSuccessfulAttempts,
              repeatedChallengeCount:
              repeatedChallengeCount,
              screenWidth:
              screenWidth,
            ),

            SizedBox(
              height:
              screenHeight * 0.035,
            ),

            /// 컬렉션
            _buildSectionTitle(
              screenWidth,
              'CHALLENGE COLLECTION',
            ),

            SizedBox(
              height:
              screenHeight * 0.015,
            ),

            _buildChallengeCollection(
              context: context,
              challenges:
              completedChallenges,
              screenWidth:
              screenWidth,
            ),

            SizedBox(
              height:
              screenHeight * 0.04,
            ),

            /// 전체 완료 목록
            _buildSectionTitle(
              screenWidth,
              '완료한 챌린지',
            ),

            SizedBox(
              height:
              screenHeight * 0.015,
            ),

            ...completedChallenges.map(
                  (challenge) {
                return ChallengeCard(
                  challenge:
                  challenge,
                  showAttemptsBadge:
                  true,
                  stageChipDisplayMode:
                  StageChipDisplayMode
                      .completed,
                  onTap: () {
                    _openChallenge(
                      context,
                      challenge,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // HERO
  // =========================================================

  Widget _buildAchievementHero({
    required int completedCount,
    required double screenWidth,
  }) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal:
          screenWidth * 0.05,
          vertical:
          screenWidth * 0.065,
        ),
        decoration: BoxDecoration(
          borderRadius:
          BorderRadius.circular(16),
          gradient: LinearGradient(
            begin:
            Alignment.topLeft,
            end:
            Alignment.bottomRight,
            colors: [
              Colors.amberAccent
                  .withOpacity(0.10),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          children: [
            Container(
              width:
              screenWidth * 0.19,
              height:
              screenWidth * 0.19,
              decoration: BoxDecoration(
                color: Colors.amberAccent
                    .withOpacity(0.12),
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
                    .emoji_events_rounded,
                color:
                Colors.amberAccent,
                size:
                screenWidth * 0.095,
              ),
            ),

            SizedBox(
              height:
              screenWidth * 0.035,
            ),

            Text(
              '$completedCount',
              style: TextStyle(
                color:
                Colors.amberAccent,
                fontFamily: 'kopub',
                fontSize:
                screenWidth * 0.11,
                fontWeight:
                FontWeight.bold,
                height: 1,
              ),
            ),

            SizedBox(
              height:
              screenWidth * 0.015,
            ),

            Text(
              'CHALLENGES COMPLETED',
              style: TextStyle(
                color: Colors.white
                    .withOpacity(0.55),
                fontFamily: 'kopub',
                fontSize:
                screenWidth * 0.025,
                fontWeight:
                FontWeight.w600,
                letterSpacing: 2,
              ),
            ),

            SizedBox(
              height:
              screenWidth * 0.035,
            ),

            Text(
              _getAchievementMessage(
                completedCount,
              ),
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color: Colors.white
                    .withOpacity(0.8),
                fontFamily: 'kopub',
                fontSize:
                screenWidth * 0.033,
                fontWeight:
                FontWeight.w500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getAchievementMessage(
      int count,
      ) {
    if (count >= 50) {
      return '꾸준한 도전이 당신만의 기록이 되었어요.';
    }

    if (count >= 20) {
      return '수많은 도전을 끝까지 완주했어요.';
    }

    if (count >= 10) {
      return '하나씩 쌓아온 도전이 멋진 성취가 되었어요.';
    }

    if (count >= 5) {
      return '꾸준히 도전하며 성취를 쌓아가고 있어요.';
    }

    return '첫 성취부터 하나씩 기록을 만들어가고 있어요.';
  }

  // =========================================================
  // SUMMARY
  // =========================================================

  Widget _buildAchievementSummary({
    required int completedCount,
    required int successfulAttempts,
    required int repeatedChallengeCount,
    required double screenWidth,
  }) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(
        vertical:
        screenWidth * 0.04,
      ),
      child: Row(
        children: [
          Expanded(
            child:
            _buildSummaryItem(
              value:
              '$completedCount',
              label:
              '총 달성',
              screenWidth:
              screenWidth,
            ),
          ),

          _buildVerticalDivider(
            screenWidth,
          ),

          Expanded(
            child:
            _buildSummaryItem(
              value:
              '$successfulAttempts',
              label:
              '총 완주',
              screenWidth:
              screenWidth,
            ),
          ),

          _buildVerticalDivider(
            screenWidth,
          ),

          Expanded(
            child:
            _buildSummaryItem(
              value:
              '$repeatedChallengeCount',
              label:
              '반복 달성',
              screenWidth:
              screenWidth,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String value,
    required String label,
    required double screenWidth,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color:
            Colors.amberAccent,
            fontFamily:
            'kopub',
            fontSize:
            screenWidth * 0.046,
            fontWeight:
            FontWeight.bold,
          ),
        ),

        SizedBox(
          height:
          screenWidth * 0.01,
        ),

        Text(
          label,
          style: TextStyle(
            color:
            Colors.white54,
            fontFamily:
            'kopub',
            fontSize:
            screenWidth * 0.028,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider(
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
  // CHALLENGE COLLECTION
  // =========================================================

  Widget _buildChallengeCollection({
    required BuildContext context,
    required List<Challenge> challenges,
    required double screenWidth,
  }) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(
        screenWidth * 0.035,
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics:
        const NeverScrollableScrollPhysics(),
        itemCount:
        challenges.length,
        gridDelegate:
        const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 18,
          childAspectRatio: 0.80,
        ),
        itemBuilder: (
            context,
            index,
            ) {
          final challenge =
          challenges[index];

          return _buildCollectionItem(
            context: context,
            challenge:
            challenge,
            screenWidth:
            screenWidth,
          );
        },
      ),
    );
  }

  Widget _buildCollectionItem({
    required BuildContext context,
    required Challenge challenge,
    required double screenWidth,
  }) {
    final successfulCount =
        challenge.attempts
            .where(
              (attempt) =>
          attempt.completed &&
              attempt.isSuccessful,
        )
            .length;

    return InkWell(
      borderRadius:
      BorderRadius.circular(12),
      onTap: () {
        _openChallenge(
          context,
          challenge,
        );
      },
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _buildCollectionImage(
                    challenge,
                  ),
                ),

                Positioned.fill(
                  child: Container(
                    decoration:
                    BoxDecoration(
                      borderRadius:
                      BorderRadius
                          .circular(
                        12,
                      ),
                      color: Colors.black
                          .withOpacity(
                        0.16,
                      ),
                    ),
                  ),
                ),

                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width:
                    screenWidth *
                        0.065,
                    height:
                    screenWidth *
                        0.065,
                    decoration:
                    BoxDecoration(
                      color: const Color(
                        0xFF013328,
                      ).withOpacity(
                        0.9,
                      ),
                      shape:
                      BoxShape.circle,
                      border:
                      Border.all(
                        color: Colors
                            .amberAccent
                            .withOpacity(
                          0.65,
                        ),
                      ),
                    ),
                    child: Icon(
                      Icons
                          .check_rounded,
                      color: Colors
                          .amberAccent,
                      size:
                      screenWidth *
                          0.038,
                    ),
                  ),
                ),

                if (successfulCount >
                    1)
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child:
                    Container(
                      padding:
                      EdgeInsets
                          .symmetric(
                        horizontal:
                        screenWidth *
                            0.018,
                        vertical:
                        screenWidth *
                            0.008,
                      ),
                      decoration:
                      BoxDecoration(
                        color:
                        Colors.black
                            .withOpacity(
                          0.55,
                        ),
                        borderRadius:
                        BorderRadius
                            .circular(
                          20,
                        ),
                      ),
                      child: Text(
                        '${successfulCount}회',
                        style:
                        TextStyle(
                          color: Colors
                              .amberAccent,
                          fontFamily:
                          'kopub',
                          fontSize:
                          screenWidth *
                              0.023,
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

          SizedBox(
            height:
            screenWidth * 0.018,
          ),

          Text(
            challenge.title,
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
            textAlign:
            TextAlign.center,
            style: TextStyle(
              color:
              Colors.white70,
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
    );
  }


  Widget _buildCollectionImage(
      Challenge challenge,
      ) {
    // ✅ 정기 챌린지 Flutter 자동 커버
    if (RecurringChallengeCover.supports(challenge)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: RecurringChallengeCover(
          challenge: challenge,
        ),
      );
    }

    final url = challenge.imageUrl.trim();

    if (url.isEmpty) {
      return _buildCollectionFallback();
    }

    // ✅ 네트워크 이미지
    if (url.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _buildCollectionFallback(),
        ),
      );
    }

    // ✅ 에셋 이미지
    if (url.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _buildCollectionFallback(),
        ),
      );
    }

    // ✅ 로컬 파일 이미지
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(url),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _buildCollectionFallback(),
      ),
    );
  }

  Widget _buildCollectionFallback() {
    return Container(
      decoration: BoxDecoration(
        color:
        Colors.white.withOpacity(
          0.055,
        ),
        borderRadius:
        BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(
          Icons
              .emoji_events_outlined,
          color:
          Colors.white38,
        ),
      ),
    );
  }

  // =========================================================
  // COMMON
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

  int _getTotalSuccessfulAttempts(
      List<Challenge> challenges,
      ) {
    int total = 0;

    for (final challenge
    in challenges) {
      total += challenge.attempts
          .where(
            (attempt) =>
        attempt.completed &&
            attempt.isSuccessful,
      )
          .length;
    }

    return total;
  }

  int _getRepeatedChallengeCount(
      List<Challenge> challenges,
      ) {
    return challenges.where(
          (challenge) {
        final successfulCount =
            challenge.attempts
                .where(
                  (attempt) =>
              attempt.completed &&
                  attempt
                      .isSuccessful,
            )
                .length;

        return successfulCount > 1;
      },
    ).length;
  }

  void _openChallenge(
      BuildContext context,
      Challenge challenge,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChallengeDoneScreen(
              challenge:
              challenge,
            ),
      ),
    );
  }

  // =========================================================
  // EMPTY
  // =========================================================

  Widget _buildEmptyState(
      double screenWidth,
      double screenHeight,
      ) {
    return Center(
      child: Padding(
        padding:
        EdgeInsets.symmetric(
          horizontal:
          screenWidth * 0.08,
        ),
        child: CardBox(
          margin:
          EdgeInsets.zero,
          padding:
          EdgeInsets.symmetric(
            horizontal:
            screenWidth * 0.055,
            vertical:
            screenWidth * 0.065,
          ),
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              Container(
                width:
                screenWidth * 0.18,
                height:
                screenWidth * 0.18,
                decoration:
                BoxDecoration(
                  color: Colors
                      .amberAccent
                      .withOpacity(
                    0.1,
                  ),
                  shape:
                  BoxShape.circle,
                  border:
                  Border.all(
                    color: Colors
                        .amberAccent
                        .withOpacity(
                      0.25,
                    ),
                  ),
                ),
                child: Icon(
                  Icons
                      .emoji_events_outlined,
                  color: Colors
                      .amberAccent,
                  size:
                  screenWidth *
                      0.085,
                ),
              ),

              SizedBox(
                height:
                screenHeight *
                    0.022,
              ),

              Text(
                '아직 달성한 챌린지가 없어요',
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
                      0.038,
                  fontWeight:
                  FontWeight
                      .bold,
                ),
              ),

              SizedBox(
                height:
                screenHeight *
                    0.009,
              ),

              Text(
                '챌린지에 도전하고\n첫 번째 성취를 만들어보세요.',
                textAlign:
                TextAlign.center,
                style:
                TextStyle(
                  color: Colors
                      .white
                      .withOpacity(
                    0.5,
                  ),
                  fontFamily:
                  'kopub',
                  fontSize:
                  screenWidth *
                      0.03,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
