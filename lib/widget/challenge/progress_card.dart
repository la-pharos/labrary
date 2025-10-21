import 'package:flutter/material.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/utils/challenge_progress_utils.dart';
import 'package:dayverse_book/utils/challenge_check_utils.dart';

class ProgressCard extends StatelessWidget {
  final Challenge challenge;
  final List<BookModel> savedBooks;
  final Map<String, dynamic> record;

  const ProgressCard({
    super.key,
    required this.challenge,
    required this.savedBooks,
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    final checkType = getChallengeCheckActionType(challenge);

    dynamic source;
    switch (checkType) {
      case ChallengeCheckActionType.libraryAuto:
        source = savedBooks;
        break;
      default:
        source = record;
        break;
    }

    final String statusText = _buildStatusText(challenge);
    final String unit = _getUnit(challenge, checkType);

    int targetCount = ChallengeProgressUtils.getTargetCount(challenge, source);
    int completed = ChallengeProgressUtils.getCompletedCount(challenge, source);

    // ✅ 지정도서 + 페이지 연동인 경우 → 페이지 기준 진행률 계산
    if (challenge.method == ChallengeMethod.specificBooks &&
        checkType == ChallengeCheckActionType.pageAuto) {
      final pageProgress = _getTotalReadPages(challenge, source);
      completed = pageProgress['completed']!;
      targetCount = pageProgress['target']!;
    }

    final double progress = (targetCount > 0) ? completed / targetCount : 0.0;
    final int percentage = (progress * 100).toInt().clamp(0, 100);

    return _buildProgressContainer(statusText, progress, completed, targetCount, percentage, unit);
  }

  Map<String, int> _getTotalReadPages(Challenge challenge, dynamic data) {
    final readPages = (data is Map && data['bookReadPages'] is Map)
        ? (data['bookReadPages'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    num total = 0;
    num completed = 0;

    if (challenge.specificBookMode == SpecificBookMode.systemDefined) {
      for (final b in challenge.requiredBooks ?? []) {
        final id = b.id?.toString();
        final pageCount = int.tryParse(b.pageCount?.toString() ?? '') ?? 0;
        BookModel? bookModel;
        try {
          bookModel = savedBooks.firstWhere((sb) => sb.id == id);
        } catch (_) {
          bookModel = null;
        }
        final readFromBook = bookModel?.pageRead ?? 0;
        final readFromRecord = int.tryParse(readPages[id]?.toString() ?? '') ?? 0;

        /// ✅ record 우선 → savedBooks는 보조
        final read = readFromRecord > 0 ? readFromRecord : readFromBook;

        total += pageCount;
        completed += read.clamp(0, pageCount);
      }
    } else {
      final books = challenge.attempts.isNotEmpty
          ? challenge.attempts.last.participatedBooks ?? []
          : [];
      for (final b in books) {
        final id = b.id;
        final pageCount = b.pageCount ?? 0;
        BookModel? bookModel;
        try {
          bookModel = savedBooks.firstWhere((sb) => sb.id == id);
        } catch (_) {
          bookModel = null;
        }
        final readFromBook = bookModel?.pageRead ?? 0;
        final readFromRecord = int.tryParse(readPages[id]?.toString() ?? '') ?? 0;

        /// ✅ record 우선 → savedBooks는 보조
        final read = readFromRecord > 0 ? readFromRecord : readFromBook;

        total += pageCount;
        completed += read.clamp(0, pageCount);
      }
    }

    return {
      'completed': completed.toInt(),
      'target': total.toInt(),
    };
  }

  /// ✅ checkType에 따라 올바른 dummy 또는 실제 데이터를 반환
  dynamic _buildProgressSource(ChallengeCheckActionType type, List<BookModel> savedBooks) {
    switch (type) {
      case ChallengeCheckActionType.libraryAuto:
        return savedBooks;

      case ChallengeCheckActionType.pageAuto:
        return {
          'bookReadPages': <String, dynamic>{},
        };

      case ChallengeCheckActionType.timerAuto:
        return {
          'recordData': {
            'dailyMinutes': <String, dynamic>{},
          },
        };

      case ChallengeCheckActionType.manual:
        return {
          'routineChecks': <String, bool>{},
          'countChecks': <String, bool>{},
        };

      case ChallengeCheckActionType.none:
      default:
        return <String, dynamic>{};
    }
  }

  String _buildStatusText(Challenge challenge) {
    final today = stripTime(DateTime.now());
    final attempt = challenge.attempts.isNotEmpty ? challenge.attempts.last : null;
    final startDate = attempt?.startDate.toLocal();
    int? duration;

    // 1) (스테이지형) 스테이지 길이
    if (attempt?.stageIndex != null && challenge.stageDurations.isNotEmpty) {
      final idx = attempt!.stageIndex!;
      if (idx >= 0 && idx < challenge.stageDurations.length) {
        duration = challenge.stageDurations[idx];
      }
    }

    // 2) (단일형) 시도에 저장된 기간
    duration ??= attempt?.selectedDuration;

    // ✅ 3) 보강: 시도에 endDate가 있으면 그걸로 기간 산출(포함 일수)
    if (duration == null && attempt?.endDate != null && startDate != null) {
      final s = stripTime(startDate);
      final e = stripTime(attempt!.endDate!.toLocal());
      duration = e.difference(s).inDays + 1;
    }

    // ✅ 4) 보강: daysBased + durationOptions가 있으면 그걸 사용
    if (duration == null &&
        challenge.stageType == ChallengeStageType.single &&
        challenge.period == ChallengePeriod.daysBased &&
        (challenge.durationOptions != null && challenge.durationOptions!.isNotEmpty)) {
      duration = challenge.durationOptions!.first;
    }

    if (startDate != null && duration != null) {
      final start = stripTime(startDate);
      final end = start.add(Duration(days: duration - 1));
      if (today.isBefore(start)) {
        final dDay = start.difference(today).inDays;
        return "🚀 시작까지 D-$dDay";
      } else if (today.isAtSameMomentAs(end)) {
        return "⏳ 오늘이 마지막 날이에요!";
      } else if (today.isAfter(start) && today.isBefore(end)) {
        final dDay = end.difference(today).inDays;
        return "⏳ 종료까지 D-$dDay";
      } else if (today.isAfter(end)) {
        return "✅ 기간 종료";
      } else {
        return "⏳ 종료까지 D-${end.difference(today).inDays}";
      }
    }

    // (periodBased 폴백은 그대로 유지)
    if (challenge.endDate != null) {
      final end = stripTime(challenge.endDate!.toLocal());
      if (today.isAtSameMomentAs(end)) return "⏳ 오늘이 마지막 날이에요!";
      if (today.isBefore(end)) return "⏳ 종료까지 D-${end.difference(today).inDays}";
      return "✅ 기간 종료";
    }

    return "🌱 정해진 기한이 없는 자유 챌린지에요.";
  }

  DateTime stripTime(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  String _getUnit(Challenge challenge, ChallengeCheckActionType checkType) {
    switch (checkType) {
      case ChallengeCheckActionType.pageAuto:
        return "페이지";
      case ChallengeCheckActionType.timerAuto:
      case ChallengeCheckActionType.manual:
        return "회";
      case ChallengeCheckActionType.libraryAuto:
        return "권";
      default:
        return "-";
    }
  }

  Widget _buildProgressContainer(
      String statusText,
      double progress,
      int completed,
      int targetCount,
      int percentage,
      String unit, {
        String? extraText,
      }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            statusText,
            style: TextStyle(
              fontSize: 16,
              color: statusText.startsWith("🚀 시작까지")
                  ? Colors.greenAccent    // 원하는 색상으로 바꿔줘
                  : Colors.amberAccent,   // 기존 색상
              fontFamily: 'kopub',
              fontWeight: FontWeight.bold,
            ),
          ),

          if (extraText != null) ...[
            const SizedBox(height: 4),
            Text(
              extraText,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'kopub',
              ),
            ),
          ],
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.white10,
            color: Colors.amberAccent,
            minHeight: 8,
          ),
          const SizedBox(height: 12),
          Text(
            targetCount > 0
                ? "$percentage% 완료  ($completed / $targetCount $unit)"
                : "진행률: 데이터 없음",
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }


}
