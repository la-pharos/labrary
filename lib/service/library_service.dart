import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LibraryService {
  /// ✅ 새 서재 생성 (초기 책 리스트는 비워둠)
  static Future<void> addLibrary(String name) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final librariesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('libraries');

    await librariesRef.add({
      'name': name,
      'books': [], // ✅ 책 리스트 추가
      'createdAt': Timestamp.now(),
    });
  }

  /// ✅ 서재 삭제
  static Future<void> deleteLibrary(String libraryId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('libraries')
        .doc(libraryId)
        .delete();
  }

  /// ✅ 서재 전체 불러오기
  static Future<List<Map<String, dynamic>>> getLibraries() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('libraries')
        .orderBy('createdAt')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'],
        'books': List<String>.from(data['books'] ?? []), // ✅ 책 리스트도 불러오기
        'createdAt': data['createdAt'],
      };
    }).toList();
  }

  /// ✅ 서재에 책 추가
  static Future<void> addBookToLibrary(String libraryId, String bookId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final libraryDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('libraries')
        .doc(libraryId);

    await libraryDoc.update({
      'books': FieldValue.arrayUnion([bookId]),
    });
  }

  /// ✅ 서재에서 책 제거
  static Future<void> removeBookFromLibrary(String libraryId, String bookId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final libraryDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('libraries')
        .doc(libraryId);

    await libraryDoc.update({
      'books': FieldValue.arrayRemove([bookId]),
    });
  }

  static Future<void> updateLibraryName(String libraryId, String newName) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('libraries') // ✅ 여기!
        .doc(libraryId);

    await ref.update({'name': newName});
  }

}
