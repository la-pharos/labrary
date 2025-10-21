import 'package:flutter/material.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/service/book_api_service.dart';

/// 여러 권 선택 가능한 도서 검색/선택 박스
/// - 기존 BookSearchSelectionBox와 UI/스타일을 최대한 동일하게 유지
/// - 검색 결과에서 탭하면 토글(add/remove)
/// - 상단/하단에 선택된 도서들이 카드 형태로 표시되고 개별 제거 가능
class MultiBookSearchSelectionBox extends StatefulWidget {
  final List<BookModel>? initialSelectedBooks;
  final ValueChanged<List<BookModel>> onBooksChanged;

  const MultiBookSearchSelectionBox({
    super.key,
    this.initialSelectedBooks,
    required this.onBooksChanged,
  });

  @override
  State<MultiBookSearchSelectionBox> createState() => _MultiBookSearchSelectionBoxState();
}

class _MultiBookSearchSelectionBoxState extends State<MultiBookSearchSelectionBox> {
  final TextEditingController _searchController = TextEditingController();
  final List<BookModel> _searchResults = [];
  final List<BookModel> _selected = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialSelectedBooks != null) {
      _selected.addAll(widget.initialSelectedBooks!);
    }
  }

  Future<void> _handleSearch(String keyword) async {
    final q = keyword.trim();
    if (q.isEmpty) {
      setState(() => _searchResults.clear());
      return;
    }
    try {
      final results = await BookApiService.searchBooksCombined(q);
      // 선택된 도서는 결과에서 그대로 보이되, 선택 표시만 켜짐
      setState(() {
        _searchResults
          ..clear()
          ..addAll(results);
      });
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("도서 검색 중 문제가 발생했습니다.")),
      );
    }
  }

  bool _isSelected(BookModel b) => _selected.any((x) => x.id == b.id);

  void _toggleBook(BookModel b) {
    setState(() {
      if (_isSelected(b)) {
        _selected.removeWhere((x) => x.id == b.id);
      } else {
        _selected.add(b);
      }
    });
    widget.onBooksChanged(List<BookModel>.from(_selected));
  }

  void _removeBook(BookModel b) {
    setState(() {
      _selected.removeWhere((x) => x.id == b.id);
    });
    widget.onBooksChanged(List<BookModel>.from(_selected));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth  = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final fontSize    = screenWidth * 0.037;
    final padding     = screenWidth * 0.035;
    final imageWidth  = screenWidth * 0.12;
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
            contentPadding: EdgeInsets.symmetric(vertical: padding * 0.8, horizontal: padding),
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
          margin: _searchResults.isNotEmpty ? EdgeInsets.only(top: padding) : EdgeInsets.zero,
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
                final selected = _isSelected(book);

                return ListTile(
                  tileColor: selected ? Colors.amber.withOpacity(0.2) : null,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      (book.imageUrl?.isNotEmpty ?? false)
                          ? book.imageUrl!
                          : 'https://upload.wikimedia.org/wikipedia/commons/6/65/No-Image-Placeholder.svg',
                      width: imageWidth,
                      height: imageHeight,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) {
                        return Container(
                          width: imageWidth,
                          height: imageHeight,
                          color: Colors.grey.shade800,
                          child: Icon(Icons.image_not_supported, color: Colors.white54, size: fontSize),
                        );
                      },
                    ),
                  ),
                  title: Text(book.title,
                      style: TextStyle(color: Colors.white, fontSize: fontSize, fontFamily: 'kopub')),
                  subtitle: Text(book.author,
                      style: TextStyle(color: Colors.white60, fontSize: fontSize * 0.9, fontFamily: 'kopub')),
                  trailing: Icon(
                    selected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: selected ? Colors.amberAccent : Colors.white38,
                    size: fontSize + 4,
                  ),
                  onTap: () => _toggleBook(book),
                );
              },
            ),
          )
              : const SizedBox.shrink(),
        ),

        SizedBox(height: padding * 1.2),

        // 선택된 도서 리스트(여러 권)
        if (_selected.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "선택한 도서 (${_selected.length}권)",
                style: TextStyle(color: Colors.white70, fontSize: fontSize * 0.95, fontFamily: 'kopub'),
              ),
              SizedBox(height: padding * 0.6),
              ..._selected.map((b) => _SelectedBookTile(
                book: b,
                onRemove: () => _removeBook(b),
                fontSize: fontSize,
                imageWidth: imageWidth,
                imageHeight: imageHeight,
                padding: padding,
              )),
            ],
          ),
      ],
    );
  }
}

class _SelectedBookTile extends StatelessWidget {
  final BookModel book;
  final VoidCallback onRemove;
  final double fontSize;
  final double imageWidth;
  final double imageHeight;
  final double padding;

  const _SelectedBookTile({
    required this.book,
    required this.onRemove,
    required this.fontSize,
    required this.imageWidth,
    required this.imageHeight,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          margin: EdgeInsets.only(top: padding * 0.8, bottom: padding * 0.2),
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
                  (book.imageUrl?.isNotEmpty ?? false)
                      ? book.imageUrl!
                      : 'https://upload.wikimedia.org/wikipedia/commons/6/65/No-Image-Placeholder.svg',
                  width: imageWidth + 10,
                  height: imageHeight + 10,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: imageWidth + 10,
                      height: imageHeight + 10,
                      color: Colors.grey.shade800,
                      child: Icon(Icons.image_not_supported, color: Colors.white54, size: fontSize),
                    );
                  },
                ),
              ),
              SizedBox(width: padding),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: fontSize)),
                    Text(book.author, style: TextStyle(color: Colors.white70, fontSize: fontSize * 0.9)),
                  ],
                ),
              ),
              if (book.pageCount != null)
                Text('${book.pageCount}쪽', style: TextStyle(color: Colors.white70, fontSize: fontSize * 0.85)),
            ],
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: const CircleAvatar(
              radius: 12,
              backgroundColor: Colors.black45,
              child: Icon(Icons.close, color: Colors.redAccent, size: 18),
            ),
          ),
        ),
      ],
    );
  }
}