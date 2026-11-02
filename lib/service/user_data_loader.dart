import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/provider/custom_library_provider.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/provider/user_data_provider.dart';
import 'package:dayverse_book/service/book_service.dart';

/// 로그인 또는 회원가입 직후 초기 데이터 로딩
Future<void> loadUserDataAfterLogin({
  required SavedBooksProvider savedBooksProvider,
  required CustomLibraryProvider customLibraryProvider,
  required ChallengeProvider challengeProvider,
  required UserDataProvider userDataProvider,
}) async {
  final uid =
      FirebaseAuth.instance.currentUser?.uid;

  debugPrint(
    '🚀 [UserDataLoader] '
        '유저 데이터 로드 시작 - UID: $uid',
  );

  if (uid == null) {
    debugPrint(
      '❌ 유저 ID가 null입니다. '
          '데이터 로드 중단',
    );

    userDataProvider.markAsLoaded();
    return;
  }

  try {
    // =====================================================
    // 1. 독립적인 초기 데이터 요청 동시 시작
    // =====================================================

    final booksFuture =
    BookService.getBooksFromFirestore();

    final recordsFuture =
    BookService.getRecordsFromFirestore();

    final librariesFuture =
    customLibraryProvider.hasListeners
        ? customLibraryProvider.fetchLibraries()
        : Future<void>.value();

    final challengesFuture =
    challengeProvider.loadChallengesFromFirestore(
      uid,
    );

    // =====================================================
    // 2. 책 + 기록
    // =====================================================

    final results = await Future.wait([
      booksFuture,
      recordsFuture,
    ]);

    final rawBooks =
    results[0] as List<Map<String, dynamic>>;

    final records =
    results[1] as List<Map<String, dynamic>>;

    final bookModels = rawBooks
        .map(
          (raw) => BookModel.fromMap(raw),
    )
        .toList();

    savedBooksProvider.clearData();

    savedBooksProvider.setBooks(
      bookModels,
    );

    savedBooksProvider.setRecords(
      records,
    );

    // =====================================================
    // 3. 서재 + 챌린지 기본 데이터 완료 대기
    // =====================================================

    await Future.wait([
      librariesFuture,
      challengesFuture,
    ]);

    // =====================================================
    // 4. 구독 상태 listener 먼저 시작
    //
    // 첫 snapshot 도착 시 UserDataProvider.isLoaded = true
    // → UserDataGate가 풀리면서 Home 진입 가능
    // =====================================================

    await userDataProvider
        .startSubscriptionListener();

    debugPrint(
      '✅ [UserDataLoader] '
          '기본 데이터 로드 완료',
    );

    // =====================================================
    // 5. 챌린지 상태 갱신은 Home 진입을 막지 않도록
    //    백그라운드에서 처리
    // =====================================================

    unawaited(
      _refreshChallengesAfterStartup(
        challengeProvider:
        challengeProvider,
        bookModels:
        bookModels,
        uid:
        uid,
      ),
    );
  } catch (e, stack) {
    debugPrint(
      '🔥 [UserDataLoader] '
          '데이터 로드 중 오류 발생: $e',
    );

    debugPrint(
      '🔥 [UserDataLoader] '
          '스택트레이스: $stack',
    );

    // 초기 데이터 일부가 실패하더라도
    // 로딩 화면에 영원히 갇히지는 않도록 처리
    userDataProvider.markAsLoaded();
  }
}

Future<void> _refreshChallengesAfterStartup({
  required ChallengeProvider challengeProvider,
  required List<BookModel> bookModels,
  required String uid,
}) async {
  try {
    challengeProvider
        .syncPageReadFromBooks(
      bookModels,
    );

    await challengeProvider
        .refreshAllStatuses(
      savedBooks: bookModels,
      userId: uid,
    );

    debugPrint(
      '✅ [UserDataLoader] '
          '백그라운드 챌린지 갱신 완료',
    );
  } catch (e, stack) {
    debugPrint(
      '⚠️ [UserDataLoader] '
          '백그라운드 챌린지 갱신 실패: $e',
    );

    debugPrint(
      '⚠️ [UserDataLoader] '
          '스택트레이스: $stack',
    );
  }
}