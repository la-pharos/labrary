import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/service/library_service.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/provider/user_data_provider.dart';


class CustomLibraryProvider extends ChangeNotifier {
  final Map<String, List<String>> _libraries = {};
  final List<String> _orderedNames = [];

  bool _isLibraryBeingCreated = false;
  bool get isLibraryBeingCreated => _isLibraryBeingCreated;

  Map<String, List<String>> get libraries => _libraries;
  List<String> get orderedLibraryNames => _orderedNames;

  String? _recentCreated;
  String? get recentCreated => _recentCreated;
  void clearRecentCreated() => _recentCreated = null;

  /// ✅ Firestore로부터 커스텀 서재 불러오기
  Future<void> fetchLibraries() async {
    final libraries = await LibraryService.getLibraries();
    _libraries.clear();
    _orderedNames.clear();

    for (final lib in libraries) {
      final name = lib['name'];
      final books = List<String>.from(lib['books'] ?? []); // ✅ 책 리스트도 불러오기
      _libraries[name] = books;
      _orderedNames.add(name);
    }
    notifyListeners();
  }

  /// ✅ Firestore에 새 서재 추가
  Future<void> createLibrary(String name, {required BuildContext context}) async {
    final userData = context.read<UserDataProvider>();
    final isSubscribed = userData.isSubscribed;

    final trimmed = name.trim();

    // ✅ 일반 유저는 3개까지만 허용
    if (!isSubscribed && _orderedNames.length >= 3) {
      throw Exception('일반 사용자는 최대 3개의 서재만 생성할 수 있습니다.');
    }

    if (!_libraries.containsKey(trimmed)) {
      _isLibraryBeingCreated = true;
      notifyListeners();

      await LibraryService.addLibrary(trimmed); // 🔥 Firestore 저장
      await fetchLibraries(); // 다시 불러오기

      _recentCreated = trimmed;
      _isLibraryBeingCreated = false;
      notifyListeners();
    }
  }

  /// ✅ Firestore에서 서재 삭제
  Future<void> deleteLibrary(String libraryId, SavedBooksProvider savedBooksProvider) async {
    final nameToDelete = await _getLibraryNameById(libraryId);
    if (nameToDelete == null) return;

    await LibraryService.deleteLibrary(libraryId); // Firestore에서 서재 삭제
    await savedBooksProvider.removeCustomLibraryEverywhere(nameToDelete); // 🔥 모든 책에서 해당 서재 이름 제거

    await fetchLibraries(); // 다시 동기화
    notifyListeners();
  }

  /// ✅ Firestore + fetch: 서재 이름 변경 후 상태 동기화
  Future<void> renameLibrary(String oldName, String newName) async {
    final trimmedNew = newName.trim();
    if (_libraries.containsKey(oldName) && !_libraries.containsKey(trimmedNew)) {
      final libraryId = await _findLibraryIdByName(oldName);
      if (libraryId != null) {
        await LibraryService.updateLibraryName(libraryId, trimmedNew); // 🔥 이름 변경
      }

      await fetchLibraries(); // 🔄 Firestore → 최신 상태 반영
      notifyListeners(); // 📣 UI 갱신
    }
  }

  /// ✅ 로컬: 서재 순서 변경
  void reorderLibrary(int oldIndex, int newIndex) {
    final item = _orderedNames.removeAt(oldIndex);
    _orderedNames.insert(newIndex, item);
    notifyListeners();
  }

  /// ✅ Firestore + 로컬: 서재에 책 추가
  Future<void> addBookToLibrary(String libraryName, String bookId) async {
    final list = _libraries[libraryName];
    if (list != null && !list.contains(bookId)) {
      list.add(bookId);
      notifyListeners();

      // 🔥 Firestore에도 동기화
      final libraryId = await _findLibraryIdByName(libraryName);
      if (libraryId != null) {
        await LibraryService.addBookToLibrary(libraryId, bookId);
      }
    }
  }

  /// ✅ Firestore + 로컬: 서재에서 책 제거
  Future<void> removeBookFromCustomLibrary(String libraryName, String bookId) async {
    final list = _libraries[libraryName];
    if (list != null && list.contains(bookId)) {
      list.remove(bookId);

      // Firestore에서도 제거
      final libraryId = await _findLibraryIdByName(libraryName);
      if (libraryId != null) {
        await LibraryService.removeBookFromLibrary(libraryId, bookId);
      }

      // 🔁 재로딩 이후 다시 알림!
      await fetchLibraries();
      notifyListeners(); // 🔥 여기 꼭 다시 호출!
    }
  }

  /// 특정 서재에 이 책이 있는지
  bool isBookInLibrary(String libraryName, String bookId) {
    return _libraries[libraryName]?.contains(bookId) ?? false;
  }

  /// 이 책이 들어있는 모든 서재 목록
  List<String> getLibrariesContainingBook(String bookId) {
    return _libraries.entries
        .where((entry) => entry.value.contains(bookId))
        .map((entry) => entry.key)
        .toList();
  }

  /// 이 책이 어떤 서재든 들어있나?
  bool isBookInAnyLibrary(String bookId) {
    return _libraries.values.any((list) => list.contains(bookId));
  }

  /// ✅ 전체 초기화 (로그아웃 시)
  void clearLibraries() {
    _libraries.clear();
    _orderedNames.clear();
    _recentCreated = null;
    notifyListeners();
  }

  /// 📌 내부용: 서재 이름 → Firestore 문서 ID 찾아오기
  Future<String?> _findLibraryIdByName(String libraryName) async {
    final libraries = await LibraryService.getLibraries();
    final library = libraries.firstWhere(
          (lib) => lib['name'] == libraryName,
      orElse: () => {},
    );
    return library['id'];
  }

  /// ✅ 특정 책을 모든 서재에서 제거하는 함수
  void removeBookEverywhere(String bookId) {
    for (final library in _libraries.values) {
      library.remove(bookId);
    }
    notifyListeners();
  }

  Future<String?> findLibraryIdByName(String libraryName) async {
    return await _findLibraryIdByName(libraryName);
  }

  Future<String?> _getLibraryNameById(String libraryId) async {
    final libraries = await LibraryService.getLibraries();
    final target = libraries.firstWhere(
          (lib) => lib['id'] == libraryId,
      orElse: () => {},
    );
    return target['name'];
  }

}
