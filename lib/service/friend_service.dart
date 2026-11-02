import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/utils/book_utils.dart';

class FriendSearchResult {
  final String uid;
  final String nickname;
  final String bio;
  final String profileImageUrl;

  const FriendSearchResult({
    required this.uid,
    required this.nickname,
    required this.bio,
    required this.profileImageUrl,
  });

  factory FriendSearchResult.fromMap(
      Map<String, dynamic> data,
      ) {
    return FriendSearchResult(
      uid: data['uid'] as String? ?? '',
      nickname:
      data['nickname'] as String? ?? '',
      bio:
      data['bio'] as String? ?? '',
      profileImageUrl:
      data['profileImageUrl'] as String? ?? '',
    );
  }
}

class FriendRequestItem {
  final String requestId;
  final String fromUid;
  final String nickname;
  final String bio;
  final String profileImageUrl;

  const FriendRequestItem({
    required this.requestId,
    required this.fromUid,
    required this.nickname,
    required this.bio,
    required this.profileImageUrl,
  });

  factory FriendRequestItem.fromMap(
      Map<String, dynamic> data,
      ) {
    return FriendRequestItem(
      requestId:
      data['requestId'] as String? ?? '',
      fromUid:
      data['fromUid'] as String? ?? '',
      nickname:
      data['nickname'] as String? ?? '',
      bio:
      data['bio'] as String? ?? '',
      profileImageUrl:
      data['profileImageUrl'] as String? ?? '',
    );
  }
}

class FriendItem {
  final String uid;
  final String nickname;
  final String bio;
  final String profileImageUrl;

  const FriendItem({
    required this.uid,
    required this.nickname,
    required this.bio,
    required this.profileImageUrl,
  });

  factory FriendItem.fromMap(
      Map<String, dynamic> data,
      ) {
    return FriendItem(
      uid:
      data['uid'] as String? ?? '',
      nickname:
      data['nickname'] as String? ?? '',
      bio:
      data['bio'] as String? ?? '',
      profileImageUrl:
      data['profileImageUrl'] as String? ?? '',
    );
  }
}

class FriendReadingOverview {
  final int totalReadingMinutes;
  final int totalReadBooks;
  final int totalReadingDays;
  final int longestStreakDays;

  const FriendReadingOverview({
    required this.totalReadingMinutes,
    required this.totalReadBooks,
    required this.totalReadingDays,
    required this.longestStreakDays,
  });

  factory FriendReadingOverview.fromMap(
      Map<String, dynamic> data,
      ) {
    return FriendReadingOverview(
      totalReadingMinutes:
      (data['totalReadingMinutes'] as num?)
          ?.toInt() ??
          0,
      totalReadBooks:
      (data['totalReadBooks'] as num?)
          ?.toInt() ??
          0,
      totalReadingDays:
      (data['totalReadingDays'] as num?)
          ?.toInt() ??
          0,
      longestStreakDays:
      (data['longestStreakDays'] as num?)
          ?.toInt() ??
          0,
    );
  }
}

class FriendBookItem {
  final String id;
  final String title;
  final String author;
  final String imageUrl;
  final String thumbnail;
  final String category;
  final String publisher;

  // YES24 책등 정보
  final String? spineUrl;

  // 책 등록용 기본 도서 정보
  final String? isbn;
  final String? description;
  final String? itemId;
  final int pageCount;

  const FriendBookItem({
    required this.id,
    required this.title,
    required this.author,
    required this.imageUrl,
    required this.thumbnail,
    required this.category,
    required this.publisher,
    this.spineUrl,
    this.isbn,
    this.description,
    this.itemId,
    this.pageCount = 0,
  });

  String get displayImageUrl {
    if (imageUrl.isNotEmpty) {
      return imageUrl;
    }

    return thumbnail;
  }

