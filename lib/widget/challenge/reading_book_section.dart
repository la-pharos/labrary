import 'package:flutter/material.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/book_model.dart';

/// 단일+운영자 지정도서+페이지 연동 챌린지의 참여 다이얼로그에서 사용.

class ReadingBookSection extends StatelessWidget {
  final Challenge challenge;
  final List<BookModel> savedBooks;
  final bool isDoneMode;
  final List<String>? completedBookIds; // ✅ 추가

  const ReadingBookSection({
    super.key,
    required this.challenge,
    required this.savedBooks,
    this.isDoneMode = false,
    this.completedBookIds, // ✅ 기본 null
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final titleFontSize = screenWidth * 0.035; // ≈16
    final bookTitleFontSize = screenWidth * 0.032; // ≈15
    final infoFontSize = screenWidth * 0.03; // ≈12
    final coverWidth = screenWidth * 0.14; // ≈60
    final coverHeight = coverWidth * 1.4; // ≈85
    final containerPadding = screenWidth * 0.03; // ≈12
    final spacing = screenWidth * 0.03; // ≈12

    const completeThreshold = 1.0;
    List<BookModel> books = [];

    final isSystemDefined = challenge.specificBookMode == SpecificBookMode.systemDefined;
    final isUserDefined = challenge.specificBookMode == SpecificBookMode.userDefined;

    final recordPages = challenge.attempts.isNotEmpty
        ? (challenge.attempts.last.recordData?['bookReadPages'] as Map?)?.cast<String, dynamic>() ?? {}
        : {};

    if (isSystemDefined && challenge.requiredBooks != null) {
      books = challenge.requiredBooks!.map((b) {
        final id = b.id;
        final matched = savedBooks.firstWhere(
              (s) => s.id == id,
          orElse: () => BookModel(
            id: id,
            title: b.title,
            author: b.author,
            pageCount: b.pageCount ?? 0,
          ),
        );
        return matched.copyWith(
          pageCount: matched.pageCount ?? b.pageCount ?? 0,
          imageUrl: matched.imageUrl ?? b.imageUrl,
        );
      }).toList();
    } else if (isUserDefined &&
        challenge.attempts.isNotEmpty &&
        challenge.attempts.last.participatedBooks != null) {
      books = challenge.attempts.last.participatedBooks!;
    }

    if (books.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "🔸 읽어야 할 책",
          style: TextStyle(
            color: Colors.white,
            fontSize: titleFontSize,
            fontFamily: 'Kopub',
          ),
        ),
        SizedBox(height: spacing),
        ...books.map((book) {
          final pageCount = book.pageCount ?? 0;

          final readFromBook = savedBooks.firstWhere(
                (b) => b.id == book.id,
            orElse: () => book,
          ).pageRead ?? 0;

          final readFromRecord = int.tryParse(recordPages[book.id]?.toString() ?? '') ?? 0;

          final pageRead = isDoneMode
              ? (book.pageCount ?? 0)
              : [readFromBook, readFromRecord].reduce((a, b) => a > b ? a : b);

          final percentage = pageCount > 0
              ? (pageRead / pageCount * 100).clamp(0, 100).toInt()
              : 0;

          final isDone = isDoneMode
              ? true
              : (book.isCompleted ?? false) ||
              (pageCount > 0 && pageRead >= (pageCount * completeThreshold).floor());

          final progressBar = pageCount > 0
              ? Padding(
            padding: EdgeInsets.only(top: spacing * 0.5),
            child: LinearProgressIndicator(
              value: (pageRead / pageCount).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDone ? Colors.greenAccent : Colors.amberAccent,
              ),
            ),
          )
              : const SizedBox.shrink();

          return Container(
            margin: EdgeInsets.only(bottom: spacing),
            padding: EdgeInsets.all(containerPadding),
            decoration: BoxDecoration(
              color: isDone ? Colors.green.withOpacity(0.2) : Colors.white10,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: (book.imageUrl?.isNotEmpty == true)
                      ? Image.network(
                    book.imageUrl!,
                    width: coverWidth,
                    height: coverHeight,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: coverWidth,
                        height: coverHeight,
                        color: Colors.grey,
                        child: const Icon(Icons.broken_image, color: Colors.white54),
                      );
                    },
                  )
                      : Container(
                    width: coverWidth,
                    height: coverHeight,
                    color: Colors.grey,
                    child: const Icon(Icons.book, color: Colors.white54),
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${book.title} (${book.author ?? '작자 미상'})",
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'kopub',
                          fontSize: bookTitleFontSize,
                        ),
                      ),
                      SizedBox(height: spacing * 0.5),
                      Text(
                        pageCount > 0
                            ? "$pageRead / $pageCount 페이지 ($percentage%)"
                            : "페이지 정보 없음",
                        style: TextStyle(
                          color: isDone ? Colors.greenAccent : Colors.white60,
                          fontSize: infoFontSize,
                        ),
                      ),
                      progressBar,
                    ],
                  ),
                ),
                SizedBox(width: spacing * 0.5),
                SizedBox(
                  height: coverHeight,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isDone ? Colors.greenAccent : Colors.white38,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}
