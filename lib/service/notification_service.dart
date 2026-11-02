import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppNotificationItem {
  final String id;
  final String type;

  final String title;
  final String body;

  final String actorUid;
  final String actorNickname;

  final String referenceId;

  final String challengeId;

  final bool isRead;
  final DateTime? createdAt;

  const AppNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.actorUid,
    required this.actorNickname,
    required this.referenceId,
    required this.challengeId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotificationItem.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? {};

    final rawCreatedAt = data['createdAt'];

    DateTime? createdAt;

    if (rawCreatedAt is Timestamp) {
      createdAt = rawCreatedAt.toDate();
    }

    return AppNotificationItem(
      id: doc.id,
      type: data['type'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      actorUid:
      data['actorUid'] as String? ?? '',
      actorNickname:
      data['actorNickname'] as String? ?? '',
      referenceId:
      data['referenceId'] as String? ?? '',
      isRead:
      data['isRead'] as bool? ?? false,
      createdAt: createdAt,
      challengeId:
      data['challengeId'] as String? ?? '',
    );
  }
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance =
  NotificationService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  String? get _currentUid =>
      FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>?
  _notificationCollection() {
    final uid = _currentUid;

    if (uid == null || uid.isEmpty) {
      return null;
    }

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications');
  }

  /// 현재 사용자의 알림 목록을 가져온다.
  Future<List<AppNotificationItem>>
  getNotifications() async {
    final collection =
    _notificationCollection();

    if (collection == null) {
      return [];
    }

    final snapshot = await collection
        .orderBy(
      'createdAt',
      descending: true,
    )
        .limit(100)
        .get();

    return snapshot.docs
        .map(
      AppNotificationItem.fromDocument,
    )
        .toList();
  }

  /// 현재 사용자의 알림을 실시간으로 구독한다.
  Stream<List<AppNotificationItem>>
  watchNotifications() {
    final collection =
    _notificationCollection();

    if (collection == null) {
      return Stream.value([]);
    }

    return collection
        .orderBy(
      'createdAt',
      descending: true,
    )
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(
        AppNotificationItem.fromDocument,
      )
          .toList(),
    );
  }

  /// 읽지 않은 알림 개수를 가져온다.
  Future<int> getUnreadCount() async {
    final collection =
    _notificationCollection();

    if (collection == null) {
      return 0;
    }

    final snapshot = await collection
        .where(
      'isRead',
      isEqualTo: false,
    )
        .get();

    return snapshot.docs.length;
  }

  /// 읽지 않은 알림 개수를 실시간으로 구독한다.
  Stream<int> watchUnreadCount() {
    final collection =
    _notificationCollection();

    if (collection == null) {
      return Stream.value(0);
    }

    return collection
        .where(
      'isRead',
      isEqualTo: false,
    )
        .snapshots()
        .map(
          (snapshot) =>
      snapshot.docs.length,
    );
  }

  /// 특정 알림을 읽음 처리한다.
  Future<void> markAsRead(
      String notificationId,
      ) async {
    final id = notificationId.trim();

    if (id.isEmpty) {
      return;
    }

    final collection =
    _notificationCollection();

    if (collection == null) {
      return;
    }

    await collection.doc(id).update({
      'isRead': true,
      'readAt':
      FieldValue.serverTimestamp(),
    });
  }

  /// 모든 알림을 읽음 처리한다.
  Future<void> markAllAsRead() async {
    final collection =
    _notificationCollection();

    if (collection == null) {
      return;
    }

    final snapshot = await collection
        .where(
      'isRead',
      isEqualTo: false,
    )
        .get();

    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      batch.update(
        doc.reference,
        {
          'isRead': true,
          'readAt':
          FieldValue.serverTimestamp(),
        },
      );
    }

    await batch.commit();
  }
}
