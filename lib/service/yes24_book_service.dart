
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class Yes24BookResult {
  final bool found;
  final String? itemId;
  final String? title;
  final String? author;
  final String? publisher;
  final String? isbn13;
  final String? spineUrl;

// YES24 앞표지와 책 소개
  final String? coverUrl;
  final String? description;

  // YES24 도서 페이지수
  final int pageCount;

  const Yes24BookResult({
    required this.found,
    this.itemId,
    this.title,
    this.author,
    this.publisher,
    this.isbn13,
    this.spineUrl,
    this.coverUrl,
    this.description,
    this.pageCount = 0,
  });

  factory Yes24BookResult.fromMap(
      Map<String, dynamic> map,
      ) {
    final rawPageCount = map['pageCount'];
    final parsedPageCount = int.tryParse(
      rawPageCount?.toString() ?? '',
    ) ?? 0;

    return Yes24BookResult(
      found: map['found'] == true,
      itemId: map['itemId']?.toString(),
      title: map['title']?.toString(),
      author: map['author']?.toString(),
      publisher: map['publisher']?.toString(),
      isbn13: map['isbn13']?.toString(),
      spineUrl: map['spineUrl']?.toString(),
      coverUrl: map['coverUrl']?.toString(),
      description: map['description']?.toString(),

      // 페이지수가 없다면 0으로 처리
      pageCount: parsedPageCount > 0
          ? parsedPageCount
          : 0,
    );
  }
}

class Yes24BookService {
  static final FirebaseFunctions _functions =
  FirebaseFunctions.instanceFor(
    region: 'asia-northeast3',
  );

  static Future<Yes24BookResult> findByIsbn(
      String isbn,
      ) async {
    final normalizedIsbn = isbn
        .replaceAll(
      RegExp(r'[^0-9Xx]'),
      '',
    )
        .trim();

    if (normalizedIsbn.isEmpty) {
      return const Yes24BookResult(
        found: false,
      );
    }

    final callable = _functions.httpsCallable(
      'getYes24BookByIsbn',
    );

    final response = await callable.call({
      'isbn': normalizedIsbn,
    });

    final data = Map<String, dynamic>.from(
      response.data as Map,
    );

    return Yes24BookResult.fromMap(data);
  }


  static Future<List<Map<String, dynamic>>> searchBooks(
      String query, {
        int maxResults = 15,
      }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final callable = _functions.httpsCallable(
      'searchYes24Books',
    );

    final user = FirebaseAuth.instance.currentUser;

    debugPrint('YES24 Firebase 사용자 존재: ${user != null}');
    debugPrint('YES24 Firebase 프로젝트: ${Firebase.app().options.projectId}');

    if (user != null) {
      try {
        await user.getIdToken(true);
        debugPrint('YES24 Firebase ID 토큰 갱신 성공');
      } catch (e) {
        debugPrint('YES24 Firebase ID 토큰 갱신 실패: $e');
      }
    }

    final response = await callable.call({
      'query': query.trim(),
      'maxResults': maxResults,
    });

    final data = Map<String, dynamic>.from(
      response.data as Map,
    );

    if (data['success'] != true) {
      return [];
    }

    final rawBooks = data['books'];

    if (rawBooks is! List) {
      return [];
    }

    return rawBooks
        .whereType<Map>()
        .map(
          (book) => Map<String, dynamic>.from(book),
    )
        .toList();
  }


  /// YES24 종합 베스트셀러 조회
  static Future<List<Map<String, dynamic>>> fetchBestsellers() async {
    final callable = _functions.httpsCallable(
      'getYes24Bestsellers',
    );

    final response = await callable.call();

    final data = Map<String, dynamic>.from(
      response.data as Map,
    );

    if (data['success'] != true) {
      return [];
    }

    final rawBooks = data['books'];

    if (rawBooks is! List) {
      return [];
    }

    return rawBooks
        .whereType<Map>()
        .map((book) => Map<String, dynamic>.from(book))
        .toList();
  }

}
