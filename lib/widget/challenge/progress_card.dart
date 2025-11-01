import 'package:flutter/material.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/utils/challenge_progress_utils.dart';
import 'package:dayverse_book/utils/challenge_check_utils.dart';

class ProgressCard extends StatelessWidget {
  final Challenge challenge;
  final List<BookModel> savedBooks;
  final Map<String, dynamic> record;

  /// ✅ 북풀 해석본 등 외부에서 주입한 타겟 도서
  final List<BookModel>? targetBooksOverride;

  const ProgressCard({
    super.key,
    required this.challenge,
    required this.savedBooks,
    required this.record,
    this.targetBooksOverride,
  });

  /// ✅ 공통 키 규칙(id > isbn)
  String? _keyForBook(BookModel b) {
    if (b.id.isNotEmpty) return b.id;
    final isbn = b.isbn;
    if (isbn != null && isbn.isNotEmpty) return isbn;
    return null;
  }

  /// ✅ 이 카드에서 사용할 '타겟 도서' 결정 로직 (override > attempt.participated > required)
  List<BookModel> get _targetBooks {
    if (targetBooksOverride != null && targetBooksOverride!.isNotEmpty) {
      return targetBooksOverride!;
    }
    final participated = challenge.attempts.isNotEmpty
        ? (challenge.attempts.last.participatedBooks ?? const <BookModel>[])
        : const <BookModel>[];
    if (participated.isNotEmpty) return participated;
    return challenge.requiredBooks ?? const <BookModel>[];
  }

  @override
  Widget build(BuildContext context) {
    final checkType = getChallengeCheckActionType(challenge);
    final dynamic source =
    (checkType == ChallengeCheckActionType.libraryAuto) ? savedBooks : record;

    final String statusText = _buildStatusText(challenge);
    final String unit = _getUnit(challenge, checkType);

    // 1) 기본값: 유틸(override 포함)로 계산
    var targetCount = ChallengeProgressUtils.getTargetCount(
      challenge,
      source,
      targetBooksOverride: _targetBooks,
    );
    var completed = ChallengeProgressUtils.getCompletedCount(
      challenge,
      source,
      targetBooksOverride: _targetBooks,
    );
    var progress = ChallengeProgressUtils.getProgress(
      challenge,
      source,
      targetBooksOverride: _targetBooks,
    );
    var percentage = (progress * 100).toInt().clamp(0, 100);

    // 2) ✅ 지정도서 + 페이지연동(pageAuto)인 경우: '페이지 합산 방식'으로 표기 교체
    if (challenge.method == ChallengeMethod.specificBooks &&
        checkType == ChallengeCheckActionType.pageAuto) {
      final pageProgress = _pageSumProgressFromTargets(source); // ← 아래 함수
      final totalPages = pageProgress['target']!;
      final readPages  = pageProgress['completed']!;
      if (totalPages > 0) {
        targetCount = totalPages;
        completed   = readPages;
        progress    = (readPages / totalPages).clamp(0.0, 1.0);
        percentage  = (progress * 100).toInt().clamp(0, 100);
      }
    }

    return _buildProgressContainer(
      statusText,
      progress,
      completed,
      targetCount,
      percentage,
      unit,
    );
  }

