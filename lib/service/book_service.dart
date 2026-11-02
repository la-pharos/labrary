import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/model/memo_model.dart';

class BookService {

  /// ✅ 책 저장 (BookModel.toFirestore() 사용)
  static Future<void> saveBookToFirestore(
      Map<String, dynamic> bookData,
      ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw StateError('로그인 정보를 찾을 수 없습니다.');
    }

    final bookId = bookData['id']?.toString();

    if (bookId == null || bookId.trim().isEmpty) {
      throw ArgumentError('저장할 책의 ID가 없습니다.');
    }

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedBooks')
        .doc(bookId);

    print(
      "📌 [BookService.saveBookToFirestore] "
          "저장 요청: $bookId - ${bookData['title']}",
    );

    final snapshot = await docRef.get();

    await docRef.set({
      ...bookData,
      if (!snapshot.exists)
        'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print(
      "✅ [BookService.saveBookToFirestore] 저장 완료: $bookId",
    );
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
  static Future<void> updateBookInFirestore(
      String bookId,
      Map<String, dynamic> updatedFields,
      ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw StateError('로그인 정보를 찾을 수 없습니다.');
    }

    if (updatedFields.isEmpty) {
      return;
    }

    print(
      "🛠 [BookService.updateBookInFirestore] "
          "업데이트: $bookId - $updatedFields",
    );

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedBooks')
        .doc(bookId)
        .update({
      ...updatedFields,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

  /// 메모 추가
  static Future<MemoModel> addMemoToFirestore({
    required String bookId,
    required String content,
    List<String> imageUrls = const [],
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw StateError('로그인 정보를 찾을 수 없습니다.');
    }

    final trimmedContent = content.trim();

    if (trimmedContent.isEmpty && imageUrls.isEmpty) {
      throw ArgumentError('메모 내용 또는 이미지가 필요합니다.');
    }

    final recordRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('bookRecords')
        .doc();

    final now = DateTime.now();

    final memo = MemoModel(
      id: recordRef.id,
      bookId: bookId,
      content: trimmedContent,
      imageUrls: List<String>.from(imageUrls),
      createdAt: now,
      updatedAt: now,
    );

    await recordRef.set({
      ...memo.toMap(),

      // 새 데이터의 종류를 명확하게 구분
      'type': 'memo',

      // 기존 화면과 기존 정렬 코드 호환용
      'savedAt': now.toIso8601String(),
    });

    return memo;
  }

  /// 메모 수정
  static Future<MemoModel> updateMemoInFirestore({
    required MemoModel memo,
    required String content,
    List<String>? imageUrls,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw StateError('로그인 정보를 찾을 수 없습니다.');
    }

    if (memo.id.trim().isEmpty) {
      throw ArgumentError('수정할 메모 ID가 없습니다.');
    }

    final trimmedContent = content.trim();
    final updatedImageUrls =
        imageUrls ?? memo.imageUrls;

    if (trimmedContent.isEmpty &&
        updatedImageUrls.isEmpty) {
      throw ArgumentError('메모 내용 또는 이미지가 필요합니다.');
    }

    final now = DateTime.now();

    final updatedMemo = memo.copyWith(
      content: trimmedContent,
      imageUrls: List<String>.from(
        updatedImageUrls,
      ),
      updatedAt: now,
    );

    final recordRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('bookRecords')
        .doc(memo.id);

    await recordRef.update({
      'content': updatedMemo.content,
      'imageUrls': updatedMemo.imageUrls,
      'updatedAt': Timestamp.fromDate(now),
      'type': 'memo',

      // 기존 화면에서는 수정된 메모를 최신으로 표시
      'savedAt': now.toIso8601String(),
    });

    return updatedMemo;
  }

  /// 메모 삭제
  static Future<void> deleteMemoFromFirestore(
      String memoId,
      ) async {
    if (memoId.trim().isEmpty) {
      throw ArgumentError('삭제할 메모 ID가 없습니다.');
    }

    await deleteRecordFromFirestore(memoId);
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
      'updatedAt': Timestamp.fromDate(
        DateTime.tryParse(newSavedAt) ??
            DateTime.now(),
      ),
    });
  }

  /// ✅ 기록 불러오기
  static Future<List<Map<String, dynamic>>>
  getRecordsFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return [];
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('bookRecords')
        .orderBy(
      'savedAt',
      descending: true,
    )
        .get();

    return snapshot.docs.map((doc) {
      final data =
      Map<String, dynamic>.from(doc.data());

      data['recordId'] = doc.id;
      data['id'] ??= doc.id;
      data['imageUrls'] ??= <String>[];

      // 새 날짜 필드가 없는 기존 기록 호환
      data['createdAt'] ??= data['savedAt'];
      data['updatedAt'] ??=
          data['createdAt'] ?? data['savedAt'];

      // 기존 데이터의 type 보정
      data['type'] ??=
      data['content'] == '독서 타이머 기록'
          ? 'timer'
          : 'memo';

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
