import 'package:flutter/material.dart';
import 'package:dayverse_book/model/challenge_model.dart';

class StageInfoCard extends StatelessWidget {
  final Challenge challenge;

  const StageInfoCard({
    super.key,
    required this.challenge,
  });

  @override
  Widget build(BuildContext context) {
    if (challenge.stageType != ChallengeStageType.staged ||
        challenge.stageDurations == null ||
        challenge.stageDurations!.isEmpty ||
        challenge.attempts.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final padding = screenWidth * 0.04;
    final fontSize = screenWidth * 0.038; // ≈16px

    final currentAttempt = challenge.attempts.lastWhere(
          (a) => !a.completed,
      orElse: () => challenge.attempts.last,
    );
    final stageIndex = currentAttempt.stageIndex ?? (challenge.attempts.length - 1);
    final clampedIndex = stageIndex.clamp(0, challenge.stageDurations!.length - 1);
    final currentDuration = challenge.stageDurations![clampedIndex];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amberAccent,
          width: 1,
        ),
      ),
      child: Text(
        "🚀 현재 스테이지: [${clampedIndex + 1}단계] - $currentDuration일 루틴",
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontFamily: 'kopub',
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
