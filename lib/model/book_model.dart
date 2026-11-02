import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:dayverse_book/utils/book_utils.dart';


class BookModel {
  final String id;
  final String title;
  final String author;
  final String? publisher;
  final String? isbn;
  final String? description;
  final File? imageFile; // ✅ 로컬 이미지 (직접 등록한 이미지 파일)
  final String? imageUrl; // ✅ URL 이미지 (API에서 받은 이미지)
  final String? itemId; // ✅ 알라딘 고유 아이템 ID

  // ✅ YES24 책등 이미지용
  final String? yes24ItemId;
  final String? spineUrl;
  final bool spineChecked;

  final int pageCount;
  int pageRead;
  final List<DateTime>? readingDates;
  final double? rating; // ⭐️ 별점 (0.0 ~ 5.0)


  String category; // 'reading', 'done', 'want'
  final List<String> customLibraries; // ex: ['AI', '소설']
  int rereadCount; // ✅ 회독수 (기본값 1)

  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? readDate;

  BookModel({
    String? id,
    required this.title,
    required this.author,
    this.publisher,
    this.isbn,
    this.description,
    this.imageFile,
    this.imageUrl,
    this.itemId,
    this.yes24ItemId,
    this.spineUrl,
    this.spineChecked = false,
    this.pageCount = 0,
    this.pageRead = 0,
    this.readingDates,
    this.rating, // ⭐️ 여기 추가
    this.rereadCount = 0,
    this.category = 'reading',
    this.customLibraries = const [],
    this.startDate,
    this.endDate,
    this.readDate,
  }) : id = id ?? const Uuid().v4();

  /// ✅ Map → BookModel 변환
  factory BookModel.fromMap(Map<String, dynamic> map) {
    return BookModel(
      id: map['id'],
      itemId: map['itemId']?.toString(),
      yes24ItemId: map['yes24ItemId']?.toString(),
      spineUrl: map['spineUrl']?.toString(),
      spineChecked: map['spineChecked'] == true,
      title: map['title'] ?? '',
      author: map['author'] ?? '',
      publisher: map['publisher'],
      isbn: map['isbn'],
      description: map['description'],
      imageUrl: map['imageUrl'],
      pageCount: int.tryParse(map['pageCount']?.toString() ?? '') ?? 0,
      pageRead: int.tryParse(map['pageRead']?.toString() ?? '0') ?? 0,
      readingDates: (map['readingDates'] as List?)?.map((e) => DateTime.parse(e)).toList(),
      rating: map['rating'] != null ? (map['rating'] as num).toDouble() : null,
      rereadCount: int.tryParse(map['rereadCount']?.toString() ?? '0') ?? 0,
      category: map['category'] ?? 'reading',
      customLibraries: List<String>.from(map['customLibraries'] ?? []),
      startDate: map['startDate'] != null ? DateTime.tryParse(map['startDate'])?.toLocal() : null,
      endDate: map['endDate'] != null ? DateTime.tryParse(map['endDate'])?.toLocal() : null,
      readDate: map['readDate'] != null ? DateTime.tryParse(map['readDate'])?.toLocal() : null,
    );
  }

