import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LibraryService {
  static CollectionReference<Map<String, dynamic>>? _librariesRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('libraries');
  }

  /// ✅ 새 서재 생성
  /// 기존 서재들의 마지막 순서 다음에 추가한다.
  static Future<void> addLibrary(String name) async {
    final librariesRef = _librariesRef();
    if (librariesRef == null) return;

    final snapshot = await librariesRef.get();

    int nextOrder = 0;

    for (final doc in snapshot.docs) {
      final rawOrder = doc.data()['order'];

      if (rawOrder is num) {
        final order = rawOrder.toInt();

        if (order >= nextOrder) {
          nextOrder = order + 1;
        }
      }
    }

    // 기존 문서에 order가 하나도 없는 경우에는
    // 현재 서재 개수 다음 순서로 생성
    if (nextOrder == 0 && snapshot.docs.isNotEmpty) {
      nextOrder = snapshot.docs.length;
    }

    await librariesRef.add({
      'name': name,
      'books': <String>[],
      'createdAt': Timestamp.now(),
      'order': nextOrder,
    });
  }

  /// ✅ 서재 삭제
  static Future<void> deleteLibrary(String libraryId) async {
    final librariesRef = _librariesRef();
    if (librariesRef == null) return;

    await librariesRef.doc(libraryId).delete();
  }

  /// ✅ 서재 전체 불러오기
  /// order가 있으면 order 우선,
  /// 기존 문서처럼 order가 없으면 createdAt 순서를 사용한다.
  static Future<List<Map<String, dynamic>>> getLibraries() async {
    final librariesRef = _librariesRef();
    if (librariesRef == null) return [];

    final snapshot = await librariesRef.get();

    final libraries = snapshot.docs.map((doc) {
      final data = doc.data();

      return <String, dynamic>{
        'id': doc.id,
        'name': data['name'],
        'books': List<String>.from(data['books'] ?? []),
        'createdAt': data['createdAt'],
        'order': data['order'],
      };
    }).toList();

    libraries.sort((a, b) {
      final orderA = a['order'];
      final orderB = b['order'];

      // 둘 다 order가 있으면 order 순
      if (orderA is num && orderB is num) {
        return orderA.toInt().compareTo(orderB.toInt());
      }

      // order가 있는 문서를 우선 배치
      if (orderA is num) return -1;
      if (orderB is num) return 1;

      // 기존 문서는 createdAt 순
      final createdAtA = a['createdAt'];
      final createdAtB = b['createdAt'];

      if (createdAtA is Timestamp && createdAtB is Timestamp) {
        return createdAtA.compareTo(createdAtB);
      }

      return 0;
    });

    return libraries;
  }

  /// ✅ 변경된 서재 순서를 Firestore에 일괄 저장
  static Future<void> saveLibraryOrder(
      List<String> orderedNames,
      ) async {
    final librariesRef = _librariesRef();
    if (librariesRef == null) return;

    final snapshot = await librariesRef.get();

    // 서재 이름 → 문서 ID
    final documentIdByName = <String, String>{};

    for (final doc in snapshot.docs) {
      final name = doc.data()['name'];

      if (name is String && name.isNotEmpty) {
        documentIdByName[name] = doc.id;
      }
    }

    final batch = FirebaseFirestore.instance.batch();

    for (int index = 0; index < orderedNames.length; index++) {
      final name = orderedNames[index];
      final documentId = documentIdByName[name];

      if (documentId == null) continue;

      batch.update(
        librariesRef.doc(documentId),
        {'order': index},
      );
    }

    await batch.commit();
  }

  /// ✅ 서재에 책 추가
  static Future<void> addBookToLibrary(
      String libraryId,
      String bookId,
      ) async {
    final librariesRef = _librariesRef();
    if (librariesRef == null) return;

    await librariesRef.doc(libraryId).update({
      'books': FieldValue.arrayUnion([bookId]),
    });
  }

  /// ✅ 서재에서 책 제거
  static Future<void> removeBookFromLibrary(
      String libraryId,
      String bookId,
      ) async {
    final librariesRef = _librariesRef();
    if (librariesRef == null) return;

    await librariesRef.doc(libraryId).update({
      'books': FieldValue.arrayRemove([bookId]),
    });
  }

  /// ✅ 서재 이름 변경
  static Future<void> updateLibraryName(
      String libraryId,
      String newName,
      ) async {
    final librariesRef = _librariesRef();
    if (librariesRef == null) return;

    await librariesRef.doc(libraryId).update({
      'name': newName,
    });
  }
}