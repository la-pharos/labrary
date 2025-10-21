import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/service/book_service.dart';
import 'package:dayverse_book/service/challenge_record_service.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/provider/custom_library_provider.dart';
import 'package:dayverse_book/main.dart';
import 'package:dayverse_book/utils/challenge_check_utils.dart';
import 'package:dayverse_book/utils/challenge_progress_utils.dart';


class SavedBooksProvider extends ChangeNotifier {
  List<BookModel> _savedBooks = [];
  final List<Map<String, dynamic>> _bookRecords = [];
  bool _disposed = false;

  void safeNotifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<BookModel> get savedBooks => _savedBooks;
  List<Map<String, dynamic>> get bookRecords => _bookRecords;

  /// 📌 책 추가 또는 갱신
  Future<void> addOrUpdateBook(BookModel book) async {
    final index = _savedBooks.indexWhere((b) => b.id == book.id);
    if (index != -1) {
      _savedBooks[index] = book;
    } else {
      _savedBooks.insert(0, book);
    }
    await BookService.saveBookToFirestore(book.toFirestore());
    safeNotifyListeners(); // ✅ 저장 후에 알림 (라우팅 꼬임 방지 가능성)
  }

  /// 📌 페이지 수 업데이트 (단독)
  Future<void> updatePageRead(String bookId, int newPageRead) async {
    final index = _savedBooks.indexWhere((b) => b.id == bookId);
    if (index != -1) {
      final original = _savedBooks[index];
      final updatedBook = original.copyWith(pageRead: newPageRead);
      _savedBooks[index] = updatedBook;
      safeNotifyListeners();

      // ✅ Firestore에도 반영
      await BookService.updateBookInFirestore(bookId, {'pageRead': newPageRead});

      // ✅ ChallengeProvider에도 반영 (페이지 연동형 챌린지용)
      final challengeProvider = Provider.of<ChallengeProvider>(navigatorKey.currentContext!, listen: false);
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        challengeProvider.syncBookPageReadToChallenge(bookId, newPageRead, userId);
      }
    }
  }

  BookModel getBookById(String id) {
    return _savedBooks.firstWhere((b) => b.id == id);
  }

  /// 📌 페이지 수 + 카테고리 함께 업데이트
  Future<void> updatePageReadAndCategory(String bookId, int newPageRead, String newCategory) async {
    final index = _savedBooks.indexWhere((b) => b.id == bookId);
    if (index != -1) {
      final original = _savedBooks[index];
      final updatedBook = original.copyWith(
        pageRead: newPageRead,
        category: newCategory,
        readDate: newCategory == 'done' && original.readDate == null
            ? DateTime.now()
            : original.readDate,
      );

      _savedBooks[index] = updatedBook;
      safeNotifyListeners();

      final updateData = {
        'pageRead': newPageRead,
        'category': newCategory,
      };
      if (updatedBook.readDate != null) {
        updateData['readDate'] = updatedBook.readDate!.toIso8601String();
      }

      await BookService.updateBookInFirestore(bookId, updateData);
      // ✅ 추가: 챌린지 성공 여부 판단
      final context = navigatorKey.currentContext;
      final user = FirebaseAuth.instance.currentUser;
      if (context != null && user != null) {
        final challengeProvider = Provider.of<ChallengeProvider>(context, listen: false);
        final userId = user.uid;

        // 현재 참여 중인 챌린지들 중에서 이 책이 관련된 챌린지만 대상으로 확인
        for (final challenge in challengeProvider.joinedChallenges) {
          final attempt = challenge.attempts.isNotEmpty ? challenge.attempts.last : null;
          if (attempt == null || attempt.completed) continue;

          final checkType = getChallengeCheckActionType(challenge);
          final record = (checkType == ChallengeCheckActionType.libraryAuto)
              ? _savedBooks
              : (attempt.recordData ?? {});

          // ✅ 성공 기록 저장 (pageAuto + specificBooks 조합에 한함)
          if (challenge.method == ChallengeMethod.specificBooks &&
              checkType == ChallengeCheckActionType.pageAuto &&
              challenge.requiredBooks?.any((b) => b.id == bookId) == true) {
            await ChallengeRecordService.saveSpecificBookCheck(challenge.id, bookId, true);
          }

          final completed = ChallengeProgressUtils.isChallengeCompleted(challenge, record);
          if (completed) {
            await challengeProvider.markChallengeAsCompleted(challenge.id, userId);
          } else {
            await challengeProvider.refreshChallengeStatus(challenge.id, userId: userId, savedBooks: _savedBooks);
          }
        }
      }
    }
  }

  /// 📌 책 삭제
  Future<void> removeBook(String bookId, CustomLibraryProvider customLibraryProvider) async {
    _savedBooks.removeWhere((book) => book.id == bookId);
    _bookRecords.removeWhere((record) => record['bookId'] == bookId);
    customLibraryProvider.removeBookEverywhere(bookId);
    safeNotifyListeners();
    await BookService.deleteBookFromFirestore(bookId);

    final bookRecordIds = (await BookService.getRecordsFromFirestore())
        .where((r) => r['bookId'] == bookId)
        .map((r) => r['recordId'])
        .toList();
    for (final recordId in bookRecordIds) {
      await BookService.deleteRecordFromFirestore(recordId);
    }
  }

  /// 📌 카테고리 업데이트
  Future<void> updateCategory(String bookId, String newCategory) async {
    final index = _savedBooks.indexWhere((b) => b.id == bookId);
    if (index != -1) {
      final original = _savedBooks[index];
      DateTime? updatedReadDate = original.readDate;

      if (newCategory == 'done' && original.readDate == null) {
        updatedReadDate = DateTime.now();
      }

      _savedBooks[index] = original.copyWith(
        category: newCategory,
        readDate: updatedReadDate,
      );

      safeNotifyListeners();

      final data = {'category': newCategory};
      if (updatedReadDate != null) {
        data['readDate'] = updatedReadDate.toIso8601String();
      }

      await BookService.updateBookInFirestore(bookId, data);
    }
  }

  /// 📌 책의 날짜 업데이트 (startDate, endDate)
  Future<void> updateBookDates(String bookId, {DateTime? startDate, DateTime? endDate}) async {
    final index = _savedBooks.indexWhere((b) => b.id == bookId);
    if (index != -1) {
      _savedBooks[index] = _savedBooks[index].copyWith(
        startDate: startDate ?? _savedBooks[index].startDate,
        endDate: endDate ?? _savedBooks[index].endDate,
      );
      safeNotifyListeners();
      final data = <String, dynamic>{};
      if (startDate != null) data['startDate'] = startDate.toIso8601String();
      if (endDate != null) data['endDate'] = endDate.toIso8601String();
      await BookService.updateBookInFirestore(bookId, data);
    }
  }

  /// 📌 라이브러리 할당/해제 (하나의 메서드로 통합)
  Future<void> toggleLibrary(String bookId, String libraryName) async {
    final index = _savedBooks.indexWhere((b) => b.id == bookId);
    if (index != -1) {
      final book = _savedBooks[index];
      if (book.customLibraries.contains(libraryName)) {
        book.customLibraries.remove(libraryName);
      } else {
        book.customLibraries.add(libraryName);
      }
      safeNotifyListeners();
      await BookService.updateBookInFirestore(bookId, {'customLibraries': book.customLibraries});
    }
  }

  /// 📌 전체 삭제
  void clearAll() {
    _savedBooks.clear();
    _bookRecords.clear();
    safeNotifyListeners();
  }

  /// 📌 책 목록 설정 (초기화 등)
  void setBooks(List<dynamic> rawBooks) {
    _savedBooks = [];

    for (final raw in rawBooks) {
      if (raw is BookModel) {
        _savedBooks.add(raw);
      } else if (raw is Map<String, dynamic>) {
        try {
          final model = BookModel.fromMap(raw);
          _savedBooks.add(model);
        } catch (e) {
          debugPrint("❌ BookModel 변환 실패 (setBooks): $e");
        }
      } else {
        debugPrint("❌ 잘못된 book 데이터 타입: ${raw.runtimeType}");
      }
    }

    safeNotifyListeners();
  }

  /// 📌 기록 목록 설정 (초기화 등)
  void setRecords(List<Map<String, dynamic>> records) {
    _bookRecords.clear();
    _bookRecords.addAll(records);
    safeNotifyListeners();
  }

  /// 📌 책별 기록 추가
  Future<void> addRecord(String bookId, String content) async {
    final savedAt = DateTime.now().toIso8601String();
    final recordId = await BookService.addRecordToFirestore(bookId, content, savedAt);
    final record = {"bookId": bookId, "savedAt": savedAt, "content": content, "recordId": recordId};
    _bookRecords.insert(0, record);
    safeNotifyListeners();
  }

  /// 📌 특정 책의 기록 가져오기
  List<Map<String, dynamic>> getRecordsForBook(String bookId) {
    return _bookRecords.where((r) => r["bookId"] == bookId).toList();
  }

  /// 📌 기록 내용 수정
  Future<void> updateRecordByContent(String bookId, String oldSavedAt, String oldContent, String newContent) async {
    final index = _bookRecords.indexWhere((r) =>
    r["bookId"] == bookId && r["savedAt"] == oldSavedAt && r["content"] == oldContent);
    if (index == -1) return;
    final recordId = _bookRecords[index]["recordId"];
    final newSavedAt = DateTime.now().toIso8601String();
    await BookService.updateRecordInFirestore(recordId, newContent, newSavedAt);
    _bookRecords[index]["content"] = newContent;
    _bookRecords[index]["savedAt"] = newSavedAt;
    safeNotifyListeners();
  }

  /// 📌 기록 삭제
  Future<void> deleteRecord(String bookId, String savedAt, String content) async {
    final index = _bookRecords.indexWhere((r) =>
    r["bookId"] == bookId && r["savedAt"] == savedAt && r["content"] == content);
    if (index == -1) return;
    final recordId = _bookRecords[index]["recordId"];
    await BookService.deleteRecordFromFirestore(recordId);
    _bookRecords.removeAt(index);
    safeNotifyListeners();
  }

  /// 📌 새로운 책 등록 시 챌린지 진행률 자동 업데이트
  Future<void> updateChallengeProgressForNewBook(BookModel book) async {
    final context = navigatorKey.currentContext;
    if (context == null || book.endDate == null) return;

    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;
    if (userId == null) return;

    final savedBooks = _savedBooks;
    final challengeProvider = Provider.of<ChallengeProvider>(context, listen: false);
    final List<Challenge> allJoined = challengeProvider.joinedChallenges;

    for (final challenge in allJoined) {
      final attempt = challenge.attempts.isNotEmpty ? challenge.attempts.last : null;
      if (attempt == null || attempt.completed) continue;

      final bookId = book.id;
      final endDate = book.endDate!;
      final checkAction = getChallengeCheckActionType(challenge);
      final method = challenge.method;
      final period = challenge.period;

      // ✅ 조합 분기 처리
      if (method == ChallengeMethod.specificBooks) {
        if (checkAction == ChallengeCheckActionType.libraryAuto) {
          final requiredIds = challenge.requiredBooks?.map((b) => b.id).toSet() ?? {};
          if (requiredIds.contains(bookId)) {
            await ChallengeRecordService.saveSpecificBookCheck(challenge.id, bookId, true);
          }
        }
        // ✅ specificBooks + pageAuto → 기록은 page 입력 시 처리됨, 여기선 패스
      }

      if (method == ChallengeMethod.quantityBased) {
        if (checkAction == ChallengeCheckActionType.libraryAuto) {
          final isInPeriod = period == ChallengePeriod.periodBased &&
              challenge.startDate != null &&
              challenge.endDate != null &&
              endDate.isAfter(challenge.startDate!.subtract(const Duration(days: 1))) &&
              endDate.isBefore(challenge.endDate!.add(const Duration(days: 1)));

          if (isInPeriod) {
            await ChallengeRecordService.incrementCompletedCount(challenge.id);
          } else if (period == ChallengePeriod.daysBased || period == ChallengePeriod.infinite) {
            final dateStr = "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";
            await ChallengeRecordService.updateChallengeRecord(challenge.id, {
              "countChecks.$dateStr": true,
            });
          }
        }

        // ✅ quantityBased + pageAuto → 패스 (페이지 기록 시 처리)
      }

      if (method == ChallengeMethod.countBased) {
        if (checkAction == ChallengeCheckActionType.libraryAuto) {
          final updatedIds = [...attempt.completedBookIds];
          if (!updatedIds.contains(bookId)) {
            updatedIds.add(bookId);
            final updatedAttempt = attempt.copyWith(completedBookIds: updatedIds);
            final updatedChallenge = challenge.copyWith(
              attempts: [
                ...challenge.attempts.sublist(0, challenge.attempts.length - 1),
                updatedAttempt,
              ],
            );
            await challengeProvider.updateChallenge(updatedChallenge, userId);
          }
        }

        // ✅ countBased + timerAuto / pageAuto / manual → 타이머나 페이지 입력 시 처리, 패스
      }

      // ✅ 기타는 무시 (libraryAuto 외엔 기록 안 함)
      // 👉 타이머나 페이지 관련 기록은 ChallengeActionScreen 등에서 처리됨

      // ✅ 진행률 상태 최종 갱신
      await challengeProvider.refreshChallengeStatus(
        challenge.id,
        userId: userId,
        savedBooks: savedBooks,
      );
    }
  }

  /// 📌 커스텀서재에 책 추가
  Future<void> addBookToCustomLibrary(String bookId, String libraryName, {CustomLibraryProvider? customLibraryProvider}) async {
    final index = _savedBooks.indexWhere((b) => b.id == bookId);
    if (index != -1) {
      final book = _savedBooks[index];
      if (!book.customLibraries.contains(libraryName)) {
        book.customLibraries.add(libraryName);
        safeNotifyListeners();

        await BookService.updateBookInFirestore(bookId, {
          'customLibraries': book.customLibraries,
        });

        // ✅ CustomLibraryProvider에도 반영
        if (customLibraryProvider != null) {
          customLibraryProvider.addBookToLibrary(libraryName, bookId);
        }
      }
    }
  }

  /// 📌 커스텀서재에 책 제거
  Future<void> removeBookFromCustomLibrary(
      String bookId,
      String libraryName, {
        required CustomLibraryProvider customLibraryProvider,
      }) async {
    final index = _savedBooks.indexWhere((b) => b.id == bookId);
    if (index != -1) {
      final book = _savedBooks[index];

      if (book.customLibraries.contains(libraryName)) {
        // 🔥 CustomLibraryProvider에서 먼저 제거
        await customLibraryProvider.removeBookFromCustomLibrary(libraryName, bookId);

        // 🧼 로컬 BookModel에서도 제거
        book.customLibraries.remove(libraryName);
        safeNotifyListeners();

        // 🔥 Firestore 업데이트
        await BookService.updateBookInFirestore(bookId, {
          'customLibraries': book.customLibraries,
        });
      }
    }
  }


  /// 📌 Firestore에서 책 목록과 기록을 다시 불러오기
  Future<void> reloadFromFirestore() async {
    final booksMap = await BookService.getBooksFromFirestore();
    final books = booksMap.map((map) => BookModel.fromMap(map)).toList();
    setBooks(books);

    final records = await BookService.getRecordsFromFirestore();
    setRecords(records);
  }

  List<Map<String, dynamic>> getRecentNotes({int limit = 2}) {
    final notes = _bookRecords
        .where((r) => r['content'] != '독서 타이머 기록')
        .toList();

    notes.sort((a, b) => (b['savedAt'] ?? '').compareTo(a['savedAt'] ?? ''));
    return notes.take(limit).toList();
  }

  /// 📌 계정 전환 시 모든 상태 초기화
  void clearData() {
    _savedBooks.clear();
    _bookRecords.clear();
    safeNotifyListeners();
  }
  /// 읽은 책 별점
  void updateBookRating(String bookId, double newRating) {
    final index = _savedBooks.indexWhere((b) => b.id == bookId);
    if (index != -1) {
      final book = _savedBooks[index];
      final updatedBook = book.copyWith(rating: newRating);
      _savedBooks[index] = updatedBook;

      BookService.updateBookInFirestore(bookId, {'rating': newRating});
      safeNotifyListeners();
    }
  }

  Future<void> addReadingDate(String bookId, DateTime date) async {
    final index = _savedBooks.indexWhere((b) => b.id == bookId);
    if (index != -1) {
      final book = _savedBooks[index];
      final currentDates = book.readingDates ?? [];
      final dateOnly = DateTime(date.year, date.month, date.day);

      // 중복 방지
      if (!currentDates.any((d) => d.year == dateOnly.year && d.month == dateOnly.month && d.day == dateOnly.day)) {
        final updatedDates = [...currentDates, dateOnly];
        final updatedBook = book.copyWith(readingDates: updatedDates);
        _savedBooks[index] = updatedBook;
        safeNotifyListeners();

        await BookService.updateBookInFirestore(bookId, {
          'readingDates': updatedDates.map((d) => d.toIso8601String()).toList(),
        });
      }
    }
  }

  /// ✅ 특정 커스텀 서재 이름을 새 이름으로 책들 안에서도 교체
  Future<void> renameCustomLibraryInBooks(String oldName, String newName) async {
    for (int i = 0; i < _savedBooks.length; i++) {
      final book = _savedBooks[i];
      if (book.customLibraries.contains(oldName)) {
        final updatedLibraries = book.customLibraries
            .map((lib) => lib == oldName ? newName : lib)
            .toList();
        final updatedBook = book.copyWith(customLibraries: updatedLibraries);
        _savedBooks[i] = updatedBook;

        // 🔥 Firestore 업데이트
        await BookService.updateBookInFirestore(book.id, {
          'customLibraries': updatedLibraries,
        });
      }
    }
    safeNotifyListeners();
  }

  /// 📌 특정 서재 이름을 가진 모든 책에서 해당 서재 제거 (삭제 시 전용)
  Future<void> removeCustomLibraryEverywhere(String libraryName) async {
    for (int i = 0; i < _savedBooks.length; i++) {
      final book = _savedBooks[i];
      if (book.customLibraries.contains(libraryName)) {
        book.customLibraries.remove(libraryName);
        await BookService.updateBookInFirestore(book.id, {
          'customLibraries': book.customLibraries,
        });
      }
    }
    safeNotifyListeners();
  }

  /// 📌 읽은 책을 별점 높은 순으로 정렬 (null은 0.0으로 처리)
  List<BookModel> get doneBooksSortedByRatingDescending {
    final doneBooks = _savedBooks.where((book) => book.category == 'done').toList();
    doneBooks.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return doneBooks;
  }

  // ✅ 추가: 못 찾으면 null 반환
  BookModel? getBookByIdOrNull(String id) {
    for (final b in _savedBooks) {
      if (b.id == id) return b;
    }
    return null;
  }

}
