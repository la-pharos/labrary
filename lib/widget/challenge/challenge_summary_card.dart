import 'package:flutter/material.dart';

import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/challenge_attempt_model.dart';
import 'package:dayverse_book/utils/challenge_check_utils.dart';
import 'package:dayverse_book/widget/card_box.dart';

class SummaryCard extends StatelessWidget {
  final Challenge challenge;

  const SummaryCard({
    super.key,
    required this.challenge,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width;

    final autoCheckHint =
    _getAutoCheckHint(challenge);

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        if (autoCheckHint.isNotEmpty) ...[
          _buildAutoCheckHint(
            text: autoCheckHint,
            screenWidth: screenWidth,
          ),

          SizedBox(
            height: screenWidth * 0.025,
          ),
        ],

        CardBox(
          margin: EdgeInsets.zero,
          padding: EdgeInsets.symmetric(
            horizontal:
            screenWidth * 0.04,
            vertical:
            screenWidth * 0.018,
          ),
          child: Column(
            children: [
              _buildInfoItem(
                icon:
                Icons.short_text_rounded,
                label:
                '한줄 소개',
                value:
                challenge.shortDescription,
                screenWidth:
                screenWidth,
              ),

              _buildDivider(),

              _buildInfoItem(
                icon:
                Icons.flag_outlined,
                label:
                '목표',
                value:
                challenge.goalDisplayText ??
                    '도전 목표 미정',
                screenWidth:
                screenWidth,
              ),

              _buildDivider(),

              _buildInfoItem(
                icon:
                Icons.calendar_today_outlined,
                label:
                '기간',
                value:
                challenge.periodDisplayText ??
                    '기간 미정',
                screenWidth:
                screenWidth,
              ),

              if (challenge.stageType ==
                  ChallengeStageType.staged) ...[
                _buildDivider(),

                _buildStageItem(
                  challenge: challenge,
                  screenWidth: screenWidth,
                ),
              ],

              if (challenge.isCustom == true &&
                  challenge.longDescription
                      ?.trim()
                      .isNotEmpty ==
                      true) ...[
                _buildDivider(),

                _buildDescriptionItem(
                  value:
                  challenge.longDescription!,
                  screenWidth:
                  screenWidth,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required double screenWidth,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical:
        screenWidth * 0.025,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width:
            screenWidth * 0.085,
            height:
            screenWidth * 0.085,
            decoration:
            BoxDecoration(
              color: Colors.white
                  .withOpacity(0.06),
              borderRadius:
              BorderRadius.circular(
                10,
              ),
            ),
            child: Icon(
              icon,
              color:
              Colors.white60,
              size:
              screenWidth * 0.043,
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
                Text(
                  label,
                  style: TextStyle(
                    color:
                    Colors.white38,
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth *
                        0.027,
                  ),
                ),

                SizedBox(
                  height:
                  screenWidth *
                      0.008,
                ),

                Text(
                  value,
                  style: TextStyle(
                    color:
                    Colors.white,
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth *
                        0.032,
                    fontWeight:
                    FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageItem({
    required Challenge challenge,
    required double screenWidth,
  }) {
    final stageInfo =
    _getStageInfo(
      challenge,
    );

    if (stageInfo == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical:
        screenWidth * 0.025,
      ),
      child: Row(
        children: [
          Container(
            width:
            screenWidth * 0.085,
            height:
            screenWidth * 0.085,
            decoration:
            BoxDecoration(
              color: Colors.amberAccent
                  .withOpacity(0.10),
              borderRadius:
              BorderRadius.circular(
                10,
              ),
            ),
            child: Icon(
              Icons
                  .stairs_rounded,
              color:
              Colors.amberAccent,
              size:
              screenWidth * 0.043,
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
                Text(
                  '현재 스테이지',
                  style: TextStyle(
                    color:
                    Colors.white38,
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth *
                        0.027,
                  ),
                ),

                SizedBox(
                  height:
                  screenWidth *
                      0.008,
                ),

                Text(
                  stageInfo,
                  style: TextStyle(
                    color: Colors
                        .amberAccent,
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth *
                        0.032,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionItem({
    required String value,
    required double screenWidth,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical:
        screenWidth * 0.025,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width:
            screenWidth * 0.085,
            height:
            screenWidth * 0.085,
            decoration:
            BoxDecoration(
              color: Colors.white
                  .withOpacity(0.06),
              borderRadius:
              BorderRadius.circular(
                10,
              ),
            ),
            child: Icon(
              Icons
                  .notes_rounded,
              color:
              Colors.white60,
              size:
              screenWidth * 0.043,
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
                Text(
                  '상세 설명',
                  style: TextStyle(
                    color:
                    Colors.white38,
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth *
                        0.027,
                  ),
                ),

                SizedBox(
                  height:
                  screenWidth *
                      0.008,
                ),

                Text(
                  value,
                  style: TextStyle(
                    color:
                    Colors.white70,
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth *
                        0.031,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoCheckHint({
    required String text,
    required double screenWidth,
  }) {
    return Container(
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
              .withOpacity(0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            Icons
                .auto_awesome_outlined,
            color: Colors.amberAccent
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
              text,
              style: TextStyle(
                color: Colors.white
                    .withOpacity(0.6),
                fontFamily:
                'kopub',
                fontSize:
                screenWidth * 0.028,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color:
      Colors.white.withOpacity(
        0.06,
      ),
    );
  }

  String? _getStageInfo(
      Challenge challenge,
      ) {
    final totalStages =
        challenge.stageDurations.length;

    if (totalStages == 0) {
      return null;
    }

    int stageIndex = 0;
    String statusText = '대기 중';

    ChallengeAttempt?
    activeAttempt;

    for (final attempt
    in challenge.attempts.reversed) {
      if (attempt.completed != true) {
        activeAttempt = attempt;
        break;
      }
    }

    if (challenge.isJoined &&
        activeAttempt != null) {
      stageIndex =
          (activeAttempt.stageIndex ?? 0)
              .clamp(
            0,
            totalStages - 1,
          );

      statusText = '진행 중';
    } else {
      int? lastSuccessfulStageIndex;

      for (final attempt
      in challenge.attempts) {
        if (attempt.completed == true &&
            attempt.isSuccessful ==
                true &&
            attempt.stageIndex !=
                null) {
          final index =
          attempt.stageIndex!;

          if (lastSuccessfulStageIndex ==
              null ||
              index >
                  lastSuccessfulStageIndex) {
            lastSuccessfulStageIndex =
                index;
          }
        }
      }

      if (lastSuccessfulStageIndex !=
          null) {
        stageIndex =
            lastSuccessfulStageIndex
                .clamp(
              0,
              totalStages - 1,
            );

        statusText = '완료';
      }
    }

    return '${stageIndex + 1} / '
        '$totalStages 스테이지 · '
        '$statusText';
  }

  String _getAutoCheckHint(
      Challenge challenge,
      ) {
    final type =
    getChallengeCheckActionType(
      challenge,
    );

    switch (type) {
      case ChallengeCheckActionType
          .timerAuto:
        return '독서 타이머 기록을 기반으로 자동 체크됩니다.';

      case ChallengeCheckActionType
          .pageAuto:
        return '읽은 페이지 기록을 기반으로 자동 체크됩니다.';

      case ChallengeCheckActionType
          .libraryAuto:
        return '서재의 독서 상태를 기반으로 자동 체크됩니다.';

      default:
        return '';
    }
  }
}
