import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:dayverse_book/model/book_model.dart';

/// 풀 JSON 스키마:
/// {
///   "poolId": "snu_korean_lit",
///   "title": "서울대 권장도서 100 – 한국문학편(16권)",
///   "books": [
///     { "title": "...", "author": "...", "isbn13": "978..." },
///     ...
///   ]
/// }
///
/// 파일 경로 규약(권장):
/// assets/challenges/book_pools/{poolId}.json
///
/// ※ 만약 여러 풀을 한 파일에 몰아 넣었다면 loadPoolEntriesFromIndex(...)를 확장해 쓰면 됨.
class BookPoolEntry {
  final String title;
  final String author;
  final String? isbn;   // BookModel의 isbn에 그대로 매핑
  final String? isbn13; // 입력 파일에 isbn13만 있을 수 있어 보존

  const BookPoolEntry({
    required this.title,
    required this.author,
    this.isbn,
    this.isbn13,
  });

  /// 풀 JSON의 단일 book 오브젝트를 파싱
  factory BookPoolEntry.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] ?? '').toString().trim();
    final author = (json['author'] ?? '').toString().trim();

    // 입력은 isbn 또는 isbn13일 수 있음 → BookModel은 isbn 필드만 쓰므로 우선 매핑
    final String? isbn13 = (json['isbn13'] ?? json['isbn'])?.toString().trim();
    final String? isbn = (json['isbn'] ?? json['isbn13'])?.toString().trim();

    return BookPoolEntry(
      title: title,
      author: author,
      isbn: (isbn != null && isbn.isNotEmpty) ? isbn : null,
      isbn13: (isbn13 != null && isbn13.isNotEmpty) ? isbn13 : null,
    );
  }
}

class BookPoolLoader {
  BookPoolLoader._();

  static final Map<String, List<BookPoolEntry>> _cache = {};

  /// 권장 경로: assets/challenges/book_pools/{poolId}.json
  static String _defaultPoolPath(String poolId) =>
      'assets/challenges/book_pools/$poolId.json';

  /// 풀을 읽어 BookPoolEntry 리스트로 변환 (캐시 포함)
  static Future<List<BookPoolEntry>> loadPoolEntries(String poolId,
      {String? assetPathOverride}) async {
    if (_cache.containsKey(poolId)) return _cache[poolId]!;

    final path = assetPathOverride ?? _defaultPoolPath(poolId);

    try {
      final raw = await rootBundle.loadString(path);
      final json = jsonDecode(raw);

      // 단일 풀 파일 규약
      if (json is Map<String, dynamic>) {
        // {"poolId": "...", "books": [...]}
        final books = (json['books'] as List? ?? [])
            .map((e) => BookPoolEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList()
            .cast<BookPoolEntry>();

        _cache[poolId] = books;
        return books;
      }

      // 혹시 배열 형태로 여러 풀을 한 파일에 넣은 케이스(비권장)
      if (json is List) {
        // [{poolId,title,books:[...]}, ...] 중 해당 poolId만 추출
        for (final item in json) {
          if (item is Map<String, dynamic>) {
            if ((item['poolId'] ?? '').toString().trim() == poolId) {
              final books = (item['books'] as List? ?? [])
                  .map((e) =>
                  BookPoolEntry.fromJson(
                      Map<String, dynamic>.from(e)))
                  .toList()
                  .cast<BookPoolEntry>();
              _cache[poolId] = books;
              return books;
            }
          }
        }
      }

      // 형식 불일치 시 빈 리스트
      _cache[poolId] = const [];
      return const [];
    } catch (e) {
      // 에셋 미존재/파싱 실패: 빈 리스트 반환 (앱 죽지 않게)
      _cache[poolId] = const [];
      return const [];
    }
  }

  /// 풀을 BookModel 리스트로 변환
  ///
  /// - isbn / isbn13 중 있는 값을 BookModel.isbn으로 매핑
  /// - pageCount는 모르면 0 (기존 ProgressUtils가 0/null을 안전 처리)
  /// - 기타 필드는 기본값
  static Future<List<BookModel>> loadPoolAsBookModels(String poolId,
      {String? assetPathOverride}) async {
    final entries = await loadPoolEntries(poolId,
        assetPathOverride: assetPathOverride);

    return entries.map((e) {
      final isbnForModel = (e.isbn != null && e.isbn!.isNotEmpty)
          ? e.isbn!
          : (e.isbn13 ?? '');

      // BookModel.id 생성 규칙: 기존 유틸 generateBookId(...)를 주로 쓰지만
      // 여기서는 ISBN이 있으면 안정적으로 식별되도록 id를 구성
      final id = (isbnForModel.isNotEmpty)
          ? 'isbn_$isbnForModel'
          : 'title_${e.title}_${e.author}'.replaceAll(' ', '_');

      return BookModel(
        id: id,
        title: e.title,
        author: e.author,
        isbn: isbnForModel.isNotEmpty ? isbnForModel : null,
        pageCount: 0,
        // 알 수 없으면 0
        pageRead: 0,
        category: 'want',
        // 초기값
        rereadCount: 1,
        customLibraries: const [],
        // publisher/imageUrl/description/itemId 등은 API로 후속 보강 가능
      );
    }).toList();
  }
}
