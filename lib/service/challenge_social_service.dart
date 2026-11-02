import 'package:cloud_functions/cloud_functions.dart';
import 'package:dayverse_book/model/challenge_group_invitation_model.dart';

class ChallengeSocialService {
  ChallengeSocialService._();

  static final ChallengeSocialService instance =
  ChallengeSocialService._();

  final FirebaseFunctions _functions =
  FirebaseFunctions.instanceFor(
    region: 'asia-northeast3',
  );

  Future<String> createChallengeGroup({
    required String challengeId,
    required String challengeTitle,
    required String ownerAttemptId,
    required DateTime startDate,
    required DateTime? endDate,
    required int? selectedDuration,
    required int? stageIndex,
    required List<Map<String, dynamic>>
    participatingBooks,
    required List<String> invitedFriendUids,
  }) async {
    final trimmedChallengeId =
    challengeId.trim();

    final trimmedTitle =
    challengeTitle.trim();

    final trimmedAttemptId =
    ownerAttemptId.trim();

    final friendUids =
    invitedFriendUids
        .map(
          (uid) => uid.trim(),
    )
        .where(
          (uid) => uid.isNotEmpty,
    )
        .toSet()
        .toList();

    if (trimmedChallengeId.isEmpty) {
      throw ArgumentError(
        '챌린지 정보가 올바르지 않습니다.',
      );
    }

    if (trimmedTitle.isEmpty) {
      throw ArgumentError(
        '챌린지 제목이 올바르지 않습니다.',
      );
    }

    if (trimmedAttemptId.isEmpty) {
      throw ArgumentError(
        '챌린지 도전 정보가 올바르지 않습니다.',
      );
    }

    if (friendUids.isEmpty) {
      throw ArgumentError(
        '초대할 친구가 없습니다.',
      );
    }

    final callable =
    _functions.httpsCallable(
      'createChallengeGroup',
    );

    final result =
    await callable.call({
      'challengeId':
      trimmedChallengeId,

      'challengeTitle':
      trimmedTitle,

      'ownerAttemptId':
      trimmedAttemptId,

      'startDate':
      startDate.toIso8601String(),

      'endDate':
      endDate?.toIso8601String(),

      'selectedDuration':
      selectedDuration,

      'stageIndex':
      stageIndex,

      'participatingBooks':
      participatingBooks,

      'invitedFriendUids':
      friendUids,
    });

    final rawData =
        result.data;

    if (rawData is! Map) {
      throw FirebaseFunctionsException(
        code: 'invalid-response',
        message:
        '챌린지 초대 결과가 올바르지 않습니다.',
      );
    }

    final data =
    Map<String, dynamic>.from(
      rawData,
    );

    if (data['success'] != true) {
      throw FirebaseFunctionsException(
        code: 'request-failed',
        message:
        '챌린지 초대를 보내지 못했습니다.',
      );
    }

    final groupId =
        data['groupId'] as String? ?? '';

    if (groupId.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'invalid-response',
        message:
        '챌린지 그룹 정보가 올바르지 않습니다.',
      );
    }

