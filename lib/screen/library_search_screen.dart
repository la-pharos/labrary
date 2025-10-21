import 'package:flutter/material.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/screen/book_detail_screen.dart';
import 'package:dayverse_book/widget/ad_banner_placeholder.dart';

class LibrarySearchScreen extends StatefulWidget {
  final List<BookModel> savedBooks;

  const LibrarySearchScreen({super.key, required this.savedBooks});

  @override
  _LibrarySearchScreenState createState() => _LibrarySearchScreenState();
}

class _LibrarySearchScreenState extends State<LibrarySearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  late List<BookModel> _filteredBooks;

  @override
  void initState() {
    super.initState();
    _filteredBooks = widget.savedBooks;
  }

  void _filterBooks(String query) {
    final allBooks = widget.savedBooks;
    setState(() {
      if (query.isEmpty) {
        _filteredBooks = allBooks;
      } else {
        _filteredBooks = allBooks.where((book) {
          final title = book.title.toLowerCase();
          final author = book.author.toLowerCase();
          return title.contains(query.toLowerCase()) || author.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final isWide = width > 600;
    final horizontalPadding = width * 0.05;
    final imageWidth = isWide ? 70.0 : 50.0;
    final imageHeight = isWide ? 100.0 : 70.0;
    final titleFontSize = isWide ? 18.0 : 16.0;
    final authorFontSize = isWide ? 16.0 : 14.0;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 20) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF013328),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            "서재 내 도서 검색",
            style: TextStyle(color: Colors.white, fontSize: isWide ? 22 : 20),
          ),
          centerTitle: true,
        ),

        body: Stack(
          children: [
            // ✅ 전체 높이 확보
            SizedBox(
              height: height,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: height * 0.08,
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _filterBooks,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white24,
                            hintText: "책 제목 / 작가를 입력하세요",
                            hintStyle: const TextStyle(color: Colors.white54),
                            prefixIcon: const Icon(Icons.search, color: Colors.white54),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _filteredBooks.isEmpty
                          ? Padding(
                        padding: const EdgeInsets.only(top: 100),
                        child: Text(
                          "검색된 책이 없습니다.",
                          style: TextStyle(color: Colors.white54, fontSize: titleFontSize),
                        ),
                      )
                          : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredBooks.length,
                        itemBuilder: (context, index) {
                          final book = _filteredBooks[index];
                          final imageWidget = _buildBookImage(book, imageWidth, imageHeight);

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 6),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: imageWidget,
                            ),
                            title: Text(
                              book.title,
                              style: TextStyle(color: Colors.white, fontSize: titleFontSize),
                            ),
                            subtitle: Text(
                              book.author,
                              style: TextStyle(color: Colors.white54, fontSize: authorFontSize),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BookDetailScreen(book: book),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // ✅ 하단 고정 광고
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BottomAdBannerBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookImage(BookModel book, double width, double height) {
    if (book.imageFile != null) {
      return Image.file(
        book.imageFile!,
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    } else if (book.imageUrl != null && book.imageUrl!.isNotEmpty) {
      return Image.network(
        book.imageUrl!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: width,
          height: height,
          color: Colors.grey,
          child: const Icon(Icons.book, color: Colors.white, size: 30),
        ),
      );
    } else {
      return Container(
        width: width,
        height: height,
        color: Colors.grey,
        child: const Icon(Icons.book, color: Colors.white, size: 30),
      );
    }
  }
}
