import 'package:flutter/material.dart';

import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/challenge_attempt_model.dart';
import 'package:dayverse_book/widget/card_box.dart';

class StageInfoCard extends StatelessWidget {
  final Challenge challenge;

  const StageInfoCard({
    super.key,
    required this.challenge,
  });

  @override
  Widget build(BuildContext context) {
    if (challenge.stageType != ChallengeStageType.staged ||
        challenge.stageDurations.isEmpty ||
        challenge.attempts.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenWidth =
        MediaQuery.of(context).size.width;

    final displayAttempt =
    _getDisplayAttempt(challenge);

    final rawStageIndex =
        displayAttempt.stageIndex ?? 0;

    final clampedIndex =
    rawStageIndex.clamp(
      0,
      challenge.stageDurations.length - 1,
    );

    final currentDuration =
    challenge.stageDurations[clampedIndex];

    final totalStages =
        challenge.stageDurations.length;

    final statusText =
    _getStatusText(
      challenge,
      displayAttempt,
    );

    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(
        screenWidth * 0.04,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          // =====================================================
          // 상단 정보
          // =====================================================

          Row(
            children: [
              Container(
                width:
                screenWidth * 0.09,
                height:
                screenWidth * 0.09,
                decoration: BoxDecoration(
                  color: Colors.amberAccent
                      .withOpacity(0.10),
                  borderRadius:
                  BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.show_chart_rounded,
                  color:
                  Colors.amberAccent,
                  size:
                  screenWidth * 0.046,
                ),
              ),

              SizedBox(
                width:
                screenWidth * 0.025,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      '현재 스테이지',
                      style: TextStyle(
                        color:
                        Colors.white38,
                        fontFamily:
                        'kopub',
                        fontSize:
                        screenWidth * 0.027,
                      ),
                    ),

                    SizedBox(
                      height:
                      screenWidth * 0.006,
                    ),

                    Text(
                      '${clampedIndex + 1} / '
                          '$totalStages 스테이지',
                      style: TextStyle(
                        color:
                        Colors.white,
                        fontFamily:
                        'kopub',
                        fontSize:
                        screenWidth * 0.035,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              _buildStatusBadge(
                statusText,
                screenWidth,
              ),
            ],
          ),

          SizedBox(
            height:
            screenWidth * 0.018,
          ),

          Padding(
            padding: EdgeInsets.only(
              left:
              screenWidth * 0.115,
            ),
          ),

          SizedBox(
            height:
            screenWidth * 0.045,
          ),

          // =====================================================
          // STEPPER
          // =====================================================

          _buildStageStepper(
            currentStageIndex:
            clampedIndex,
            displayAttempt:
            displayAttempt,
            screenWidth:
            screenWidth,
          ),
        ],
      ),
    );
  }

  // =========================================================
  // STEPPER
  // =========================================================

  Widget _buildStageStepper({
    required int currentStageIndex,
    required ChallengeAttempt displayAttempt,
    required double screenWidth,
  }) {
    final totalStages =
        challenge.stageDurations.length;

    return Column(
      children: [
        // 원 + 연결선
        Row(
          children: [
            for (int i = 0;
            i < totalStages;
            i++) ...[
              _buildStageNode(
                stageIndex: i,
                currentStageIndex:
                currentStageIndex,
                displayAttempt:
                displayAttempt,
                screenWidth:
                screenWidth,
              ),

              if (i <
                  totalStages - 1)
                Expanded(
                  child:
                  _buildStageConnector(
                    stageIndex: i,
                    currentStageIndex:
                    currentStageIndex,
                    screenWidth:
                    screenWidth,
                  ),
                ),
            ],
          ],
        ),

        SizedBox(
          height:
          screenWidth * 0.018,
        ),

        // 단계명 + 기간
        Row(
          children: List.generate(
            totalStages,
                (index) {
              final isCurrent =
                  index ==
                      currentStageIndex;

              final isCompleted =
              _isStageCompleted(
                index,
              );

              return Expanded(
                child: Column(
                  children: [
                    Text(
                      '${index + 1}단계',
                      style: TextStyle(
                        color: isCurrent
                            ? Colors
                            .amberAccent
                            : isCompleted
                            ? Colors.white70
                            : Colors.white30,
                        fontFamily:
                        'kopub',
                        fontSize:
                        screenWidth *
                            0.025,
                        fontWeight:
                        isCurrent
                            ? FontWeight
                            .bold
                            : FontWeight
                            .normal,
                      ),
                    ),

                    SizedBox(
                      height:
                      screenWidth *
                          0.006,
                    ),

                    Text(
                      '${challenge.stageDurations[index]}일',
                      style: TextStyle(
                        color: isCurrent
                            ? Colors.white60
                            : Colors.white30,
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
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStageNode({
    required int stageIndex,
    required int currentStageIndex,
    required ChallengeAttempt displayAttempt,
    required double screenWidth,
  }) {
    final isCompleted =
    _isStageCompleted(
      stageIndex,
    );

    final isCurrent =
        stageIndex ==
            currentStageIndex &&
            challenge.isJoined &&
            !displayAttempt.completed;

    final nodeSize =
        screenWidth * 0.075;

    if (isCompleted) {
      return Container(
        width: nodeSize,
        height: nodeSize,
        decoration: const BoxDecoration(
          color:
          Colors.amberAccent,
          shape:
          BoxShape.circle,
        ),
        child: Icon(
          Icons.check_rounded,
          color:
          const Color(0xFF013328),
          size:
          screenWidth * 0.045,
        ),
      );
    }

    if (isCurrent) {
      return Container(
        width: nodeSize,
        height: nodeSize,
        decoration: BoxDecoration(
          color: Colors.amberAccent
              .withOpacity(0.10),
          shape:
          BoxShape.circle,
          border: Border.all(
            color:
            Colors.amberAccent,
            width: 1.5,
          ),
        ),
        alignment:
        Alignment.center,
        child: Text(
          '${stageIndex + 1}',
          style: TextStyle(
            color:
            Colors.amberAccent,
            fontFamily:
            'kopub',
            fontSize:
            screenWidth * 0.028,
            fontWeight:
            FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      width: nodeSize,
      height: nodeSize,
      decoration: BoxDecoration(
        color: Colors.white
            .withOpacity(0.04),
        shape:
        BoxShape.circle,
        border: Border.all(
          color: Colors.white
              .withOpacity(0.12),
        ),
      ),
      alignment:
      Alignment.center,
      child: Text(
        '${stageIndex + 1}',
        style: TextStyle(
          color:
          Colors.white38,
          fontFamily:
          'kopub',
          fontSize:
          screenWidth * 0.028,
          fontWeight:
          FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStageConnector({
    required int stageIndex,
    required int currentStageIndex,
    required double screenWidth,
  }) {
    final isPassed =
    _isStageCompleted(
      stageIndex,
    );

    return Container(
      height: 2,
      margin: EdgeInsets.symmetric(
        horizontal:
        screenWidth * 0.012,
      ),
      decoration: BoxDecoration(
        color: isPassed
            ? Colors.amberAccent
            .withOpacity(0.65)
            : Colors.white
            .withOpacity(0.10),
        borderRadius:
        BorderRadius.circular(20),
      ),
    );
  }

  bool _isStageCompleted(
      int stageIndex,
      ) {
    for (final attempt
    in challenge.attempts) {
      if (attempt.stageIndex ==
          stageIndex &&
          attempt.completed == true &&
          attempt.isSuccessful ==
              true) {
        return true;
      }
    }

    return false;
  }

  // =========================================================
  // STATUS
  // =========================================================

  Widget _buildStatusBadge(
      String statusText,
      double screenWidth,
      ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal:
        screenWidth * 0.022,
        vertical:
        screenWidth * 0.01,
      ),
      decoration: BoxDecoration(
        color: Colors.amberAccent
            .withOpacity(0.10),
        borderRadius:
        BorderRadius.circular(30),
        border: Border.all(
          color: Colors.amberAccent
              .withOpacity(0.25),
        ),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color:
          Colors.amberAccent,
          fontFamily:
          'kopub',
          fontSize:
          screenWidth * 0.025,
          fontWeight:
          FontWeight.bold,
        ),
      ),
    );
  }

  String _getStatusText(
      Challenge challenge,
      ChallengeAttempt attempt,
      ) {
    if (challenge.isCompleted) {
      return '최종 완료';
    }

    if (challenge.isJoined &&
        !attempt.completed) {
      return '진행 중';
    }

    if (!challenge.isJoined &&
        attempt.completed) {
      return '완료';
    }

    return '대기 중';
  }

  // =========================================================
  // ATTEMPT
  // =========================================================

  ChallengeAttempt _getDisplayAttempt(
      Challenge challenge,
      ) {
    if (challenge.isJoined) {
      for (int i =
          challenge.attempts.length - 1;
      i >= 0;
      i--) {
        final attempt =
        challenge.attempts[i];

        if (!attempt.completed) {
          return attempt;
        }
      }
    }

    for (int i =
        challenge.attempts.length - 1;
    i >= 0;
    i--) {
      final attempt =
      challenge.attempts[i];

      if (attempt.completed) {
        return attempt;
      }
    }

    return challenge.attempts.last;
  }

}