import 'package:flutter/foundation.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/service/yes24_book_service.dart';
import 'package:dayverse_book/utils/book_utils.dart';

class BookApiService {
  /// YES24 도서 검색
  static Future<List<BookModel>> searchBooks(
    String query, {
    int maxResults = 15,
  }) async {
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      return [];
    }

    try {
      final yes24Books = await Yes24BookService.searchBooks(
        trimmedQuery,
        maxResults: maxResults,
      );

      final results = <BookModel>[];

      for (final data in yes24Books) {
        final title = data['title']?.toString().trim() ?? '';
        final author = data['author']?.toString().trim() ?? '';
        final isbn = data['isbn13']?.toString().trim() ?? '';

        if (title.isEmpty) {
          continue;
        }

        final pageCount = int.tryParse(
              data['pageCount']?.toString() ?? '',
            ) ??
            0;

        final yes24ItemId = data['yes24ItemId']?.toString();

        results.add(
          BookModel(
            id: generateBookId(
              isbn.isEmpty ? null : isbn,
              title,
              author,
            ),
            title: title,
            author: author,
            publisher: data['publisher']?.toString(),
            isbn: isbn.isEmpty ? null : isbn,
            description: data['description']?.toString(),
            imageUrl: data['coverUrl']?.toString(),

            // 알라딘 상품 ID는 사용하지 않음
            itemId: null,

            // YES24 상품 ID
            yes24ItemId: yes24ItemId,

            pageCount: pageCount > 0 ? pageCount : 0,
            pageRead: 0,
            rereadCount: 1,
            category: 'want',
            customLibraries: const [],
          ),
        );
      }

      debugPrint(
        'YES24 검색 성공: ${results.length}권',
      );

      return results.take(maxResults).toList();
    } catch (e, stackTrace) {
      debugPrint('YES24 검색 실패: $e');
      debugPrint('$stackTrace');
      return [];
    }
  }

  /// ISBN13으로 YES24 도서 상세정보 조회
  static Future<BookModel?> fetchBookDetailByIsbn(
    String isbn,
  ) async {
    final normalizedIsbn = isbn.replaceAll(RegExp(r'[^0-9Xx]'), '').trim();

    // 현재 서버 함수는 ISBN13 전용
    if (normalizedIsbn.length != 13) {
      debugPrint(
        '지원하지 않는 ISBN 형식: $normalizedIsbn',
      );
      return null;
    }

    try {
      final yes24 = await Yes24BookService.findByIsbn(
        normalizedIsbn,
      );

      if (!yes24.found || yes24.title == null || yes24.title!.trim().isEmpty) {
        return null;
      }

      // 다른 판본으로 잘못 조회되는 상황 방지
      if (yes24.isbn13 != normalizedIsbn) {
        debugPrint(
          'YES24 ISBN 불일치: $normalizedIsbn',
        );
        return null;
      }

      final title = yes24.title!.trim();
      final author = yes24.author?.trim() ?? '';

      return BookModel(
        id: generateBookId(
          normalizedIsbn,
          title,
          author,
        ),
        title: title,
        author: author,
        publisher: yes24.publisher,
        isbn: normalizedIsbn,

        // YES24 앞표지와 도서 소개
        description: yes24.description,
        imageUrl: yes24.coverUrl,

        // 알라딘 상품 ID는 사용하지 않음
        itemId: null,

        // YES24 상품 ID 및 책등
        yes24ItemId: yes24.itemId,
        spineUrl: yes24.spineUrl,
        spineChecked: true,

        // YES24 페이지수
        pageCount: yes24.pageCount,

        pageRead: 0,
        rereadCount: 1,
        category: 'want',
        customLibraries: const [],
      );
    } catch (e, stackTrace) {
      debugPrint(
        'YES24 ISBN 상세 조회 실패: $e',
      );
      debugPrint('$stackTrace');
      return null;
    }
  }

  /// 챌린지 지정 도서의 상세정보 보강
  ///
  /// 기존 BookModel을 유지하면서
  /// YES24에서 가져온 도서 정보만 반영한다.
  static Future<List<BookModel>> fetchRequiredBooksFromApi(
    List<BookModel> books,
  ) async {
    final result = <BookModel>[];

    for (final book in books) {
      BookModel? fetched;

      final isbn = book.isbn?.trim();

      // 1. ISBN으로 정확한 판본 조회
      if (isbn != null && isbn.isNotEmpty) {
        fetched = await fetchBookDetailByIsbn(isbn);
      }

      // 2. ISBN 조회 실패 시 제목 + 저자 검색
      if (fetched == null) {
        final query = [
          book.title,
          book.author,
        ]
            .where(
              (value) => value.trim().isNotEmpty,
            )
            .join(' ');

        if (query.isNotEmpty) {
          final searchedBooks = await searchBooks(
            query,
            maxResults: 1,
          );

          if (searchedBooks.isNotEmpty) {
            final candidate = searchedBooks.first;

            // ISBN이 있으면 반드시 동일한 ISBN일 때만 반영
            if (isbn == null || isbn.isEmpty || candidate.isbn == isbn) {
              fetched = candidate;
            }
          }
        }
      }

      if (fetched != null) {
        result.add(
          book.copyWith(
            title: fetched.title.isNotEmpty ? fetched.title : book.title,
            author: fetched.author.isNotEmpty ? fetched.author : book.author,
            publisher: (fetched.publisher?.isNotEmpty ?? false)
                ? fetched.publisher
                : book.publisher,
            isbn:
                (fetched.isbn?.isNotEmpty ?? false) ? fetched.isbn : book.isbn,
            description: (fetched.description?.isNotEmpty ?? false)
                ? fetched.description
                : book.description,
            imageUrl: (fetched.imageUrl?.isNotEmpty ?? false)
                ? fetched.imageUrl
                : book.imageUrl,

            // 기존 독서 기록의 페이지수는 우선 보존
            pageCount: book.pageCount > 0 ? book.pageCount : fetched.pageCount,

            // 기존 알라딘 ID는 데이터 호환을 위해 보존
            itemId: fetched.itemId ?? book.itemId,

            // YES24 정보
            yes24ItemId: fetched.yes24ItemId ?? book.yes24ItemId,
            spineUrl: fetched.spineUrl ?? book.spineUrl,
          ),
        );
      } else {
        // 도서 정보를 조회하지 못하면 기존 값 유지
        result.add(book);
      }
    }

    return result;
  }

  /// 기존 검색 화면 호출부 호환용
  static Future<List<BookModel>> searchBooksCombined(
    String query,
  ) {
    return searchBooks(
      query,
      maxResults: 15,
    );
  }

  /// 기존 호출부 호환용
  ///
  /// 함수명은 과거 네이버 API에서 사용한 이름이지만
  /// 실제 데이터 조회는 YES24에서 수행한다.
  @Deprecated(
    '네이버 책 API 종료. '
    'searchBooks 또는 fetchBookDetailByIsbn 사용',
  )
  static Future<BookModel?> fetchBookFromNaver(
    String query,
  ) async {
    final books = await searchBooks(
      query,
      maxResults: 1,
    );

    if (books.isEmpty) {
      return null;
    }

    return books.first;
  }

  /// YES24 종합 베스트셀러 TOP 10 조회
  static Future<List<BookModel>> fetchBestsellers() async {
    try {
      final data = await Yes24BookService.fetchBestsellers();

      final books = <BookModel>[];

      for (final item in data) {
        final title = item['title']?.toString().trim() ?? '';
        final author = item['author']?.toString().trim() ?? '';
        final isbn = item['isbn13']?.toString().trim() ?? '';

        if (title.isEmpty) {
          continue;
        }

        final pageCount = int.tryParse(
              item['pageCount']?.toString() ?? '',
            ) ??
            0;

        books.add(
          BookModel(
            id: generateBookId(
              isbn.isEmpty ? null : isbn,
              title,
              author,
            ),
            title: title,
            author: author,
            publisher: item['publisher']?.toString(),
            isbn: isbn.isEmpty ? null : isbn,
            description: item['description']?.toString(),
            imageUrl: item['coverUrl']?.toString(),

            // 알라딘 상품 ID는 사용하지 않음
            itemId: null,

            // YES24 상품 ID
            yes24ItemId: item['yes24ItemId']?.toString(),

            pageCount: pageCount > 0 ? pageCount : 0,
            pageRead: 0,
            rereadCount: 1,
            category: 'want',
            customLibraries: const [],
          ),
        );
      }

      debugPrint(
        'YES24 베스트셀러 조회 성공: ${books.length}권',
      );

      return books;
    } catch (e, stackTrace) {
      debugPrint(
        'YES24 베스트셀러 조회 실패: $e',
      );
      debugPrint('$stackTrace');
      return [];
    }
  }

  /// 여러 ISBN을 순차적으로 YES24에서 조회
  static Future<List<BookModel>> fetchBooksByIsbnList(
    List<String> isbns,
  ) async {
    final result = <BookModel>[];

    for (final isbn in isbns) {
      try {
        final book = await fetchBookDetailByIsbn(isbn);

        if (book != null) {
          result.add(book);
        }
      } catch (e) {
        debugPrint(
          'ISBN $isbn 조회 실패: $e',
        );
      }
    }

    return result;
  }
}
