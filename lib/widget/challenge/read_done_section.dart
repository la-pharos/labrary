import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';

class ReadDoneSection extends StatefulWidget {
  final Challenge challenge;
  final bool isDoneMode;
  final List<String>? completedBookIds;
  final List<BookModel>? booksOverride; // ✅ 실제 필드로 반영

  const ReadDoneSection({
    super.key,
    required this.challenge,
    this.isDoneMode = false,
    this.completedBookIds,
    this.booksOverride, // ✅
  });

  @override
  State<ReadDoneSection> createState() => _ReadDoneSectionState();
}

class _ReadDoneSectionState extends State<ReadDoneSection> {
  bool _isExpanded = false;

  // ✅ id > isbn 기준 키 통일
  String? _keyForBook(BookModel b) {
    if (b.id.isNotEmpty) return b.id;
    final isbn = b.isbn;
    if (isbn != null && isbn.isNotEmpty) return isbn;
    return null;
  }

  // ✅ 타겟 도서 해석 (override > participating > required)
  List<BookModel> _resolveTargetBooks() {
    if (widget.booksOverride != null && widget.booksOverride!.isNotEmpty) {
      return widget.booksOverride!;
    }
    if ((widget.challenge.participatingBooks ?? []).isNotEmpty) {
      return widget.challenge.participatingBooks!;
    }
    return widget.challenge.requiredBooks ?? const <BookModel>[];
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 1) 권수형에서만 노출
    if (widget.challenge.method != ChallengeMethod.quantityBased) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final titleFontSize = screenWidth * 0.035;
    final textFontSize = screenWidth * 0.03;
    final subTextFontSize = screenWidth * 0.03;
    final bookWidth = screenWidth * 0.23;
    final bookHeight = bookWidth * 1.35;
    final sectionSpacing = screenWidth * 0.03;

    // 마지막 attempt
    final attempt = widget.challenge.attempts.isNotEmpty ? widget.challenge.attempts.last : null;
    if (attempt == null) return const SizedBox.shrink();

    // ✅ 2) 기간 계산 보정
    DateTime? start = widget.challenge.startDate?.toLocal();
    DateTime? end   = widget.challenge.endDate?.toLocal();

    if (start == null) start = attempt.startDate.toLocal();
    if (end == null) {
      if (attempt.endDate != null) {
        end = attempt.endDate!.toLocal();
      } else if (attempt.selectedDuration != null) {
        final s = DateTime(start.year, start.month, start.day);
        end = s.add(Duration(days: attempt.selectedDuration! - 1));
      }
    }
    if (start == null || end == null) {
      return const SizedBox.shrink();
    }

    final savedBooks = context.read<SavedBooksProvider>().savedBooks;

    // ✅ 3) 타겟 키셋 준비(풀/참여/필수 도서로 제한) — 없으면 전체 허용
    final targets = _resolveTargetBooks();
    final targetKeys = targets.map(_keyForBook).whereType<String>().toSet();
    final hasTargetFilter = targetKeys.isNotEmpty;

    // ✅ 4) 표시할 책 id 목록 산출
    final booksToShowIds = widget.isDoneMode
        ? (widget.completedBookIds ?? attempt.completedBookIds)
        : savedBooks
        .where((book) {
      final completedAt = book.endDate?.toLocal();
      final inPeriod = book.category == 'done' &&
          completedAt != null &&
          !completedAt.isBefore(start!) &&
          !completedAt.isAfter(end!);

      if (!inPeriod) return false;

      // 타겟 제한(있을 때만) 적용: id>isbn 키 기준
      if (!hasTargetFilter) return true;
      final k = _keyForBook(book);
      return k != null && targetKeys.contains(k);
    })
        .map((b) => b.id)
        .toList();

    final completedBooksInPeriod =
    savedBooks.where((b) => booksToShowIds.contains(b.id)).toList();

    // ✅ 5) 안전한 문자열 보간
    final sectionTitle =
        "🔸 도전기간 내 읽은 책${completedBooksInPeriod.isNotEmpty ? " (${completedBooksInPeriod.length}권)" : ""}";

    final isOverflow = completedBooksInPeriod.length > 6;
    final booksToDisplay = _isExpanded || !isOverflow
        ? completedBooksInPeriod
        : completedBooksInPeriod.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sectionTitle,
          style: TextStyle(
            color: Colors.white,
            fontSize: titleFontSize,
            fontFamily: 'kopub',
          ),
        ),
        SizedBox(height: sectionSpacing),
        if (completedBooksInPeriod.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: sectionSpacing * 0.6),
            child: Text(
              "아직 도전 기간 동안 완독한 책이 없어요.",
              style: TextStyle(color: Colors.white70, fontSize: textFontSize),
            ),
          )
        else
          Container(
            width: screenWidth,
            padding: EdgeInsets.symmetric(
              horizontal: sectionSpacing,
              vertical: sectionSpacing * 1.2,
            ),
            margin: EdgeInsets.only(bottom: sectionSpacing),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: screenWidth * 0.04,
                  runSpacing: screenWidth * 0.05,
                  children: booksToDisplay.map((book) {
                    return Container(
                      width: bookWidth + 10,
                      padding: EdgeInsets.all(sectionSpacing * 0.6),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: (book.imageUrl?.isNotEmpty == true)
                                ? Image.network(
                              book.imageUrl!,
                              width: bookWidth,
                              height: bookHeight,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: bookWidth,
                                  height: bookHeight,
                                  color: Colors.grey,
                                  child: const Icon(Icons.broken_image,
                                      color: Colors.white54),
                                );
                              },
                            )
                                : Container(
                              width: bookWidth,
                              height: bookHeight,
                              color: Colors.grey,
                              child: const Icon(Icons.book,
                                  color: Colors.white54),
                            ),
                          ),
                          SizedBox(height: sectionSpacing * 0.4),
                          Text(
                            book.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: textFontSize,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            book.author,
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: subTextFontSize,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                if (isOverflow) ...[
                  SizedBox(height: sectionSpacing * 0.6),
                  TextButton(
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    child: const Text(
                      "더 보기",
                      style: TextStyle(color: Colors.white, fontFamily: 'kopub'),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}