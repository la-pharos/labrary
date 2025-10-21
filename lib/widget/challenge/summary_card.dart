import 'package:flutter/material.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/challenge_attempt_model.dart';
import 'package:dayverse_book/utils/challenge_check_utils.dart';

class SummaryCard extends StatelessWidget {
  final Challenge challenge;

  const SummaryCard({super.key, required this.challenge});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final autoCheckHint = _getAutoCheckHint(challenge);

    final fontSize = screenWidth * 0.032; // 약 14~16
    final iconSize = screenWidth * 0.052; // 약 18~24
    final padding = screenWidth * 0.03;  // 약 12
    final marginBottom = screenWidth * 0.025;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (autoCheckHint.isNotEmpty)
          _buildHintBox(autoCheckHint, fontSize, iconSize, padding, marginBottom),
        if (challenge.stageType == ChallengeStageType.staged)
          _buildInfoStageRow("🚀 현재 스테이지", challenge, fontSize, padding, marginBottom),
        _buildInfoRow("💡 한줄 소개", challenge.shortDescription, fontSize, padding, marginBottom),
        _buildInfoRow("🎯 목표", challenge.goalDisplayText ?? "도전 목표 미정", fontSize, padding, marginBottom),
        _buildInfoRow("🗓 기간", challenge.periodDisplayText ?? "기간 미정", fontSize, padding, marginBottom),
      ],
    );
  }

  Widget _buildHintBox(String text, double fontSize, double iconSize, double padding, double marginBottom) {
    return Container(
      margin: EdgeInsets.only(bottom: marginBottom),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amberAccent, size: iconSize),
          SizedBox(width: padding * 0.6),
          Text(
            text,
            style: TextStyle(
              color: Colors.amberAccent,
              fontSize: fontSize,
              fontFamily: 'kopub',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value, double fontSize, double padding, double marginBottom) {
    return Container(
      margin: EdgeInsets.only(bottom: marginBottom),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'kopub',
              fontSize: fontSize,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontSize: fontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoStageRow(String title, Challenge challenge, double fontSize, double padding, double marginBottom) {
    final totalStages = challenge.stageDurations?.length ?? 0;
    final completedStages = challenge.attempts.where((a) => a.completed).length;

    final stageText = "$completedStages / $totalStages 스테이지";

    return Container(
      margin: EdgeInsets.only(bottom: marginBottom),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.amberAccent,
              fontFamily: 'kopub',
              fontSize: fontSize,
            ),
          ),
          Text(
            stageText,
            style: TextStyle(
              color: Colors.amberAccent,
              fontFamily: 'kopub',
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }

  String _getAutoCheckHint(Challenge challenge) {
    final type = getChallengeCheckActionType(challenge);
    switch (type) {
      case ChallengeCheckActionType.timerAuto:
        return "⏱ 타이머 기반으로 자동 체크되는 챌린지입니다.";
      case ChallengeCheckActionType.pageAuto:
        return "📖 페이지 수 입력으로 자동 체크되는 챌린지입니다.";
      case ChallengeCheckActionType.libraryAuto:
        return "📚 서재 연동으로 자동 체크되는 챌린지입니다.";
      default:
        return "";
    }
  }
}