  factory FriendBookItem.fromMap(
      Map<String, dynamic> data,
      ) {
    String? optionalString(dynamic value) {
      if (value == null) return null;

      final text = value.toString().trim();

      return text.isEmpty ? null : text;
    }

    return FriendBookItem(
      id: data['id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      author: data['author'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      thumbnail: data['thumbnail'] as String? ?? '',
      category: data['category'] as String? ?? '',
      publisher: data['publisher'] as String? ?? '',

      spineUrl: optionalString(data['spineUrl']),

      isbn: optionalString(data['isbn']),

      description: optionalString(data['description']),

      itemId: optionalString(data['itemId']),

      pageCount:
      int.tryParse(
        data['pageCount']?.toString() ?? '',
      ) ??
          0,
    );
  }
}

extension FriendBookRegistration on FriendBookItem {
  BookModel toRegistrationBook() {
    final normalizedIsbn =
    (isbn ?? '')
        .replaceAll(
      RegExp(r'[^0-9Xx]'),
      '',
    )
        .toUpperCase();

    return BookModel(
      // 친구의 Firestore 문서 ID를 그대로 사용하지 않음
      id: normalizedIsbn.isNotEmpty
          ? generateBookId(
        normalizedIsbn,
        title,
        author,
      )
          : null,

      title: title,
      author: author,
      publisher: publisher,
      isbn: normalizedIsbn.isNotEmpty
          ? normalizedIsbn
          : null,
      description: description,
      imageUrl: displayImageUrl,
      itemId: itemId,
      pageCount: pageCount,

      // 책등 정보
      spineUrl: spineUrl,
      spineChecked: spineUrl?.isNotEmpty == true,

      // 친구의 개인 독서기록은 복사하지 않음
      category: 'want',
      pageRead: 0,
      rating: null,
      rereadCount: 0,
      customLibraries: const [],
      startDate: null,
      endDate: null,
      readDate: null,
    );
  }
}

class FriendProfile {
  final String uid;
  final String nickname;
  final String bio;
  final String profileImageUrl;

  final FriendReadingOverview overview;

  final List<FriendBookItem> books;

  const FriendProfile({
    required this.uid,
    required this.nickname,
    required this.bio,
    required this.profileImageUrl,
    required this.overview,
    required this.books,
  });
}

class FriendService {
  FriendService._();

  static final FriendService instance =
  FriendService._();

  final FirebaseFunctions _functions =
  FirebaseFunctions.instanceFor(
    region: 'asia-northeast3',
  );

  List<FriendItem>? _cachedFriends;

  List<FriendItem>? get cachedFriends =>
      _cachedFriends == null
          ? null
          : List.unmodifiable(
        _cachedFriends!,
      );


  /// 닉네임으로 사용자를 정확히 검색한다.
  ///
  /// 검색 결과가 없거나 자기 자신이면 null을 반환한다.
  Future<FriendSearchResult?> searchUserByNickname(
      String nickname,
      ) async {
    final trimmedNickname = nickname.trim();

    if (trimmedNickname.isEmpty) {
      throw ArgumentError(
        '검색할 닉네임을 입력해주세요.',
      );
    }

    final callable =
    _functions.httpsCallable(
      'searchUserByNickname',
    );

    final result = await callable.call({
      'nickname': trimmedNickname,
    });

    final rawData = result.data;

    if (rawData is! Map) {
      throw FirebaseFunctionsException(
        code: 'invalid-response',
        message:
        '사용자 검색 결과가 올바르지 않습니다.',
      );
    }

    final data =
    Map<String, dynamic>.from(rawData);

    if (data['found'] != true) {
      return null;
    }

    final rawUser = data['user'];

    if (rawUser is! Map) {
      throw FirebaseFunctionsException(
        code: 'invalid-response',
        message:
        '사용자 검색 정보가 올바르지 않습니다.',
      );
    }

    final userData =
    Map<String, dynamic>.from(rawUser);

    final user =
    FriendSearchResult.fromMap(userData);

    if (user.uid.isEmpty ||
        user.nickname.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'invalid-response',
        message:
        '사용자 검색 정보가 올바르지 않습니다.',
      );
    }

    return user;
  }

