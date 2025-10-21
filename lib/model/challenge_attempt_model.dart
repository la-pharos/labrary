import 'package:uuid/uuid.dart';
import 'package:dayverse_book/model/book_model.dart';

class ChallengeAttempt {
  final String attemptId;
  final DateTime startDate;
  final DateTime? endDate;
  final List<String> completedBookIds;
  final bool isSuccessful;
  final bool completed;
  bool get isCompleted => completed;

  final List<BookModel>? participatedBooks;
  final Map<String, dynamic>? recordData;

  final int? stageIndex;
  final int? selectedDuration;

  ChallengeAttempt({
    String? attemptId,
    required this.startDate,
    this.endDate,
    this.completedBookIds = const [],
    this.isSuccessful = false,
    this.completed = false,
    this.participatedBooks,
    this.stageIndex,
    this.selectedDuration,
    this.recordData,
  }) : attemptId = attemptId ?? const Uuid().v4();

  bool get isStageAttempt => stageIndex != null;

  factory ChallengeAttempt.fromMap(Map<String, dynamic> map) {
    return ChallengeAttempt(
      attemptId: map['attemptId'] ?? const Uuid().v4(),
      startDate: DateTime.parse(map['startDate']).toLocal(),
      endDate: map['endDate'] != null ? DateTime.tryParse(map['endDate'])?.toLocal() : null,
      completedBookIds: List<String>.from(map['completedBookIds'] ?? []),
      isSuccessful: map['isSuccessful'] ?? false,
      completed: map['completed'] ?? false, // ✅ 수정: 기본값 false
      participatedBooks: map['participatedBooks'] != null
          ? List<BookModel>.from(
          (map['participatedBooks'] as List).map((e) => BookModel.fromMap(e)))
          : null,
      stageIndex: map['stageIndex'],
      selectedDuration: map['selectedDuration'],
      recordData: map['recordData'] is Map
          ? Map<String, dynamic>.from(map['recordData'])
          : null, // ✅ 타입 안전성 강화
    );
  }

  Map<String, dynamic> toMap() => {
    'attemptId': attemptId,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'completedBookIds': completedBookIds,
    'isSuccessful': isSuccessful,
    'completed': completed,
    'participatedBooks': participatedBooks?.map((b) => b.toMap()).toList(),
    'stageIndex': stageIndex,
    'selectedDuration': selectedDuration,
    'recordData': recordData,
  };

  ChallengeAttempt copyWith({
    String? attemptId,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? completedBookIds,
    bool? isSuccessful,
    bool? completed,
    List<BookModel>? participatedBooks,
    int? stageIndex,
    int? selectedDuration,
    Map<String, dynamic>? recordData,
  }) {
    return ChallengeAttempt(
      attemptId: attemptId ?? this.attemptId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      completedBookIds: completedBookIds ?? this.completedBookIds,
      isSuccessful: isSuccessful ?? this.isSuccessful,
      completed: completed ?? this.completed,
      participatedBooks: participatedBooks ?? this.participatedBooks,
      stageIndex: stageIndex ?? this.stageIndex,
      selectedDuration: selectedDuration ?? this.selectedDuration,
      recordData: recordData ?? this.recordData,
    );
  }


}
