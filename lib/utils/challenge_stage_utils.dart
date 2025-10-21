import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/challenge_attempt_model.dart';


extension StageChallengeUtils on Challenge {
  /// ✅ 현재 스테이지 챌린지가 아닌 경우 무조건 0으로 간주
  int get currentStageIndex {
    if (stageType != ChallengeStageType.staged) return 0;

    final current = attempts.lastWhere(
          (a) => !a.completed,
      orElse: () => ChallengeAttempt(stageIndex: 0, startDate: DateTime(2000)),
    );

    return current.stageIndex ?? 0;
  }

  /// ✅ 현재 스테이지의 목표 일수 (없으면 null)
  int? get currentStageDuration {
    if (stageType != ChallengeStageType.staged || stageDurations == null) return null;
    if (currentStageIndex >= stageDurations!.length) return null;
    return stageDurations![currentStageIndex];
  }

  /// ✅ 현재 스테이지 텍스트 (예: "2단계 / 총 3단계")
  String get currentStageText {
    if (stageType != ChallengeStageType.staged || stageDurations == null) return "";
    return "${currentStageIndex + 1}단계 / 총 ${stageDurations!.length}단계";
  }

  /// ✅ 마지막 스테이지 여부
  bool get isLastStage {
    if (stageType != ChallengeStageType.staged || stageDurations == null) return true;

    final currentIndex = currentStageIndex;
    return currentIndex >= stageDurations!.length - 1;
  }

  /// ✅ 다음 스테이지 존재 여부
  bool get hasNextStage {
    if (stageType != ChallengeStageType.staged || stageDurations == null) return false;
    return currentStageIndex < stageDurations!.length - 1;
  }

  /// ✅ 현재 스테이지 시작일
  DateTime? get currentStageStartDate {
    return attempts.isNotEmpty ? attempts.last.startDate : null;
  }

  /// ✅ 현재 스테이지 종료일
  DateTime? get currentStageEndDate {
    return attempts.isNotEmpty ? attempts.last.endDate : null;
  }


}
