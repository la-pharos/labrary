import 'package:flutter/material.dart';
import 'package:dayverse_book/model/book_model.dart';
// 지정도서 2권 이상일 때 뜨는 다이얼로그임

class FixedBookSelectionDialog extends StatelessWidget {
  final List<BookModel> books;
  final Function(BookModel) onBookSelected;

  const FixedBookSelectionDialog({
    super.key,
    required this.books,
    required this.onBookSelected,
  });

  @override
  Widget build(BuildContext context) {
    final dialogHeight = MediaQuery.of(context).size.height * 0.3; // 화면의 60%까지 사용

    return Dialog(
      backgroundColor: const Color(0xFF0A1D27),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogHeader(context),
            const SizedBox(height: 8),
            const Text(
              "도전 중인 책 목록입니다. 읽을 책을 선택해주세요!",
              style: TextStyle(
                color: Colors.amberAccent,
                fontSize: 16,
                fontFamily: 'kopub',
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: dialogHeight,
              child: Scrollbar(
                thumbVisibility: true,
                radius: const Radius.circular(8),
                thickness: 4,
                child: ListView.builder(
                  itemCount: books.length,
                  itemBuilder: (_, index) {
                    final book = books[index];
                    return GestureDetector(
                      onTap: () => onBookSelected(book),
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
                              child: book.imageUrl != null && book.imageUrl!.isNotEmpty
                                  ? Image.network(
                                book.imageUrl!,
                                width: 50,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _fallbackImage(),
                              )
                                  : _fallbackImage(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    book.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    book.author ?? '',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (book.pageCount != null)
                                    Text(
                                      "총 ${book.pageCount}쪽",
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackImage() {
    return Container(
      width: 50,
      height: 70,
      color: Colors.grey.shade700,
      child: const Icon(Icons.book, color: Colors.white),
    );
  }

  Widget _buildDialogHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "어떤 책과 함께할까요?",
          style: TextStyle(
            fontSize: 22,
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
}