  /// 특정 사용자에게 친구 요청을 보낸다.
  Future<void> sendFriendRequest(
      String toUid,
      ) async {
    final trimmedUid = toUid.trim();

    if (trimmedUid.isEmpty) {
      throw ArgumentError(
        '친구 요청 대상이 올바르지 않습니다.',
      );
    }

    final callable =
    _functions.httpsCallable(
      'sendFriendRequest',
    );

    final result = await callable.call({
      'toUid': trimmedUid,
    });

    final rawData = result.data;

    if (rawData is! Map) {
      throw FirebaseFunctionsException(
        code: 'invalid-response',
        message:
        '친구 요청 결과가 올바르지 않습니다.',
      );
    }

    final data =
    Map<String, dynamic>.from(rawData);

    if (data['success'] != true) {
      throw FirebaseFunctionsException(
        code: 'request-failed',
        message:
        '친구 요청을 보내지 못했습니다.',
      );
    }
  }

  /// 받은 친구 요청을 수락한다.
  Future<void> acceptFriendRequest(
      String requestId,
      ) async {
    final trimmedRequestId = requestId.trim();

    if (trimmedRequestId.isEmpty) {
      throw ArgumentError(
        '친구 요청 정보가 올바르지 않습니다.',
      );
    }

    final callable =
    _functions.httpsCallable(
      'acceptFriendRequest',
    );

    final result = await callable.call({
      'requestId': trimmedRequestId,
    });

    final rawData = result.data;

    if (rawData is! Map) {
      throw FirebaseFunctionsException(
        code: 'invalid-response',
        message:
        '친구 요청 수락 결과가 올바르지 않습니다.',
      );
    }

    final data =
    Map<String, dynamic>.from(rawData);

    if (data['success'] != true) {
      throw FirebaseFunctionsException(
        code: 'request-failed',
        message:
        '친구 요청을 수락하지 못했습니다.',
      );
    }
  }

  /// 받은 친구 요청을 거절한다.
  Future<void> rejectFriendRequest(
      String requestId,
      ) async {
    final trimmedRequestId = requestId.trim();

    if (trimmedRequestId.isEmpty) {
      throw ArgumentError(
        '친구 요청 정보가 올바르지 않습니다.',
      );
    }

    final callable =
    _functions.httpsCallable(
      'rejectFriendRequest',
    );

    final result = await callable.call({
      'requestId': trimmedRequestId,
    });

    final rawData = result.data;

    if (rawData is! Map) {
      throw FirebaseFunctionsException(
        code: 'invalid-response',
        message:
        '친구 요청 거절 결과가 올바르지 않습니다.',
      );
    }

    final data =
    Map<String, dynamic>.from(rawData);

    if (data['success'] != true) {
      throw FirebaseFunctionsException(
        code: 'request-failed',
        message:
        '친구 요청을 거절하지 못했습니다.',
      );
    }
  }

  /// 내가 받은 pending 상태의 친구 요청 목록을 가져온다.
  Future<List<FriendRequestItem>>
  getReceivedFriendRequests() async {
    final callable =
    _functions.httpsCallable(
      'getReceivedFriendRequests',
    );

    final result =
    await callable.call();

    final rawData = result.data;

    if (rawData is! Map) {
      throw FirebaseFunctionsException(
        code: 'invalid-response',
        message:
        '친구 요청 목록 결과가 올바르지 않습니다.',
      );
    }

    final data =
    Map<String, dynamic>.from(rawData);

    if (data['success'] != true) {
      throw FirebaseFunctionsException(
        code: 'request-failed',
        message:
        '친구 요청 목록을 불러오지 못했습니다.',
      );
    }

    final rawRequests =
    data['requests'];

    if (rawRequests is! List) {
      return [];
    }

    return rawRequests
        .whereType<Map>()
        .map(
          (item) =>
          FriendRequestItem.fromMap(
            Map<String, dynamic>.from(item),
          ),
    )
        .where(
          (item) =>
      item.requestId.isNotEmpty &&
          item.fromUid.isNotEmpty &&
          item.nickname.isNotEmpty,
    )
        .toList();
  }

