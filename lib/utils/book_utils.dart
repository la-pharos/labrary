import 'package:flutter/material.dart';

// ✅ 책 ID 생성 함수
String generateBookId(String? isbn, String title, String author) {
  if (isbn != null && isbn.trim().isNotEmpty) {
    return "isbn_${isbn.trim()}";
  } else {
    return "self_${title.trim().toLowerCase()}_${author.trim().toLowerCase()}";
  }
}

// ISBN이 있는 책:
// bookId = "isbn_$isbn"

// ISBN이 없는 책 (직접 등록한 책):
// bookId = "self_${title}_${author}"
