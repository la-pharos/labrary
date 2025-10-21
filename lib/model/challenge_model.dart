import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'challenge_attempt_model.dart';
import 'package:dayverse_book/model/book_model.dart';

/// ✅ 챌린지 유형 (단일형 / 스테이지형)
enum ChallengeStageType { single, staged }

/// ✅ 챌린지 카테고리 (루틴형 / 성장형)
enum ChallengeCategory { routine, growth }

/// ✅ 도전 방식: 지정 횟수 / 지정 도서 / 지정 권수
enum ChallengeMethod { countBased, specificBooks, quantityBased }

/// ✅ 도전 기간: 기간형 / 일자형 / 지속형
enum ChallengePeriod { periodBased, daysBased, infinite }

/// ✅ 체크 방식 (수동형 / 자동형)
enum ChallengeCheckMode { manual, auto }

/// ✅ 지정 도서 방식: 운영자 / 사용자 지정
enum SpecificBookMode { systemDefined, userDefined }

class Challenge {
  final String id;

  final String title;
  final String shortDescription;
  final String? longDescription;
  final String? goalDescription;
  final String? recommendedFor;
  final String? guideText;

  final ChallengeStageType stageType;
  final ChallengeCategory category;
  final ChallengeMethod method;
  final ChallengePeriod period;
  final ChallengeCheckMode checkMode;

  final List<int>? durationOptions;
  final List<int>? checkCountOptions;

  final DateTime? startDate;
  final DateTime? endDate;

  final int? totalBooks;
  final int? requiredMinutes;
  final int? requiredPages;

  final SpecificBookMode? specificBookMode;
  final List<BookModel>? requiredBooks;
  final List<BookModel>? participatingBooks;

  final String imageUrl;
  final String? goalDisplayText;
  final String? periodDisplayText;

  final bool isCustom;
  final bool isPremium;
  final bool isJoined;
  final bool isCompleted;
  final bool isRepeatable;
  final bool forceBookSelection;

  final bool isArchived;

  final List<int> stageDurations;
  final List<ChallengeAttempt> attempts;

  final TimeOfDay? allowedStartTime;
  final TimeOfDay? allowedEndTime;

  Challenge({
    String? id,
    required this.title,
    required this.shortDescription,
    this.longDescription,
    this.goalDescription,
    this.recommendedFor,
    this.guideText,
    required this.stageType,
    required this.category,
    required this.method,
    required this.period,
    required this.checkMode,
    this.durationOptions,
    this.checkCountOptions,
    this.startDate,
    this.endDate,
    this.totalBooks,
    this.requiredMinutes,
    this.requiredPages,
    this.specificBookMode,
    this.requiredBooks,
    this.participatingBooks,
    required this.imageUrl,
    this.goalDisplayText,
    this.periodDisplayText,
    this.isCustom = false,
    this.isPremium = false,
    this.isJoined = false,
    this.isCompleted = false,
    this.isRepeatable = false,
    this.forceBookSelection = false,
    this.isArchived = false,
    this.stageDurations = const [],
    this.attempts = const [],
    this.allowedStartTime,
    this.allowedEndTime,
  }) : id = id ?? const Uuid().v4();