  /// 현재 사용자의 친구 목록을 가져온다.
  Future<List<FriendItem>> getFriends({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cachedFriends != null) {
      return List<FriendItem>.from(
        _cachedFriends!,
      );
    }

    final callable =
    _functions.httpsCallable(
      'getFriends',
    );

    final result =
    await callable.call();

    final rawData =
        result.data;

    if (rawData is! Map) {
      throw FirebaseFunctionsException(
        code:
        'invalid-response',
        message:
        '친구 목록 결과가 올바르지 않습니다.',
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
        '친구 목록을 불러오지 못했습니다.',
      );
    }

    final rawFriends =
    data['friends'];

    if (rawFriends is! List) {
      _cachedFriends =
      <FriendItem>[];

      return [];
    }

    final friends =
    rawFriends
        .whereType<Map>()
        .map(
          (item) =>
          FriendItem.fromMap(
            Map<String, dynamic>.from(
              item,
            ),
          ),
    )
        .where(
          (item) =>
      item.uid.isNotEmpty &&
          item.nickname.isNotEmpty,
    )
        .toList();

    _cachedFriends =
        friends;

    return List<FriendItem>.from(
      friends,
    );
  }

  Future<FriendProfile> getFriendProfile(
      String friendUid,
      ) async {
    final trimmedUid =
    friendUid.trim();

    if (trimmedUid.isEmpty) {
      throw ArgumentError(
        '친구 정보가 올바르지 않습니다.',
      );
    }

    final callable =
    _functions.httpsCallable(
      'getFriendProfile',
    );

    final result =
    await callable.call({
      'friendUid': trimmedUid,
    });

    final rawData =
        result.data;

    if (rawData is! Map) {
      throw FirebaseFunctionsException(
        code: 'invalid-response',
        message:
        '친구 프로필 결과가 올바르지 않습니다.',
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
        '친구 프로필을 불러오지 못했습니다.',
      );
    }

    final rawFriend =
    data['friend'];

    final rawOverview =
    data['overview'];

    final rawBooks =
    data['books'];

    if (rawFriend is! Map ||
        rawOverview is! Map) {
      throw FirebaseFunctionsException(
        code: 'invalid-response',
        message:
        '친구 프로필 정보가 올바르지 않습니다.',
      );
    }

    final friendData =
    Map<String, dynamic>.from(
      rawFriend,
    );

    final overviewData =
    Map<String, dynamic>.from(
      rawOverview,
    );

    final books =
    rawBooks is List
        ? rawBooks
        .whereType<Map>()
        .map(
          (book) =>
          FriendBookItem.fromMap(
            Map<String, dynamic>.from(
              book,
            ),
          ),
    )
        .where(
          (book) =>
      book.id.isNotEmpty &&
          book.title.isNotEmpty,
    )
        .toList()
        : <FriendBookItem>[];

    return FriendProfile(
      uid:
      friendData['uid']
      as String? ??
          '',
      nickname:
      friendData['nickname']
      as String? ??
          '',
      bio:
      friendData['bio']
      as String? ??
          '',
      profileImageUrl:
      friendData[
      'profileImageUrl']
      as String? ??
          '',
      overview:
      FriendReadingOverview
          .fromMap(
        overviewData,
      ),
      books: books,
    );
  }

  /// 친구를 삭제한다.
  Future<void> removeFriend(
      String friendUid,
      ) async {
    final trimmedFriendUid =
    friendUid.trim();

    if (trimmedFriendUid.isEmpty) {
      throw ArgumentError(
        '친구 정보가 올바르지 않습니다.',
      );
    }

    final callable =
    _functions.httpsCallable(
      'removeFriend',
    );

    final result =
    await callable.call({
      'friendUid': trimmedFriendUid,
    });

    final rawData = result.data;

    if (rawData is! Map) {
      throw FirebaseFunctionsException(
        code: 'invalid-response',
        message:
        '친구 삭제 결과가 올바르지 않습니다.',
      );
    }

    final data =
    Map<String, dynamic>.from(rawData);

    if (data['success'] != true) {
      throw FirebaseFunctionsException(
        code: 'request-failed',
        message:
        '친구를 삭제하지 못했습니다.',
      );
    }
  }

}
