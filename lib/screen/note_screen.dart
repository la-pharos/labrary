import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/screen/book_detail_screen.dart';
import 'package:dayverse_book/widget/ad_banner_placeholder.dart';

class NoteScreen extends StatefulWidget {
  const NoteScreen({super.key});

  @override
  State<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final savedBooksProvider = context.watch<SavedBooksProvider>();
    final books = savedBooksProvider.savedBooks;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final horizontalPadding = screenWidth * 0.045;
    final imageWidth = screenWidth * 0.145;
    final imageHeight = imageWidth * 1.4;
    final fontSizeTitle = screenWidth * 0.035;
    final fontSizeSubtitle = screenWidth * 0.03;
    final fontSizeNote = screenWidth * 0.03;

    final booksWithNotes = books.where((book) {
      final notes = savedBooksProvider.getRecordsForBook(book.id)
          .where((r) => r['content'] != '독서 타이머 기록')
          .toList();
      final hasNote = notes.isNotEmpty;
      final matchesQuery = _searchQuery.isEmpty ||
          book.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          book.author.toLowerCase().contains(_searchQuery.toLowerCase());
      return hasNote && matchesQuery;
    }).toList();

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
          centerTitle: true,
          title: Text(
            "NOTE",
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),

        body: Stack(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height, // <-- 이거 한 줄!
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: screenHeight * 0.08,
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: screenHeight * 0.01,
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (query) {
                            setState(() => _searchQuery = query);
                          },
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
                            contentPadding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
                          ),
                        ),
                      ),
                      if (booksWithNotes.isEmpty)
                        SizedBox(
                          height: screenHeight * 0.75,
                          child: Center(
                            child: Text(
                              "작성한 독서 노트가 없습니다.\n지금 첫 노트를 작성해보세요!",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: fontSizeSubtitle,
                                fontFamily: 'kopub',
                              ),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.all(horizontalPadding),
                          itemCount: booksWithNotes.length,
                          itemBuilder: (context, index) {
                            final book = booksWithNotes[index];
                            final notes = savedBooksProvider
                                .getRecordsForBook(book.id)
                                .where((r) => r['content'] != '독서 타이머 기록')
                                .toList();
              
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BookDetailScreen(book: book),
                                  ),
                                );
                              },
                              child: Card(
                                color: Colors.white12,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(screenWidth * 0.035),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(5),
                                        child: book.imageUrl != null && book.imageUrl!.isNotEmpty
                                            ? Image.network(
                                          book.imageUrl!,
                                          width: imageWidth,
                                          height: imageHeight,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _defaultBookIcon(imageWidth, imageHeight),
                                        )
                                            : _defaultBookIcon(imageWidth, imageHeight),
                                      ),
                                      SizedBox(width: screenWidth * 0.04),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              book.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontFamily: 'kopub',
                                                fontSize: fontSizeTitle,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(height: screenHeight * 0.005),
                                            Text(
                                              "${book.author} • ${book.publisher}",
                                              style: TextStyle(
                                                color: Colors.white54,
                                                fontFamily: 'kopub',
                                                fontSize: fontSizeSubtitle,
                                              ),
                                            ),
                                            SizedBox(height: screenHeight * 0.005),
                                            Text(
                                              "📎 ${notes.length}개 노트",
                                              style: TextStyle(
                                                color: Colors.amberAccent,
                                                fontFamily: 'kopub',
                                                fontSize: fontSizeNote,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, color: Colors.white54),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      SizedBox(height: screenHeight * 0.04),
                    ],
                  ),
                ),
              ),
            ),

            // ✅ 하단 고정 광고 (LevelScreen과 동일)
            const Positioned(
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

  Widget _defaultBookIcon(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey,
      child: const Icon(Icons.book, color: Colors.white, size: 30),
    );
  }
}