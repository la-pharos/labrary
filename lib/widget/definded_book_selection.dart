import 'package:flutter/material.dart';
import 'package:dayverse_book/model/book_model.dart';

class DefinedBookSelection extends StatelessWidget {
  final List<BookModel> books;
  final List<BookModel> savedBooks;

  const DefinedBookSelection({
    super.key,
    required this.books,
    required this.savedBooks,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final titleFontSize = screenWidth * 0.045; // 약 16~20 사이
    final textFontSize = screenWidth * 0.035; // 약 13~15
    final smallFontSize = screenWidth * 0.03;  // 약 11~13
    final imageWidth = screenWidth * 0.13;     // 약 50px
    final imageHeight = imageWidth * 1.45;
    final horizontalPadding = screenWidth * 0.05;

    final List<BookModel> enrichedBooks = books.map((book) {
      final matched = savedBooks.firstWhere(
            (s) => s.id == book.id,
        orElse: () => book,
      );
      return book.copyWith(
        imageUrl: matched.imageUrl ?? book.imageUrl,
        pageCount: matched.pageCount ?? book.pageCount,
        rereadCount: matched.rereadCount ?? book.rereadCount,
        pageRead: matched.pageRead ?? book.pageRead,
      );
    }).toList();

    return AlertDialog(
      backgroundColor: const Color(0xFF1B2C2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        "읽을 책을 선택하세요",
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'kopub',
          fontWeight: FontWeight.bold,
          fontSize: titleFontSize,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: enrichedBooks.length,
          separatorBuilder: (_, __) => SizedBox(height: screenHeight * 0.01),
          itemBuilder: (_, index) {
            final book = enrichedBooks[index];
            final hasImage = book.imageUrl != null && book.imageUrl!.startsWith('http');
            final pageCount = book.pageCount ?? 0;
            final pageRead = book.pageRead ?? 0;
            final isDone = (pageCount > 0 && pageRead >= pageCount);
            final percent = pageCount > 0 ? (pageRead / pageCount * 100).clamp(0, 100).toInt() : 0;

            return GestureDetector(
              onTap: () => Navigator.of(context).pop(book),
              child: Container(
                decoration: BoxDecoration(
                  color: isDone ? Colors.green.withOpacity(0.15) : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.all(horizontalPadding * 0.4),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: hasImage
                          ? Image.network(
                        book.imageUrl!,
                        width: imageWidth,
                        height: imageHeight,
                        fit: BoxFit.cover,
                      )
                          : Container(
                        width: imageWidth,
                        height: imageHeight,
                        color: Colors.grey,
                        child: const Icon(Icons.book, color: Colors.white),
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.03),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDone ? Colors.greenAccent : Colors.white,
                              fontSize: textFontSize,
                              fontFamily: 'kopub',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.005),
                          Text(
                            book.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: smallFontSize,
                              fontFamily: 'kopub',
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.005),
                          Text(
                            pageCount > 0
                                ? "$pageRead / $pageCount 페이지 ($percent%)"
                                : "페이지 정보 없음",
                            style: TextStyle(
                              color: isDone ? Colors.greenAccent : Colors.white54,
                              fontSize: smallFontSize,
                              fontFamily: 'kopub',
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isDone) ...[
                      SizedBox(width: screenWidth * 0.02),
                      const Icon(Icons.check_circle, color: Colors.greenAccent),
                    ]
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}