  /// ✅ 타겟(override/participated/required) 기준 페이지 진행(읽은합/전체합)
  Map<String, int> _pageSumProgressFromTargets(dynamic data) {
    // 1) record.bookReadPages 안전 추출 (top-level 또는 recordData 내부)
    Map<String, dynamic> recordPages = <String, dynamic>{};
    if (data is Map) {
      final brpTop = data['bookReadPages'];
      if (brpTop is Map) {
        recordPages = Map<String, dynamic>.from(brpTop as Map);
      } else {
        final inner = data['recordData'];
        if (inner is Map && inner['bookReadPages'] is Map) {
          recordPages = Map<String, dynamic>.from(inner['bookReadPages'] as Map);
        }
      }
    }

    // 2) savedBooks 빠른 조회 (id > isbn)
    String? keyFor(BookModel b) =>
        (b.id.isNotEmpty) ? b.id : (b.isbn?.isNotEmpty == true ? b.isbn : null);

    final savedMap = <String, BookModel>{
      for (final sb in savedBooks)
        if (keyFor(sb) != null) keyFor(sb)!: sb,
    };

    int totalPages = 0;
    int readPagesSum = 0;

    for (final t in _targetBooks) {
      final k = keyFor(t);
      if (k == null) continue;

      // ⚠️ pageCount는 non-nullable int
      final total = (t.pageCount > 0)
          ? t.pageCount
          : (savedMap[k]?.pageCount ?? 0);
      if (total <= 0) continue;

      final fromRecord = int.tryParse(recordPages[k]?.toString() ?? '') ?? 0;
      final fromSaved  = savedMap[k]?.pageRead ?? 0;
      final read = (fromRecord > 0 ? fromRecord : fromSaved);
      final clippedRead = read.clamp(0, total);

      totalPages   += total;
      readPagesSum += clippedRead;
    }

    return {'completed': readPagesSum, 'target': totalPages};
  }

  /// ✅ 타겟 도서 기준 페이지 진행(읽은합/전체합) 계산
  /// - record.bookReadPages(키=id 또는 isbn) > savedBooks.pageRead(백업)
  Map<String, int> _getPageProgressFromTargets(dynamic data) {
    // recordPages 안전 추출
    Map<String, dynamic> recordPages = <String, dynamic>{};
    if (data is Map) {
      final brpTop = data['bookReadPages'];
      if (brpTop is Map) {
        recordPages = Map<String, dynamic>.from(brpTop as Map);
      } else {
        final inner = data['recordData'];
        if (inner is Map && inner['bookReadPages'] is Map) {
          recordPages = Map<String, dynamic>.from(inner['bookReadPages'] as Map);
        }
      }
    }

    // savedBooks 맵 (id > isbn)
    String? keyFor(BookModel b) =>
        (b.id.isNotEmpty) ? b.id : (b.isbn?.isNotEmpty == true ? b.isbn : null);

    final savedMap = <String, BookModel>{
      for (final sb in savedBooks)
        if (keyFor(sb) != null) keyFor(sb)!: sb,
    };

    int totalPages = 0;
    int readPagesSum = 0;

    for (final t in _targetBooks) {
      final k = keyFor(t);
      if (k == null) continue;

      final total = t.pageCount; // non-nullable
      if (total <= 0) continue;

      final fromRecord = int.tryParse(recordPages[k]?.toString() ?? '') ?? 0;
      final fromSaved  = savedMap[k]?.pageRead ?? 0;
      final read = (fromRecord > 0 ? fromRecord : fromSaved);
      final clippedRead = read.clamp(0, total);

      totalPages   += total;
      readPagesSum += clippedRead;
    }

    return {'completed': readPagesSum, 'target': totalPages};
  }

  // --- 이하 기존 보조 메서드 그대로 ---

  String _buildStatusText(Challenge challenge) {
    final today = stripTime(DateTime.now());
    final attempt = challenge.attempts.isNotEmpty ? challenge.attempts.last : null;
    final startDate = attempt?.startDate.toLocal();
    int? duration;

    if (attempt?.stageIndex != null && challenge.stageDurations.isNotEmpty) {
      final idx = attempt!.stageIndex!;
      if (idx >= 0 && idx < challenge.stageDurations.length) {
        duration = challenge.stageDurations[idx];
      }
    }

    duration ??= attempt?.selectedDuration;

    if (duration == null && attempt?.endDate != null && startDate != null) {
      final s = stripTime(startDate);
      final e = stripTime(attempt!.endDate!.toLocal());
      duration = e.difference(s).inDays + 1;
    }

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
                  ? Colors.greenAccent
                  : Colors.amberAccent,
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
            value: (progress.clamp(0.0, 1.0) as num).toDouble(),
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