    return groupId;
  }

  Future<void> acceptChallengeInvite({
    required String groupId,
    required String memberAttemptId,
  }) async {
    final trimmedGroupId =
    groupId.trim();

    final trimmedMemberAttemptId =
    memberAttemptId.trim();

    if (trimmedGroupId.isEmpty) {
      throw ArgumentError(
        '챌린지 그룹 정보가 올바르지 않습니다.',
      );
    }

    if (trimmedMemberAttemptId.isEmpty) {
      throw ArgumentError(
        '챌린지 도전 정보가 올바르지 않습니다.',
      );
    }

    final callable =
    _functions.httpsCallable(
      'acceptChallengeInvite',
    );

    final result =
    await callable.call({
      'groupId':
      trimmedGroupId,

      'memberAttemptId':
      trimmedMemberAttemptId,
    });

    final rawData =
        result.data;

    if (rawData is! Map) {
      throw FirebaseFunctionsException(
        code:
        'invalid-response',
        message:
        '챌린지 초대 수락 결과가 올바르지 않습니다.',
      );
    }

    final data =
    Map<String, dynamic>.from(
      rawData,
    );

    if (data['success'] != true) {
      throw FirebaseFunctionsException(
        code:
        'request-failed',
        message:
        '챌린지 초대를 수락하지 못했습니다.',
      );
    }
  }

  Future<void> rejectChallengeInvite({
    required String groupId,
  }) async {
    final trimmedGroupId =
    groupId.trim();

    if (trimmedGroupId.isEmpty) {
      throw ArgumentError(
        '챌린지 그룹 정보가 올바르지 않습니다.',
      );
    }

    final callable =
    _functions.httpsCallable(
      'rejectChallengeInvite',
    );

    final result =
    await callable.call({
      'groupId':
      trimmedGroupId,
    });

    final rawData =
        result.data;

    if (rawData is! Map) {
      throw FirebaseFunctionsException(
        code: 'invalid-response',
        message:
        '챌린지 초대 거절 결과가 올바르지 않습니다.',
      );
    }

    final data =
    Map<String, dynamic>.from(
      rawData,
    );

    if (data['success'] != true) {
      throw FirebaseFunctionsException(
        code: 'request-failed',
        message:
        '챌린지 초대를 거절하지 못했습니다.',
      );
    }
  }

  Future<ChallengeGroupInvitationModel>
  getChallengeGroupInvitation({
    required String groupId,
  }) async {
    final trimmedGroupId =
    groupId.trim();

    if (trimmedGroupId.isEmpty) {
      throw ArgumentError(
        '챌린지 그룹 정보가 올바르지 않습니다.',
      );
    }

    final callable =
    _functions.httpsCallable(
      'getChallengeGroupInvitation',
    );

    final result =
    await callable.call({
      'groupId':
      trimmedGroupId,
    });

    final rawData =
        result.data;

    if (rawData is! Map) {
      throw FirebaseFunctionsException(
        code:
        'invalid-response',
        message:
        '챌린지 초대 정보가 올바르지 않습니다.',
      );
    }

    final data =
    Map<String, dynamic>.from(
      rawData,
    );

    if (data['success'] != true) {
      throw FirebaseFunctionsException(
        code:
        'request-failed',
        message:
        '챌린지 초대 정보를 불러오지 못했습니다.',
      );
    }

    return ChallengeGroupInvitationModel.fromMap(
      data,
    );
  }

  Future<List<Map<String, dynamic>>>
  getChallengeGroupMembers({
    required String groupId,
    List<String> targetBookIds = const [],
  }) async {
    final trimmedGroupId =
    groupId.trim();

    if (trimmedGroupId.isEmpty) {
      throw ArgumentError(
        '챌린지 그룹 정보가 올바르지 않습니다.',
      );
    }

    final callable =
    _functions.httpsCallable(
      'getChallengeGroupMembers',
    );

    final normalizedTargetBookIds =
    targetBookIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final result =
    await callable.call({
      'groupId':
      trimmedGroupId,

      'targetBookIds':
      normalizedTargetBookIds,
    });

    final rawData =
        result.data;

    if (rawData is! Map) {
      throw FirebaseFunctionsException(
        code:
        'invalid-response',
        message:
        '함께 도전 중인 친구 정보가 올바르지 않습니다.',
      );
    }

    final data =
    Map<String, dynamic>.from(
      rawData,
    );

    if (data['success'] != true) {
      throw FirebaseFunctionsException(
        code:
        'request-failed',
        message:
        '함께 도전 중인 친구 정보를 불러오지 못했습니다.',
      );
    }

    final rawMembers =
    data['members'];

    if (rawMembers is! List) {
      return [];
    }

    return rawMembers
        .whereType<Map>()
        .map(
          (member) =>
      Map<String, dynamic>.from(
        member,
      ),
    )
        .toList();
  }

  Future<String?> getChallengeGroupForAttempt({
    required String challengeId,
    required String attemptId,
  }) async {
    final trimmedChallengeId =
    challengeId.trim();

    final trimmedAttemptId =
    attemptId.trim();

    if (trimmedChallengeId.isEmpty ||
        trimmedAttemptId.isEmpty) {
      throw ArgumentError(
        '챌린지 도전 정보가 올바르지 않습니다.',
      );
    }

    final callable =
    _functions.httpsCallable(
      'getChallengeGroupForAttempt',
    );

    final result =
    await callable.call({
      'challengeId':
      trimmedChallengeId,
      'attemptId':
      trimmedAttemptId,
    });

    final rawData =
        result.data;

    if (rawData is! Map) {
      throw FirebaseFunctionsException(
        code:
        'invalid-response',
        message:
        '챌린지 그룹 정보가 올바르지 않습니다.',
      );
    }

    final data =
    Map<String, dynamic>.from(
      rawData,
    );

    if (data['success'] != true) {
      throw FirebaseFunctionsException(
        code:
        'request-failed',
        message:
        '챌린지 그룹을 확인하지 못했습니다.',
      );
    }

    final groupId =
    data['groupId'];

    if (groupId is! String ||
        groupId.trim().isEmpty) {
      return null;
    }

    return groupId.trim();
  }

}