  /// ✅ BookModel → Map 변환 (Firestore 저장용)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemId': itemId,
      'yes24ItemId': yes24ItemId,
      'spineUrl': spineUrl,
      'spineChecked': spineChecked,
      'title': title,
      'author': author,
      'publisher': publisher,
      'isbn': isbn,
      'description': description,
      'imageUrl': imageUrl,
      'pageCount': pageCount,
      'pageRead': pageRead,
      'readingDates': readingDates?.map((e) => e.toIso8601String()).toList(),
      'rating': rating,
      'rereadCount': rereadCount,
      'category': category,
      'customLibraries': customLibraries,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'readDate': readDate?.toIso8601String()
    };
  }

  factory BookModel.fromFirestore(
      Map<String, dynamic> map,
      String docId,
      ) {
    return BookModel(
      id: docId,
      itemId: map['itemId']?.toString(),
      yes24ItemId: map['yes24ItemId']?.toString(),
      spineUrl: map['spineUrl']?.toString(),
      spineChecked: map['spineChecked'] == true,
      title: map['title'] ?? '',
      author: map['author'] ?? '',
      publisher: map['publisher'],
      isbn: map['isbn'],
      description: map['description'],
      imageUrl: map['imageUrl'],
      pageCount:
      int.tryParse(map['pageCount']?.toString() ?? '') ?? 0,
      pageRead:
      int.tryParse(map['pageRead']?.toString() ?? '0') ?? 0,
      readingDates: (map['readingDates'] as List?)
          ?.map((e) => DateTime.parse(e.toString()))
          .toList(),
      rating: map['rating'] != null
          ? (map['rating'] as num).toDouble()
          : null,
      rereadCount:
      int.tryParse(map['rereadCount']?.toString() ?? '0') ?? 0,
      category: map['category'] ?? 'reading',
      customLibraries:
      List<String>.from(map['customLibraries'] ?? []),
      startDate: map['startDate'] != null
          ? DateTime.tryParse(map['startDate'].toString())?.toLocal()
          : null,
      endDate: map['endDate'] != null
          ? DateTime.tryParse(map['endDate'].toString())?.toLocal()
          : null,
      readDate: map['readDate'] != null
          ? DateTime.tryParse(map['readDate'].toString())?.toLocal()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'itemId': itemId,
      'yes24ItemId': yes24ItemId,
      'spineUrl': spineUrl,
      'spineChecked': spineChecked,
      'title': title,
      'author': author,
      'publisher': publisher,
      'isbn': isbn,
      'description': description,
      'imageUrl': imageUrl,
      'pageCount': pageCount,
      'pageRead': pageRead,
      'readingDates':
      readingDates?.map((e) => e.toIso8601String()).toList(),
      'rating': rating,
      'rereadCount': rereadCount,
      'category': category,
      'customLibraries': customLibraries,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'readDate': readDate?.toIso8601String(),
    };
  }

  /// ✅ 진행률 (0.0 ~ 1.0)
  double get progressRatio {
    if (pageCount == 0) return 0.0;
    if (pageRead >= pageCount) return 1.0;
    return (pageRead / pageCount).clamp(0.0, 0.999); // 최대 0.999까지만 허용
  }

  int get progressPercent {
    if (pageCount == 0) return 0;
    if (pageRead >= pageCount) return 100;
    return ((pageRead / pageCount) * 100).floor(); // floor로 확실히 제어
  }

  BookModel copyWith({
    String? id,
    String? title,
    String? author,
    String? publisher,
    String? isbn,
    String? description,
    File? imageFile,
    String? imageUrl,
    String? itemId,
    String? yes24ItemId,
    String? spineUrl,
    bool? spineChecked,
    bool clearSpineUrl = false,
    int? pageCount,
    int? pageRead,
    List<DateTime>? readingDates,
    double? rating,
    int? rereadCount,
    String? category,
    List<String>? customLibraries,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? readDate,
  }) {
    return BookModel(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      publisher: publisher ?? this.publisher,
      isbn: isbn ?? this.isbn,
      description: description ?? this.description,
      imageFile: imageFile ?? this.imageFile,
      imageUrl: imageUrl ?? this.imageUrl,
      itemId: itemId ?? this.itemId,
      yes24ItemId: yes24ItemId ?? this.yes24ItemId,
      spineUrl:
      clearSpineUrl
          ? null
          : (spineUrl ?? this.spineUrl),
      spineChecked:
      spineChecked ?? this.spineChecked,
      pageCount: pageCount ?? this.pageCount,
      pageRead: pageRead ?? this.pageRead,
      readingDates: readingDates ?? this.readingDates,
      rating: rating ?? this.rating,
      rereadCount: rereadCount ?? this.rereadCount,
      category: category ?? this.category,
      customLibraries: customLibraries ?? List<String>.from(this.customLibraries),
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      readDate: readDate ?? this.readDate,
    );
  }

  /// ✅ 완독 여부: 97% 이상 읽었거나 카테고리 'done'이면 true
  bool get isCompleted {
    return pageCount > 0 && pageRead >= pageCount;
  }

  factory BookModel.fromAladinApi(Map<String, dynamic> map) {
    final title = map['title'] ?? '';
    final author = map['author'] ?? '';
    final isbn = map['isbn13'] ?? map['isbn'];

    // ✅ itemPage를 다양한 위치에서 추출 시도
    final pageCount = int.tryParse(
      map['itemPage']?.toString() ??
          map['subInfo']?['itemPage']?.toString() ??
          '0',
    ) ?? 0;

    return BookModel(
      id: generateBookId(isbn, title, author),
      title: title,
      author: author,
      publisher: map['publisher'] ?? '',
      isbn: isbn,
      description: map['description'] ?? '',
      imageUrl: (map['cover'] as String? ?? '').replaceAll('coversum', 'cover'),
      itemId: map['itemId']?.toString(), // 반드시 유지!
      pageCount: pageCount,
      pageRead: 0,
      rereadCount: 1,
      category: 'want',
      customLibraries: [],
      startDate: null,
      endDate: null,
    );


  }

  factory BookModel.fromNaverApi(Map<String, dynamic> json) {
    final isbnRaw = json['isbn'] ?? '';
    final isbn = isbnRaw.split(' ').last; // ISBN10과 ISBN13이 함께 있을 수 있음

    final title = _cleanHtml(json['title'] ?? '');
    final author = _cleanHtml(json['author'] ?? '');

    return BookModel(
      id: generateBookId(isbn, title, author),
      title: title,
      author: author,
      publisher: json['publisher'],
      isbn: isbn,
      description: _cleanHtml(json['description']),
      imageUrl: json['image'],
      itemId: null, // 알라딘 전용 itemId는 아직 없음
      pageCount: 0, // 알라딘에서 추후 보충
      pageRead: 0,
      rereadCount: 1,
      category: 'want',
      customLibraries: [],
      startDate: null,
      endDate: null,
    );
  }

  static String _cleanHtml(String? input) {
    if (input == null) return '';
    return input.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  BookModel merge(BookModel other) {
    return copyWith(
      title: other.title.isNotEmpty ? other.title : title,
      author: other.author.isNotEmpty ? other.author : author,
      publisher: (other.publisher?.isNotEmpty ?? false) ? other.publisher : publisher,
      isbn: (other.isbn?.isNotEmpty ?? false) ? other.isbn : isbn,
      description: (other.description?.isNotEmpty ?? false) ? other.description : description,
      imageUrl: (other.imageUrl?.isNotEmpty ?? false) ? other.imageUrl : imageUrl,
      pageCount: (pageCount > 0) ? pageCount : (other.pageCount > 0 ? other.pageCount : 0),
      itemId: (itemId?.isNotEmpty ?? false) ? itemId : (other.itemId?.isNotEmpty ?? false ? other.itemId : null),
    );
  }

  factory BookModel.selfRegistered({
    required String title,
    required String author,
    required String publisher,
    String? isbn,
    required int pageCount,
    required String imageUrl,
    required String category,
    required DateTime? startDate,
    required DateTime? endDate,
    required int pageRead,
  }) {
    final trimmedTitle = title.trim();
    final trimmedAuthor = author.trim();
    final trimmedPublisher = publisher.trim();

    final normalizedIsbn = (isbn ?? '')
        .replaceAll(RegExp(r'[^0-9Xx]'), '')
        .toUpperCase();

    return BookModel(
      // 직접 등록 책은 ISBN 유무와 관계없이 고유 UUID 사용
      id: 'self_${const Uuid().v4()}',
      title: trimmedTitle,
      author: trimmedAuthor,
      publisher: trimmedPublisher,
      isbn: normalizedIsbn.isEmpty ? null : normalizedIsbn,
      description: null,
      imageUrl: imageUrl,
      imageFile: null,
      itemId: null,
      pageCount: pageCount,
      pageRead: pageRead,
      rereadCount: category == 'done' ? 1 : 0,
      category: category,
      customLibraries: const [],
      startDate: category == 'done' || category == 'reading'
          ? startDate
          : null,
      endDate: category == 'done' ? endDate : null,
      readDate: category == 'done'
          ? endDate ?? DateTime.now()
          : null,
    );
  }

}

extension BookModelImageSafe on BookModel {
  String get safeImageUrl {
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return imageUrl!.replaceAll('coversum', 'cover');
    }
    return 'https://via.placeholder.com/150x220?text=No+Image';
  }
}

