import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../model/challenge_attempt_model.dart';
import 'package:dayverse_book/model/book_model.dart';

/// ✅ 챌린지 유형 (루틴형/성장형)
enum ChallengeType { routine, growth }

/// ✅ 챌린지 도전 방식 (지정횟수/지정도서/지정권수)
enum ChallengeMethod { countBased, specificBooks, quantityBased }

/// ✅ 챌린지 도전 기간 (기간형/일자형/지속형)
enum ChallengePeriod { periodBased, daysBased, infinite }

/// ✅ 챌린지 체크 방식 (수동형/자동형)
enum ChallengeCheckMode { manual, auto }

/// ✅ 지정 도서 방식 (운영자 or 사용자)
enum SpecificBookMode { systemDefined, userDefined }

/// ✅ 챌린지 스테이지 유무 (일반형 / 단계형)
enum ChallengeStageType { single, staged }

class Challenge {
  final String id;
  final String title;
  final String shortDescription;
  final String? longDescription;
  final String? goalDescription;
  final String? recommendedFor;
  final String? guideText;

  final ChallengeType type;
  final ChallengeMethod method;
  final ChallengePeriod period;
  final ChallengeCheckMode checkMode;

  final List<int>? durationOptions; // 사용자가 선택할 수 있는 도전 기간
  final List<int>? checkCountOptions; // 사용자가 선택할 수 있는 도전 횟수
  final DateTime? startDate;
  final DateTime? endDate;

  final int? totalBooks; // 목표 권수 (지정 권수)
  final List<Map<String, dynamic>>? requiredBooks; // 운영자가 지정한 도서 목록
  final List<BookModel>? participatingBooks; // 사용자가 선택한 도서 목록

  final String imageUrl;
  final String badgeImage;
  final String rewardTitle;
  final String? goalDisplayText;
  final String? periodDisplayText;

  final bool isCustom; // 커스텀 챌린지 여부
  final bool isPremium;
  final bool isJoined;
  final bool isCompleted;
  final bool isRepeatable;
  final bool forceBookSelection; // 참여 시 책 선택이 필수 인지

  final ChallengeStageType stageType;
  final List<int> stageDurations; // 예: [7, 21, 66]

  final List<ChallengeAttempt> attempts;

  final int? requiredMinutes; // 하루 목표 독서 시간
  final int? requiredPages; // 하루 목표 페이지 수

  final SpecificBookMode? specificBookMode; // 지정 도서 방식

  final TimeOfDay? allowedStartTime; // 도전 가능 시작 시각
  final TimeOfDay? allowedEndTime;   // 도전 가능 종료 시각

  Challenge({
    String? id,
    required this.title,
    required this.shortDescription,
    this.longDescription,
    this.goalDescription,
    this.recommendedFor,
    this.guideText,
    required this.type,
    required this.method,
    required this.period,
    required this.checkMode,
    this.durationOptions,
    this.checkCountOptions,
    this.startDate,
    this.endDate,
    this.totalBooks,
    this.requiredBooks,
    this.participatingBooks,
    required this.imageUrl,
    required this.badgeImage,
    required this.rewardTitle,
    this.goalDisplayText,
    this.periodDisplayText,
    this.isCustom = false,
    this.isPremium = false,
    this.isJoined = false,
    this.isCompleted = false,
    this.isRepeatable = false,
    this.forceBookSelection = false,
    this.stageType = ChallengeStageType.single, // ✅ 기본값: single
    this.stageDurations = const [],
    this.attempts = const [],
    this.requiredMinutes,
    this.requiredPages,
    this.specificBookMode,
    this.allowedStartTime,
    this.allowedEndTime,
  }) : id = id ?? const Uuid().v4();

