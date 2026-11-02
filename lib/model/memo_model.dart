import 'package:cloud_firestore/cloud_firestore.dart';

class MemoModel {
  final String id;
  final String bookId;
  final String content;
  final List<String> imageUrls;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemoModel({
    required this.id,
    required this.bookId,
    required this.content,
    this.imageUrls = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasImages => imageUrls.isNotEmpty;

  bool get isEdited =>
      updatedAt.isAfter(createdAt);

  MemoModel copyWith({
    String? id,
    String? bookId,
    String? content,
    List<String>? imageUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MemoModel(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      content: content ?? this.content,
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory MemoModel.fromMap(
      Map<String, dynamic> map, {
        String? documentId,
      }) {
    final createdAt = _parseDateTime(
      map['createdAt'] ?? map['savedAt'],
    );

    final updatedAt = _parseDateTime(
      map['updatedAt'],
      fallback: createdAt,
    );

    return MemoModel(
      id: documentId ??
          map['id']?.toString() ??
          '',
      bookId: map['bookId']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      imageUrls: _parseImageUrls(
        map['imageUrls'],
      ),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'content': content,
      'imageUrls': imageUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static DateTime _parseDateTime(
      dynamic value, {
        DateTime? fallback,
      }) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      final parsed = DateTime.tryParse(value);

      if (parsed != null) {
        return parsed;
      }
    }

    return fallback ?? DateTime.now();
  }

  static List<String> _parseImageUrls(
      dynamic value,
      ) {
    if (value is! List) {
      return const [];
    }

    return value
        .map((item) => item.toString().trim())
        .where((url) => url.isNotEmpty)
        .toList();
  }
}
