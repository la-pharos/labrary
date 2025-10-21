import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dayverse_book/model/book_model.dart';

class BookService {
  /// ✅ 책 저장 (BookModel.toFirestore() 사용)
  static Future<void> saveBookToFirestore(Map<String, dynamic> bookData) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      print("❗ [BookService.saveBookToFirestore] 유저 ID 없음, 저장 실패");
      return;
    }

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedBooks')
        .doc(bookData['id']);

    print("📌 [BookService.saveBookToFirestore] 저장 요청: ${bookData['id']} - ${bookData['title']}");

    await docRef.set({
      ...bookData,
      'createdAt': FieldValue.serverTimestamp(), // ✅ 여기 추가
    });

    print("✅ [BookService.saveBookToFirestore] 저장 완료: ${bookData['id']}");
  }

  /// ✅ 책 불러오기 (BookModel.fromFirestore 사용 추천)
  static Future<List<Map<String, dynamic>>> getBooksFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      print("❗ [BookService.getBooksFromFirestore] 유저 ID 없음, 불러오기 실패");
      return [];
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedBooks')
        .orderBy('createdAt', descending: true)
        .get();

    print("📥 [BookService.getBooksFromFirestore] 불러온 책 개수: ${snapshot.docs.length}");
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      data['customLibraries'] ??= [];
      data['pageRead'] ??= 0;
      data['pageCount'] ??= 0;
      return data;
    }).toList();
  }

  /// ✅ 책 삭제
  static Future<void> deleteBookFromFirestore(String bookId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedBooks')
        .doc(bookId)
        .delete();
  }

  /// ✅ 책 업데이트
  static Future<void> updateBookInFirestore(String bookId, Map<String, dynamic> updatedFields) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      print("❗ [BookService.updateBookInFirestore] 유저 ID 없음, 업데이트 실패");
      return;
    }

    if (updatedFields.isEmpty) {
      print("⚠️ [BookService.updateBookInFirestore] 업데이트할 필드 없음 → Firestore update 건너뜀");
      return;
    }

    print("🛠 [BookService.updateBookInFirestore] 업데이트: $bookId - $updatedFields");

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedBooks')
        .doc(bookId)
        .update(updatedFields);
  }

  /// ✅ 기록 추가
  static Future<String> addRecordToFirestore(String bookId, String content, String savedAt) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return "";

    final recordRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('bookRecords')
        .doc();

    await recordRef.set({
      'bookId': bookId,
      'content': content,
      'savedAt': savedAt,
    });

    return recordRef.id;
  }

  /// ✅ 기록 삭제
  static Future<void> deleteRecordFromFirestore(String recordId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final recordRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('bookRecords')
        .doc(recordId);

    await recordRef.delete();
  }

  /// ✅ 기록 업데이트
  static Future<void> updateRecordInFirestore(String recordId, String newContent, String newSavedAt) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final recordRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('bookRecords')
        .doc(recordId);

    await recordRef.update({
      'content': newContent,
      'savedAt': newSavedAt,
    });
  }

  /// ✅ 기록 불러오기
  static Future<List<Map<String, dynamic>>> getRecordsFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('bookRecords')
        .orderBy('savedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['recordId'] = doc.id;
      return data;
    }).toList();
  }

  /// ✅ customLibraries 필드 보강
  static Future<void> initializeCustomLibrariesForOldBooks() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedBooks');

    final snapshot = await collection.get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (!data.containsKey('customLibraries')) {
        await doc.reference.update({'customLibraries': []});
      }
    }
  }

  /// ✅ 고아 기록 삭제
  static Future<void> deleteOrphanBookRecords() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final booksSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedBooks')
        .get();
    final validBookIds = booksSnapshot.docs.map((doc) => doc.id).toSet();

    final recordsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('bookRecords')
        .get();

    for (final doc in recordsSnapshot.docs) {
      final bookId = doc.data()['bookId'];
      if (!validBookIds.contains(bookId)) {
        print("🗑️ 고아 기록 삭제: ${doc.id}");
        await doc.reference.delete();
      }
    }
  }

  static Future<void> initializeReadDateForDoneBooks() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final booksRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedBooks');

    final snapshot = await booksRef.get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['category'] == 'done' && (data['readDate'] == null || data['readDate'].toString().isEmpty)) {
        await doc.reference.update({
          'readDate': DateTime.now().toIso8601String(),
        });
        print("✅ readDate 보정됨: ${data['title']} (${doc.id})");
      }
    }
  }

}
