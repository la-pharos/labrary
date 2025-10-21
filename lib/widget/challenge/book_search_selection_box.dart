import 'package:flutter/material.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/service/book_api_service.dart';

/// 단일+사용자 지정도서+페이지 연동 챌린지의 참여 다이얼로그에서 사용.

class BookSearchSelectionBox extends StatefulWidget {
  final BookModel? initialSelectedBook;
  final Function(BookModel?) onBookChanged;

  const BookSearchSelectionBox({
    super.key,
    this.initialSelectedBook,
    required this.onBookChanged,
  });

  @override
  State<BookSearchSelectionBox> createState() => _BookSearchSelectionBoxState();
}

class _BookSearchSelectionBoxState extends State<BookSearchSelectionBox> {
  final TextEditingController _searchController = TextEditingController();
  List<BookModel> _searchResults = [];
  BookModel? _selectedBook;

  @override
  void initState() {
    super.initState();
    _selectedBook = widget.initialSelectedBook;
  }

  Future<void> _handleSearch(String keyword) async {
    if (keyword
        .trim()
        .isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    try {
      final results = await BookApiService.searchBooksCombined(keyword);
      setState(() => _searchResults = results);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("도서 검색 중 문제가 발생했습니다.")),
      );
    }
  }

  void _selectBook(BookModel book) {
    setState(() {
      _selectedBook = book;
      _searchResults = []; // 선택 후 리스트 닫기
    });
    widget.onBookChanged(book);
  }

  void _removeBook() {
    setState(() => _selectedBook = null);
    widget.onBookChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    final screenHeight = MediaQuery
        .of(context)
        .size
        .height;

    final fontSize = screenWidth * 0.037;
    final padding = screenWidth * 0.035;
    final imageWidth = screenWidth * 0.12;
    final imageHeight = imageWidth * 1.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 검색창
        TextField(
          controller: _searchController,
          onSubmitted: _handleSearch,
          style: TextStyle(color: Colors.white, fontSize: fontSize),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(
                vertical: padding * 0.8, horizontal: padding),
            prefixIcon: IconButton(
              icon: Icon(Icons.search, color: Colors.white, size: fontSize + 4),
              onPressed: () => _handleSearch(_searchController.text),
            ),
            hintText: "책 제목 / 작가를 입력하세요",
            hintStyle: TextStyle(color: Colors.white54, fontSize: fontSize),
            filled: true,
            fillColor: Colors.white12,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        // 검색 결과 리스트
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: _searchResults.isNotEmpty
              ? EdgeInsets.only(top: padding)
              : EdgeInsets.zero,
          height: _searchResults.isNotEmpty ? screenHeight * 0.25 : 0,
          child: _searchResults.isNotEmpty
              ? Container(
            padding: EdgeInsets.all(padding * 0.7),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final book = _searchResults[index];
                final isSelected = _selectedBook?.id == book.id;

                return ListTile(
                  tileColor: isSelected ? Colors.amber.withOpacity(0.2) : null,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      (book.imageUrl?.isNotEmpty ?? false)
                          ? book.imageUrl!
                          : 'https://upload.wikimedia.org/wikipedia/commons/6/65/No-Image-Placeholder.svg',
                      width: imageWidth,
                      height: imageHeight,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: imageWidth,
                          height: imageHeight,
                          color: Colors.grey.shade800,
                          child: Icon(
                              Icons.image_not_supported, color: Colors.white54,
                              size: fontSize),
                        );
                      },
                    ),
                  ),
                  title: Text(book.title,
                      style: TextStyle(color: Colors.white,
                          fontSize: fontSize,
                          fontFamily: 'kopub')),
                  subtitle: Text(book.author,
                      style: TextStyle(color: Colors.white60,
                          fontSize: fontSize * 0.9,
                          fontFamily: 'kopub')),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: Colors.amberAccent,
                      size: fontSize + 4)
                      : null,
                  onTap: () => _selectBook(book),
                );
              },
            ),
          )
              : const SizedBox.shrink(),
        ),

        SizedBox(height: padding * 1.2),

        if (_selectedBook != null)
          Stack(
            children: [
              Container(
                margin: EdgeInsets.only(top: padding * 0.8),
                padding: EdgeInsets.all(padding),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        (_selectedBook!.imageUrl?.isNotEmpty ?? false)
                            ? _selectedBook!.imageUrl!
                            : 'https://upload.wikimedia.org/wikipedia/commons/6/65/No-Image-Placeholder.svg',
                        width: imageWidth + 10,
                        height: imageHeight + 10,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: imageWidth + 10,
                            height: imageHeight + 10,
                            color: Colors.grey.shade800,
                            child: Icon(Icons.image_not_supported,
                                color: Colors.white54, size: fontSize),
                          );
                        },
                      ),
                    ),
                    SizedBox(width: padding),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedBook!.title,
                              style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: fontSize)),
                          Text(_selectedBook!.author,
                              style: TextStyle(color: Colors.white70,
                                  fontSize: fontSize * 0.9)),
                        ],
                      ),
                    ),
                    if (_selectedBook!.pageCount != null)
                      Text('${_selectedBook!.pageCount}쪽',
                          style: TextStyle(color: Colors.white70,
                              fontSize: fontSize * 0.85)),
                  ],
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: _removeBook,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, color: Colors.redAccent,
                        size: fontSize + 3),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
