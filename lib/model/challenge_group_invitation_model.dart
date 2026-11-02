import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/model/challenge_model.dart';

class ChallengeGroupInvitationModel {
  final String groupId;

  final String challengeId;
  final String challengeTitle;

  final String ownerUid;
  final String ownerAttemptId;

  final DateTime startDate;
  final DateTime? endDate;

  final int? selectedDuration;
  final int? stageIndex;

  final List<BookModel> participatingBooks;

  final List<String> memberUids;
  final List<String> invitedUids;

  final bool isInvited;
  final bool isMember;

  /// 커스텀 챌린지 대응용
  ///
  /// 초대한 사람의 원본 Challenge 데이터.
  /// 시스템 챌린지에서도 내려올 수 있다.
  final Challenge? challenge;

  const ChallengeGroupInvitationModel({
    required this.groupId,
    required this.challengeId,
    required this.challengeTitle,
    required this.ownerUid,
    required this.ownerAttemptId,
    required this.startDate,
    required this.endDate,
    required this.selectedDuration,
    required this.stageIndex,
    required this.participatingBooks,
    required this.memberUids,
    required this.invitedUids,
    required this.isInvited,
    required this.isMember,
    required this.challenge,
  });

  factory ChallengeGroupInvitationModel.fromMap(
      Map<String, dynamic> map,
      ) {
    final rawStartDate =
        map['startDate'] as String? ?? '';

    final parsedStartDate =
    DateTime.tryParse(
      rawStartDate,
    );

    if (parsedStartDate == null) {
      throw const FormatException(
        '챌린지 시작일 정보가 올바르지 않습니다.',
      );
    }

    final rawEndDate =
    map['endDate'] as String?;

    final rawBooks =
    map['participatingBooks'];

    final rawChallenge =
    map['challenge'];

    final challenge =
    rawChallenge is Map
        ? Challenge.fromMap(
      Map<String, dynamic>.from(
        rawChallenge,
      ),
    )
        : null;

    return ChallengeGroupInvitationModel(
      groupId:
      map['groupId'] as String? ?? '',

      challengeId:
      map['challengeId'] as String? ?? '',

      challengeTitle:
      map['challengeTitle']
      as String? ??
          '',

      ownerUid:
      map['ownerUid'] as String? ?? '',

      ownerAttemptId:
      map['ownerAttemptId']
      as String? ??
          '',

      startDate:
      parsedStartDate.toLocal(),

      endDate:
      rawEndDate != null &&
          rawEndDate.isNotEmpty
          ? DateTime.tryParse(
        rawEndDate,
      )?.toLocal()
          : null,

      selectedDuration:
      (map['selectedDuration']
      as num?)
          ?.toInt(),

      stageIndex:
      (map['stageIndex']
      as num?)
          ?.toInt(),

      participatingBooks:
      rawBooks is List
          ? rawBooks
          .whereType<Map>()
          .map(
            (book) =>
            BookModel.fromMap(
              Map<String, dynamic>.from(
                book,
              ),
            ),
      )
          .toList()
          : <BookModel>[],

      memberUids:
      List<String>.from(
        map['memberUids'] ?? [],
      ),

      invitedUids:
      List<String>.from(
        map['invitedUids'] ?? [],
      ),

      isInvited:
      map['isInvited'] as bool? ??
          false,

      isMember:
      map['isMember'] as bool? ??
          false,

      challenge:
      challenge,
    );
  }
}