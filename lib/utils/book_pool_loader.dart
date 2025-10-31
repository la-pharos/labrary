import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// 풀 JSON에서 isbn13 리스트만 뽑아옴
Future<List<String>> loadIsbnsFromPool(String poolId) async {
  final path = 'assets/challenges/book_pools/$poolId.json';
  final raw = await rootBundle.loadString(path);
  final map = jsonDecode(raw) as Map<String, dynamic>;
  final books = (map['books'] as List? ?? []);
  return books
      .map((e) => (e['isbn13'] ?? '').toString().trim())
      .where((isbn) => isbn.isNotEmpty)
      .toList();
}