  factory Challenge.fromMap(Map<String, dynamic> map) {
    return Challenge(
      id: map['id'],
      title: map['title'],
      shortDescription: map['shortDescription'],
      longDescription: map['longDescription'],
      goalDescription: map['goalDescription'],
      recommendedFor: map['recommendedFor'],
      guideText: map['guideText'],
      stageType: ChallengeStageType.values.firstWhere((e) => e.name == map['stageType']),
      category: ChallengeCategory.values.firstWhere((e) => e.name == map['category']),
      method: ChallengeMethod.values.firstWhere((e) => e.name == map['method']),
      period: ChallengePeriod.values.firstWhere((e) => e.name == map['period']),
      checkMode: ChallengeCheckMode.values.firstWhere((e) => e.name == map['checkMode']),
      durationOptions: map['durationOptions'] != null ? List<int>.from(map['durationOptions']) : null,
      checkCountOptions: map['checkCountOptions'] != null ? List<int>.from(map['checkCountOptions']) : null,
      startDate: map['startDate'] != null ? DateTime.parse(map['startDate']).toLocal() : null,
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']).toLocal() : null,
      totalBooks: map['totalBooks'],
      requiredMinutes: map['requiredMinutes'],
      requiredPages: map['requiredPages'],
      specificBookMode: map['specificBookMode'] != null
          ? SpecificBookMode.values.firstWhere((e) => e.name == map['specificBookMode'])
          : null,
      requiredBooks: map['requiredBooks'] != null
          ? (map['requiredBooks'] as List)
          .map((e) => BookModel.fromMap(Map<String, dynamic>.from(e)))
          .toList()
          : null,
      participatingBooks: map['participatingBooks'] != null
          ? (map['participatingBooks'] as List)
          .map((e) => BookModel.fromMap(Map<String, dynamic>.from(e)))
          .toList()
          : null,
      imageUrl: map['imageUrl'],
      goalDisplayText: map['goalDisplayText'],
      periodDisplayText: map['periodDisplayText'],
      isCustom: map['isCustom'] ?? false,
      isPremium: map['isPremium'] ?? false,
      isJoined: map['isJoined'] ?? false,
      isCompleted: map['isCompleted'] ?? false,
      isRepeatable: map['isRepeatable'] ?? false,
      forceBookSelection: map['forceBookSelection'] ?? false,
      isArchived: map['isArchived'] ?? false,
      stageDurations: List<int>.from(map['stageDurations'] ?? []),
      attempts: map['attempts'] != null
          ? List<ChallengeAttempt>.from(
          (map['attempts'] as List).map((e) => ChallengeAttempt.fromMap(Map<String, dynamic>.from(e))))
          : [],
      allowedStartTime: map['allowedStartTime'] != null ? _parseTime(map['allowedStartTime']) : null,
      allowedEndTime: map['allowedEndTime'] != null ? _parseTime(map['allowedEndTime']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'shortDescription': shortDescription,
      'longDescription': longDescription,
      'goalDescription': goalDescription,
      'recommendedFor': recommendedFor,
      'guideText': guideText,
      'stageType': stageType.name,
      'category': category.name,
      'method': method.name,
      'period': period.name,
      'checkMode': checkMode.name,
      'durationOptions': durationOptions,
      'checkCountOptions': checkCountOptions,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'totalBooks': totalBooks,
      'requiredMinutes': requiredMinutes,
      'requiredPages': requiredPages,
      'specificBookMode': specificBookMode?.name,
      'requiredBooks': requiredBooks?.map((b) => b.toMap()).toList(),
      'participatingBooks': participatingBooks?.map((b) => b.toMap()).toList(),
      'imageUrl': imageUrl,
      'goalDisplayText': goalDisplayText,
      'periodDisplayText': periodDisplayText,
      'isCustom': isCustom,
      'isPremium': isPremium,
      'isJoined': isJoined,
      'isCompleted': isCompleted,
      'isRepeatable': isRepeatable,
      'forceBookSelection': forceBookSelection,
      'isArchived': isArchived,
      'stageDurations': stageDurations,
      'attempts': attempts.map((a) => a.toMap()).toList(),
      'allowedStartTime': allowedStartTime != null ? _formatTime(allowedStartTime!) : null,
      'allowedEndTime': allowedEndTime != null ? _formatTime(allowedEndTime!) : null,
    };
  }

  Challenge copyWith({
    String? id,
    String? title,
    String? shortDescription,
    String? longDescription,
    String? goalDescription,
    String? recommendedFor,
    String? guideText,
    ChallengeStageType? stageType,
    ChallengeCategory? category,
    ChallengeMethod? method,
    ChallengePeriod? period,
    ChallengeCheckMode? checkMode,
    List<int>? durationOptions,
    List<int>? checkCountOptions,
    DateTime? startDate,
    DateTime? endDate,
    int? totalBooks,
    int? requiredMinutes,
    int? requiredPages,
    SpecificBookMode? specificBookMode,
    List<BookModel>? requiredBooks,
    List<BookModel>? participatingBooks,
    String? imageUrl,
    String? badgeImage,
    String? rewardTitle,
    String? goalDisplayText,
    String? periodDisplayText,
    bool? isCustom,
    bool? isPremium,
    bool? isJoined,
    bool? isCompleted,
    bool? isRepeatable,
    bool? forceBookSelection,
    bool? isArchived,
    List<int>? stageDurations,
    List<ChallengeAttempt>? attempts,
    TimeOfDay? allowedStartTime,
    TimeOfDay? allowedEndTime,
  }) {
    return Challenge(
      id: id ?? this.id,
      title: title ?? this.title,
      shortDescription: shortDescription ?? this.shortDescription,
      longDescription: longDescription ?? this.longDescription,
      goalDescription: goalDescription ?? this.goalDescription,
      recommendedFor: recommendedFor ?? this.recommendedFor,
      guideText: guideText ?? this.guideText,
      stageType: stageType ?? this.stageType,
      category: category ?? this.category,
      method: method ?? this.method,
      period: period ?? this.period,
      checkMode: checkMode ?? this.checkMode,
      durationOptions: durationOptions ?? this.durationOptions,
      checkCountOptions: checkCountOptions ?? this.checkCountOptions,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalBooks: totalBooks ?? this.totalBooks,
      requiredMinutes: requiredMinutes ?? this.requiredMinutes,
      requiredPages: requiredPages ?? this.requiredPages,
      specificBookMode: specificBookMode ?? this.specificBookMode,
      requiredBooks: requiredBooks ?? this.requiredBooks,
      participatingBooks: participatingBooks ?? this.participatingBooks,
      imageUrl: imageUrl ?? this.imageUrl,
      goalDisplayText: goalDisplayText ?? this.goalDisplayText,
      periodDisplayText: periodDisplayText ?? this.periodDisplayText,
      isCustom: isCustom ?? this.isCustom,
      isPremium: isPremium ?? this.isPremium,
      isJoined: isJoined ?? this.isJoined,
      isCompleted: isCompleted ?? this.isCompleted,
      isRepeatable: isRepeatable ?? this.isRepeatable,
      forceBookSelection: forceBookSelection ?? this.forceBookSelection,
      isArchived: isArchived ?? this.isArchived,
      stageDurations: stageDurations ?? this.stageDurations,
      attempts: attempts ?? this.attempts,
      allowedStartTime: allowedStartTime ?? this.allowedStartTime,
      allowedEndTime: allowedEndTime ?? this.allowedEndTime,
    );
  }

  static TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// ✅ 현재 스테이지 인덱스 계산 (항상 최신 attempt 기준)
  int get currentStageIndex {
    if (stageType != ChallengeStageType.staged) return 0;
    if (attempts.isEmpty) return 0;
    return attempts.last.stageIndex ?? 0;
  }

  // --------- 편의 계산 속성(Provider 필터에서 활용하기 좋음) ---------

  /// 소프트 삭제 상태(전 섹션에서 숨김)
  bool get isSoftDeleted => isArchived;

  /// “챌린지 참여하기” 섹션 노출 후보
  bool get isJoinableCandidate =>
      !isArchived && !isCustom && !isJoined && !isCompleted;

  /// 진행 중 섹션 노출(아카이브면 제외)
  bool get isOngoingVisible => !isArchived && isJoined && !isCompleted;

  /// 완료 섹션 노출(아카이브면 제외)
  bool get isCompletedVisible => !isArchived && isCompleted;
}
