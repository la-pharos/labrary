/// ReadingIntroScreen에서 사용

import 'package:flutter/material.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/service/book_api_service.dart';

class BookSearchDialog extends StatefulWidget {
  const BookSearchDialog({super.key});

  @override
  State<BookSearchDialog> createState() => _BookSearchDialogState();
}

class _BookSearchDialogState extends State<BookSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<BookModel> _searchResults = [];
  bool _hasSearched = false;
  bool _isLoading = false;
  double _dialogHeightRatio = 0.3; // 초기엔 검색창만 보이게

  void _onSearchChanged(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _dialogHeightRatio = 0.3; // 검색어 없으면 다시 축소
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _searchResults = [];
      _hasSearched = true;
      _dialogHeightRatio = 0.7; // 검색 시작 시 확장
    });

    try {
      final results = await BookApiService.searchBooksCombined(keyword);
      setState(() {
        _searchResults = results;
        _dialogHeightRatio = 0.7; // 계속 유지
      });
    } catch (e) {
      debugPrint("❌ API 검색 오류: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("도서 검색 중 문제가 발생했습니다.")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onBookTap(BookModel book) async {
    BookModel selected = book;

    if (book.pageCount == 0 && book.itemId != null) {
      final detail = await BookApiService.fetchBookDetail(book.itemId!);
      if (detail != null) {
        selected = detail;
      }
    }

    debugPrint("[📘 선택된 책] ${selected.title}, pageCount: ${selected.pageCount}");
    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final padding = screenWidth * 0.05;
    final fontSize = screenWidth * 0.05;
    final imageWidth = screenWidth * 0.13;
    final imageHeight = screenHeight * 0.1;
    final dialogWidth = screenWidth * 0.9;

    return Dialog(
      backgroundColor: const Color(0xFF0A1D27),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: dialogWidth,
        height: screenHeight * _dialogHeightRatio,
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDialogHeader(fontSize),
              SizedBox(height: screenHeight * 0.02),
              TextField(
                controller: _searchController,
                onSubmitted: _onSearchChanged,
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
              const SizedBox(height: 12),
              Expanded(
                child: _buildResultSection(imageWidth, imageHeight, fontSize),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogHeader(double fontSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "어떤 책과 함께할까요?",
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            fontFamily: 'kopub',
            color: Colors.white,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildResultSection(double imageWidth, double imageHeight, double fontSize) {
    if (!_hasSearched) {
      return const Center(
        child: Text(
          "검색어를 입력해주세요.",
          style: TextStyle(color: Colors.white54, fontFamily: 'kopub'),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          "검색 결과가 없습니다.",
          style: TextStyle(color: Colors.white54, fontFamily: 'kopub'),
        ),
      );
    }

    return Scrollbar(
      thumbVisibility: true,
      radius: const Radius.circular(8),
      thickness: 4,
      child: ListView.builder(
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final book = _searchResults[index];
          return GestureDetector(
            onTap: () => _onBookTap(book),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      book.imageUrl ?? '',
                      width: imageWidth,
                      height: imageHeight,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: imageWidth,
                        height: imageHeight,
                        color: Colors.grey,
                        child: const Icon(Icons.book, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize * 0.75,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          book.author,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: fontSize * 0.7,
                          ),
                        ),
                        if (book.pageCount > 0)
                          Text(
                            "총 ${book.pageCount}쪽",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: fontSize * 0.6,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

}
