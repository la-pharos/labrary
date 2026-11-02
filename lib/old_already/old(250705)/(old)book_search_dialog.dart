/// 아직 아무데도 안 쓰고 있음. 사실상 폐기.

import 'package:flutter/material.dart';
import 'package:dayverse_book/constants/dummy_book_list.dart';
import 'package:dayverse_book/model/book_model.dart';

class BookSearchDialog extends StatefulWidget {
  final Function(BookModel) onBookSelected; // ✅ 타입 변경

  const BookSearchDialog({super.key, required this.onBookSelected});

  @override
  State<BookSearchDialog> createState() => _BookSearchDialogState();
}


class _BookSearchDialogState extends State<BookSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<BookModel> _filteredBooks = []; // ✅ 타입 변경

  void _onSearchChanged(String keyword) {
    setState(() {
      _filteredBooks = dummyBooks.where((book) {
        final title = book.title.toLowerCase();
        final author = book.author.toLowerCase();
        return title.contains(keyword.toLowerCase()) ||
            author.contains(keyword.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0A1D27),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "💪 도전 중 책을 추가할 수 있어요!",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'kopub',
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "선택된 책은 '읽는 중인 책'으로 서재에 자동 등록돼요.",
              style: TextStyle(
                color: Colors.amberAccent,
                fontSize: 14,
                fontFamily: 'kopub',
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "책 제목 또는 작가 검색",
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_searchController.text.isNotEmpty)
              SizedBox(
                height: 300,
                child: _filteredBooks.isNotEmpty
                    ? Scrollbar(
                  thumbVisibility: true,
                  radius: const Radius.circular(8),
                  thickness: 4,
                  child: ListView.builder(
                    itemCount: _filteredBooks.length,
                    itemBuilder: (context, index) {
                      final book = _filteredBooks[index];
                      return ListTile(
                        title: Text(
                          book.title,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          book.author,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        onTap: () => widget.onBookSelected(book),
                      );
                    },
                  ),
                )
                    : const Center(
                  child: Text(
                    "검색 결과가 없습니다.",
                    style: TextStyle(
                      color: Colors.white54,
                      fontFamily: 'kopub',
                    ),
                  ),
                ),
              )
            else
              const Center(
                child: Text(
                  "🔎 검색어를 입력해 주세요.",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                    fontFamily: 'kopub',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
