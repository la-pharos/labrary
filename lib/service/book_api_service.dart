import 'dart:convert';
import 'package:flutter/foundation.dart'; // ✅ debugPrint 사용 시 필요
import 'package:http/http.dart' as http;
import 'package:dayverse_book/model/book_model.dart';

class BookApiService {
  static const String _baseUrl = 'https://www.aladin.co.kr/ttb/api/ItemSearch.aspx';
  static const String _apiKey = 'ttbljunlsool2051001';

  static const String _naverClientId = 'THeSZORYA2Ce_woLCqYj'; // 네 ID
  static const String _naverClientSecret = 'N7n4FudxCH';        // 네 시크릿

  /// 🔧 긴 문자열을 안전하게 출력 (잘리지 않게)
  static void debugPrintLongText(String text) {
    const int chunkSize = 800;
    for (var i = 0; i < text.length; i += chunkSize) {
      final chunk = text.substring(i, i + chunkSize > text.length ? text.length : i + chunkSize);
      debugPrint(chunk);
    }
  }

  /// 📘 책 검색 (간략 정보)
  static Future<List<BookModel>> searchBooks(String query) async {
    final uri = Uri.parse(
      '$_baseUrl?ttbkey=$_apiKey&Query=$query&QueryType=Title&SearchTarget=Book&output=JS&Version=20131101&Cover=Big',
    );
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final items = data['item'] as List<dynamic>? ?? [];
      return items.map((item) => BookModel.fromAladinApi(item)).toList();
    } else {
      throw Exception('알라딘 API 호출 실패: ${response.statusCode}');
    }
  }

  /// 📖 상세 정보 조회 (페이지 수 등)
  static Future<BookModel?> fetchBookDetail(String itemId) async {
    final uri = Uri.parse(
      'https://www.aladin.co.kr/ttb/api/ItemLookUp.aspx'
          '?ttbkey=$_apiKey'
          '&itemId=$itemId'
          '&ItemIdType=ItemId'
          '&output=JS'
          '&Version=20131101',
    );

    //debugPrint("📘 [API 요청] 상세 조회 요청 itemId: $itemId");

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final items = data['item'] as List<dynamic>? ?? [];
      if (items.isNotEmpty) {
        final item = items[0];
        //debugPrintLongText('[📦 상세조회 item 데이터] ${json.encode(item)}'); // ✅ 긴 JSON 안전 출력

        final pageCountFromApi = int.tryParse(
          item['itemPage']?.toString() ??
              item['subInfo']?['itemPage']?.toString() ??
              '0',
        ) ?? 0;

        //debugPrint("📘 [파싱 확인] 추출된 pageCount: $pageCountFromApi");

        final coverUrl = item['cover'] ?? '';
        //debugPrint('[📷 표지 이미지 URL] $coverUrl');

        final book = BookModel.fromAladinApi(item);
        //debugPrint("📘 [최종 전달할 BookModel] pageCount: ${book.pageCount}, title: ${book.title}");
        return book;
      }
    } else {
      throw Exception('알라딘 상세 정보 API 실패: ${response.statusCode}');
    }
    return null;
  }

  static Future<BookModel?> fetchBookDetailByIsbn(String isbn) async {
    final url = Uri.parse('https://www.aladin.co.kr/ttb/api/ItemLookUp.aspx'
        '?ttbkey=$_apiKey' // 🔧 통일: 위에서 정의한 _apiKey 사용
        '&itemIdType=ISBN'
        '&ItemId=$isbn'
        '&output=JS'
        '&Version=20131101');

    //debugPrint("📘 [API 요청] 상세조회 by ISBN: $isbn");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final items = data['item'] as List<dynamic>? ?? [];
      if (items.isNotEmpty) {
        final item = items[0];
        //debugPrintLongText('[📦 ISBN 상세조회 데이터] ${jsonEncode(item)}');

        final coverUrl = item['cover'] ?? '';
        //debugPrint('[📷 표지 이미지 URL] $coverUrl');

        final book = BookModel.fromAladinApi(item);
        //debugPrint("📘 [최종 BookModel] title: ${book.title}, pageCount: ${book.pageCount}");
        return book;
      }
    } else {
      debugPrint("❌ [API 오류] 상태 코드: ${response.statusCode}");
    }

    return null;
  }

  /// 📚 requiredBooks 리스트 기반 상세 정보 묶음 조회
  static Future<List<BookModel>> fetchRequiredBooksFromApi(List<BookModel> books) async {
    final List<BookModel> result = [];

    for (final book in books) {
      BookModel? fetched;

      final isbn = book.isbn;
      final itemId = book.itemId;

      // 1. ISBN → 2. itemId → 3. title+author
      if (isbn != null && isbn.isNotEmpty) {
        fetched = await fetchBookDetailByIsbn(isbn);
        //debugPrint("📕 ISBN으로 검색 시도: ${book.title} → ${fetched != null ? '성공' : '실패'}");
      }

      if (fetched == null && itemId != null && itemId.isNotEmpty) {
        fetched = await fetchBookDetail(itemId);
        //debugPrint("📘 itemId로 검색 시도: ${book.title} → ${fetched != null ? '성공' : '실패'}");
      }

      // 🔥 마지막 fallback: 네이버 title + author 검색
      if (fetched == null) {
        final query = "${book.title} ${book.author}";
        fetched = await fetchBookFromNaver(query);
        //debugPrint("📗 제목+저자 검색 시도: $query → ${fetched != null ? '성공' : '실패'}");
      }

      if (fetched != null) {
        result.add(fetched.copyWith(id: book.id)); // 기존 ID 유지
      } else {
        //debugPrint("❌ 최종 실패: ${book.title} (${book.isbn ?? 'isbn 없음'})");
        result.add(book); // 최소한 원본은 유지
      }
    }

    return result;
  }

  static Future<BookModel?> fetchBookFromNaver(String query) async {
    final uri = Uri.https(
      'openapi.naver.com',
      '/v1/search/book.json',
      {
        'query': query,
        'display': '1',
      },
    );

    final response = await http.get(uri, headers: {
      'X-Naver-Client-Id': _naverClientId,
      'X-Naver-Client-Secret': _naverClientSecret,
    });

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final items = data['items'] as List<dynamic>;
      if (items.isNotEmpty) {
        return BookModel.fromNaverApi(items[0]);
      }
    } else {
      debugPrint('❌ 네이버 API 실패: ${response.statusCode}');
    }

    return null;
  }

  /// 🔍 네이버 + 알라딘 검색 통합 함수
  static Future<List<BookModel>> searchBooksCombined(String query) async {
    final List<BookModel> finalList = [];

    try {
      // 1. 네이버에서 최대 10권 검색
      final naverUri = Uri.https(
        'openapi.naver.com',
        '/v1/search/book.json',
        {
          'query': query,
          'display': '10',
        },
      );

      final naverResponse = await http.get(naverUri, headers: {
        'X-Naver-Client-Id': _naverClientId,
        'X-Naver-Client-Secret': _naverClientSecret,
      });

      if (naverResponse.statusCode == 200) {
        final data = json.decode(utf8.decode(naverResponse.bodyBytes));
        final items = data['items'] as List<dynamic>;

        for (var item in items) {
          final naverBook = BookModel.fromNaverApi(item);

          BookModel mergedBook = naverBook;

          // 2. 알라딘에서 pageCount 보충 (ISBN 기반)
          if (naverBook.isbn != null && naverBook.isbn!.isNotEmpty) {
            final detail = await fetchBookDetailByIsbn(naverBook.isbn!);
            if (detail != null) {
              mergedBook = naverBook.merge(detail);
            }
          }

          finalList.add(mergedBook);
        }
      } else {
        debugPrint('❌ 네이버 API 실패: ${naverResponse.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ 네이버 검색 예외: $e');
    }

    return finalList;
  }

  static Future<List<BookModel>> fetchBestsellersWithNaverData() async {
    final url = Uri.parse("https://www.aladin.co.kr/ttb/api/ItemList.aspx"
        "?ttbkey=$_apiKey"
        "&QueryType=Bestseller"
        "&MaxResults=10"
        "&start=1"
        "&SearchTarget=Book"
        "&output=js"
        "&Version=20131101");

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception("📛 베스트셀러 불러오기 실패: ${response.statusCode}");
    }

    final json = jsonDecode(response.body);
    final items = (json['item'] as List).cast<Map<String, dynamic>>();
    final List<BookModel> result = [];

    for (final item in items) {
      final isbn = item["isbn13"] ?? item["isbn"];
      if (isbn == null || isbn.isEmpty) continue;

      try {
        // 1. 알라딘 정보 먼저 가져옴 (pageCount 포함)
        final aladinBook = BookModel.fromAladinApi(item);

        // 2. 네이버 API로 정보 조회 (title, author, description, etc)
        final naverBook = await fetchBookFromNaver(isbn);

        if (naverBook != null) {
          // ✅ 알라딘 기준으로 네이버 덮어쓰기
          final merged = aladinBook.merge(naverBook);
          result.add(merged);
        } else {
          result.add(aladinBook);
        }
      } catch (e) {
        debugPrint("❌ 베스트셀러 처리 실패 ($isbn): $e");
      }
    }

    return result;
  }

}
// 📂
