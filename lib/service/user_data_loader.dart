import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/provider/custom_library_provider.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/provider/user_data_provider.dart';
import 'package:dayverse_book/service/book_service.dart';
import 'package:dayverse_book/service/user_service.dart';

/// 로그인 또는 회원가입 직후 초기 데이터 로딩
Future<void> loadUserDataAfterLogin({
  required SavedBooksProvider savedBooksProvider,
  required CustomLibraryProvider customLibraryProvider,
  required ChallengeProvider challengeProvider,
  required UserDataProvider userDataProvider, // ✅ 추가
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  print("🚀 [UserDataLoader] 유저 데이터 로드 시작 - UID: $uid");

  if (uid == null) {
    debugPrint("❌ 유저 ID가 null입니다. 데이터 로드 중단");
    return;
  }

  try {
    await BookService.initializeCustomLibrariesForOldBooks();

    // 1. 책 및 기록 로드
    final rawBooks = await BookService.getBooksFromFirestore();
    final bookModels = rawBooks.map((raw) => BookModel.fromMap(raw)).toList();
    final records = await BookService.getRecordsFromFirestore();

    savedBooksProvider.clearData();
    savedBooksProvider.setBooks(bookModels);
    savedBooksProvider.setRecords(records);

    // 2. 커스텀 서재 로드
    if (customLibraryProvider.hasListeners) {
      await customLibraryProvider.fetchLibraries();
    } else {
      debugPrint("⚠️ CustomLibraryProvider는 이미 dispose된 상태입니다. fetch 생략.");
    }

    // 3. 챌린지 로드
    await challengeProvider.loadChallengesFromFirestore(uid);
    challengeProvider.syncPageReadFromBooks(bookModels);
    await challengeProvider.refreshAllStatuses(
      savedBooks: bookModels,
      userId: uid,
    );

    // ✅ 4. 유저 구독 정보 로드
    final profile = await UserService().getUserProfile(uid);
    final isPremium = profile?.isPremium ?? false;
    userDataProvider.setSubscribed(isPremium); // ✅ 구독 여부 반영

    print("✅ [UserDataLoader] 유저 데이터 로드 완료");
  } catch (e, stack) {
    debugPrint("🔥 데이터 로드 중 오류 발생: $e");
    debugPrint("🔥 스택트레이스: $stack");
  }
}
