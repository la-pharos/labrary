import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import '../screen/book_detail_screen.dart';

class NoteSearchScreen extends StatefulWidget {
  const NoteSearchScreen({super.key});

  @override
  State<NoteSearchScreen> createState() => _NoteSearchScreenState();
}

class _NoteSearchScreenState extends State<NoteSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<BookModel> _filteredBooks = [];

  @override
  void initState() {
    super.initState();
    _applyFilter("");
  }

  void _applyFilter(String query) {
    final provider = Provider.of<SavedBooksProvider>(context, listen: false);
    final allBooks = provider.savedBooks;

    setState(() {
      final lower = query.toLowerCase();

      _filteredBooks = allBooks.where((book) {
        final notes = provider.getRecordsForBook(book.id)
            .where((r) => r['content'] != '독서 타이머 기록')
            .toList();

        final hasNote = notes.isNotEmpty;
        final matchesQuery = book.title.toLowerCase().contains(lower) ||
            book.author.toLowerCase().contains(lower);

        return hasNote && matchesQuery;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final horizontalPadding = screenWidth * 0.04;
    final verticalPadding = screenHeight * 0.02;

    final provider = Provider.of<SavedBooksProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFF013328),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: screenWidth * 0.06),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "기록 검색",
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'kopub',
            fontSize: screenWidth * 0.05,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding * 0.6),
            child: TextField(
              controller: _searchController,
              onChanged: _applyFilter,
              style: TextStyle(color: Colors.white, fontSize: screenWidth * 0.042),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white24,
                hintText: "책 제목 / 작가를 입력하세요",
                hintStyle: TextStyle(color: Colors.white54, fontSize: screenWidth * 0.04),
                prefixIcon: Icon(Icons.search, color: Colors.white54, size: screenWidth * 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _filteredBooks.isEmpty
                ? Center(
              child: Text(
                "검색된 책이 없습니다.",
                style: TextStyle(
                  color: Colors.white54,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.042,
                ),
              ),
            )
                : ListView.builder(
              itemCount: _filteredBooks.length,
              itemBuilder: (context, index) {
                final book = _filteredBooks[index];
                final notes = provider
                    .getRecordsForBook(book.id)
                    .where((r) => r['content'] != '독서 타이머 기록')
                    .toList();

                return ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding * 0.4),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: book.imageUrl != null && book.imageUrl!.isNotEmpty
                        ? Image.network(
                      book.imageUrl!,
                      width: screenWidth * 0.13,
                      height: screenHeight * 0.12,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: screenWidth * 0.13,
                        height: screenHeight * 0.12,
                        color: Colors.grey,
                        child: Icon(Icons.book, color: Colors.white, size: screenWidth * 0.07),
                      ),
                    )
                        : Container(
                      width: screenWidth * 0.13,
                      height: screenHeight * 0.12,
                      color: Colors.grey,
                      child: Icon(Icons.book, color: Colors.white, size: screenWidth * 0.07),
                    ),
                  ),
                  title: Text(
                    book.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'kopub',
                      fontSize: screenWidth * 0.044,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    book.author,
                    style: TextStyle(
                      color: Colors.white54,
                      fontFamily: 'kopub',
                      fontSize: screenWidth * 0.036,
                    ),
                  ),
                  trailing: Text(
                    "노트 ${notes.length}개",
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontFamily: 'kopub',
                      fontSize: screenWidth * 0.032,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)),
                    );
                    _applyFilter(_searchController.text);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