  factory Challenge.fromMap(Map<String, dynamic> map) {
    return Challenge(
      id: map['id'],
      title: map['title'],
      shortDescription: map['shortDescription'] ?? '',
      longDescription: map['longDescription'],
      goalDescription: map['goalDescription'],
      recommendedFor: map['recommendedFor'],
      guideText: map['guideText'],
      type: ChallengeType.values.firstWhere((e) => e.name == map['type']),
      method: ChallengeMethod.values.firstWhere((e) => e.name == map['method']),
      period: ChallengePeriod.values.firstWhere((e) => e.name == map['period']),
      checkMode: ChallengeCheckMode.values.firstWhere((e) => e.name == map['checkMode']),
      durationOptions: map['durationOptions'] != null ? List<int>.from(map['durationOptions']) : null,
      checkCountOptions: map['checkCountOptions'] != null ? List<int>.from(map['checkCountOptions']) : null,
      startDate: map['startDate'] != null ? DateTime.parse(map['startDate']).toLocal() : null,
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']).toLocal() : null,
      totalBooks: map['totalBooks'],
      requiredBooks: map['requiredBooks'] != null
          ? List<Map<String, dynamic>>.from(map['requiredBooks'])
          : [],
      participatingBooks: (map['participatingBooks'] as List?)
          ?.map((e) => BookModel.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      imageUrl: map['imageUrl'],
      badgeImage: map['badgeImage'],
      rewardTitle: map['rewardTitle'],
      goalDisplayText: map['goalDisplayText'],
      periodDisplayText: map['periodDisplayText'],
      isCustom: map['isCustom'] ?? false,
      isPremium: map['isPremium'] ?? false,
      isJoined: map['isJoined'] ?? false,
      isCompleted: map['isCompleted'] ?? false,
      isRepeatable: map['isRepeatable'] ?? false,
      forceBookSelection: map['forceBookSelection'] ?? false,
      stageType: map['stageType'] != null
          ? ChallengeStageType.values.firstWhere((e) => e.name == map['stageType'])
          : ChallengeStageType.single,
      stageDurations: map['stageDurations'] != null
          ? List<int>.from(map['stageDurations'])
          : [],
      attempts: map['attempts'] != null
          ? List<ChallengeAttempt>.from((map['attempts'] as List).map(
            (a) => ChallengeAttempt.fromMap(Map<String, dynamic>.from(a)),
      ))
          : [],
      requiredMinutes: map['requiredMinutes'],
      requiredPages: map['requiredPages'],
      specificBookMode: map['specificBookMode'] != null
          ? SpecificBookMode.values.firstWhere((e) => e.name == map['specificBookMode'])
          : null,
      allowedStartTime: map['allowedStartTime'] != null
          ? TimeOfDay(
        hour: int.parse(map['allowedStartTime'].split(":")[0]),
        minute: int.parse(map['allowedStartTime'].split(":")[1]),
      )
          : null,
      allowedEndTime: map['allowedEndTime'] != null
          ? TimeOfDay(
        hour: int.parse(map['allowedEndTime'].split(":")[0]),
        minute: int.parse(map['allowedEndTime'].split(":")[1]),
      )
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'shortDescription': shortDescription,
    'longDescription': longDescription,
    'goalDescription': goalDescription,
    'recommendedFor': recommendedFor,
    'guideText': guideText,
    'type': type.name,
    'method': method.name,
    'period': period.name,
    'checkMode': checkMode.name,
    'durationOptions': durationOptions,
    'checkCountOptions': checkCountOptions,
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'totalBooks': totalBooks,
    'requiredBooks': requiredBooks ?? [],
    'participatingBooks': participatingBooks?.map((b) => b.toMap()).toList(),
    'imageUrl': imageUrl,
    'badgeImage': badgeImage,
    'rewardTitle': rewardTitle,
    'goalDisplayText': goalDisplayText,
    'periodDisplayText': periodDisplayText,
    'isCustom': isCustom,
    'isPremium': isPremium,
    'isJoined': isJoined,
    'isCompleted': isCompleted,
    'isRepeatable': isRepeatable,
    'forceBookSelection': forceBookSelection,
    'stageType': stageType.name,
    'stageDurations': stageDurations,
    'attempts': attempts.map((e) => e.toMap()).toList(),
    'requiredMinutes': requiredMinutes,
    'requiredPages': requiredPages,
    'specificBookMode': specificBookMode?.name,
    'allowedStartTime': allowedStartTime != null
        ? '${allowedStartTime!.hour}:${allowedStartTime!.minute}'
        : null,
    'allowedEndTime': allowedEndTime != null
        ? '${allowedEndTime!.hour}:${allowedEndTime!.minute}'
        : null,
  };

  Challenge copyWith({
    String? title,
    String? shortDescription,
    String? longDescription,
    String? goalDescription,
    String? recommendedFor,
    String? guideText,
    ChallengeType? type,
    ChallengeMethod? method,
    ChallengePeriod? period,
    ChallengeCheckMode? checkMode,
    List<int>? durationOptions,
    List<int>? checkCountOptions,
    DateTime? startDate,
    DateTime? endDate,
    int? totalBooks,
    List<Map<String, dynamic>>? requiredBooks,
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
    ChallengeStageType? stageType,
    List<int>? stageDurations,
    List<ChallengeAttempt>? attempts,
    int? requiredMinutes,
    int? requiredPages,
    SpecificBookMode? specificBookMode,
    TimeOfDay? allowedStartTime,
    TimeOfDay? allowedEndTime,
  }) {
    return Challenge(
      id: id,
      title: title ?? this.title,
      shortDescription: shortDescription ?? this.shortDescription,
      longDescription: longDescription ?? this.longDescription,
      goalDescription: goalDescription ?? this.goalDescription,
      recommendedFor: recommendedFor ?? this.recommendedFor,
      guideText: guideText ?? this.guideText,
      type: type ?? this.type,
      method: method ?? this.method,
      period: period ?? this.period,
      checkMode: checkMode ?? this.checkMode,
      durationOptions: durationOptions ?? this.durationOptions,
      checkCountOptions: checkCountOptions ?? this.checkCountOptions,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalBooks: totalBooks ?? this.totalBooks,
      requiredBooks: requiredBooks ?? this.requiredBooks,
      participatingBooks: participatingBooks ?? this.participatingBooks,
      imageUrl: imageUrl ?? this.imageUrl,
      badgeImage: badgeImage ?? this.badgeImage,
      rewardTitle: rewardTitle ?? this.rewardTitle,
      goalDisplayText: goalDisplayText ?? this.goalDisplayText,
      periodDisplayText: periodDisplayText ?? this.periodDisplayText,
      isCustom: isCustom ?? this.isCustom,
      isPremium: isPremium ?? this.isPremium,
      isJoined: isJoined ?? this.isJoined,
      isCompleted: isCompleted ?? this.isCompleted,
      isRepeatable: isRepeatable ?? this.isRepeatable,
      forceBookSelection: forceBookSelection ?? this.forceBookSelection,
      stageType: stageType ?? this.stageType,
      stageDurations: stageDurations ?? this.stageDurations,
      attempts: attempts ?? this.attempts,
      requiredMinutes: requiredMinutes ?? this.requiredMinutes,
      requiredPages: requiredPages ?? this.requiredPages,
      specificBookMode: specificBookMode ?? this.specificBookMode,
      allowedStartTime: allowedStartTime ?? this.allowedStartTime,
      allowedEndTime: allowedEndTime ?? this.allowedEndTime,
    );
  }
}
