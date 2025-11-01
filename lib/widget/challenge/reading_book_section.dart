import 'package:flutter/material.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/book_model.dart';

/// 단일+운영자 지정도서+페이지 연동 챌린지의 참여/완료 화면 공용 위젯
class ReadingBookSection extends StatelessWidget {
  final Challenge challenge;
  final List<BookModel> savedBooks;
  final bool isDoneMode;
  final List<String>? completedBookIds;

  /// ✅ 풀/참여 도서 등 외부에서 주입하는 타겟 리스트 (최우선)
  final List<BookModel>? booksOverride;

  /// ✅ 부모에서 풀/네트워크 로딩 여부를 넘기면, 제목은 즉시 노출 + 목록 대신 로딩 인디케이터 표시
  final bool isLoading;

  const ReadingBookSection({
    super.key,
    required this.challenge,
    required this.savedBooks,
    this.isDoneMode = false,
    this.completedBookIds,
    this.booksOverride,
    this.isLoading = false,
  });

  // ── 유틸: 키(id > isbn) ──────────────────────────────────────────────
  String? _keyForBook(BookModel b) {
    if (b.id.isNotEmpty) return b.id;
    final isbn = b.isbn;
    if (isbn != null && isbn.isNotEmpty) return isbn;
    return null;
  }

  // ── 유틸: savedBooks로 이미지/페이지 등 보강 ────────────────────────────
  List<BookModel> _enrichWithSaved(List<BookModel> books, List<BookModel> saved) {
    final savedMap = <String, BookModel>{
      for (final s in saved)
        if (_keyForBook(s) != null) _keyForBook(s)!: s
    };

    return books.map((b) {
      final k = _keyForBook(b);
      final sb = (k != null) ? savedMap[k] : null;
      if (sb == null) return b;
      return b.copyWith(
        // 비어있을 때만 보강
        imageUrl: (b.imageUrl?.isNotEmpty == true) ? b.imageUrl : sb.imageUrl,
        pageCount: (b.pageCount != null && b.pageCount! > 0) ? b.pageCount : sb.pageCount,
        publisher: (b.publisher?.isNotEmpty == true) ? b.publisher : sb.publisher,
        itemId: b.itemId ?? sb.itemId,
        description: b.description ?? sb.description,
      );
    }).toList();
  }

  // ── 유틸: 커버 안전 렌더링 ────────────────────────────────────────────
  Widget _cover(String? url, double w, double h) {
    if (url == null || url.isEmpty) return _fallbackBox(w, h);
    if (url.startsWith('http')) {
      return Image.network(
        url, width: w, height: h, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackBox(w, h),
      );
    }
    if (url.startsWith('assets/')) {
      return Image.asset(url, width: w, height: h, fit: BoxFit.cover);
    }
    return _fallbackBox(w, h);
  }

  Widget _fallbackBox(double w, double h) => Container(
    width: w, height: h, color: Colors.grey,
    child: const Icon(Icons.book, color: Colors.white54),
  );

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

    final isSystemDefined = challenge.specificBookMode == SpecificBookMode.systemDefined;
    final isUserDefined   = challenge.specificBookMode == SpecificBookMode.userDefined;

    // ✅ recordPages 안전 추출 (record/recordData/bookReadPages 어디에 있어도 OK)
    final Map<String, dynamic> recordPages = () {
      final rec = (challenge.attempts.isNotEmpty)
          ? (challenge.attempts.last.recordData as Map?)?.cast<String, dynamic>()
          : null;
      if (rec == null) return const <String, dynamic>{};
      if (rec['bookReadPages'] is Map) {
        return Map<String, dynamic>.from(rec['bookReadPages'] as Map);
      }
      if (rec['recordData'] is Map && (rec['recordData'] as Map)['bookReadPages'] is Map) {
        return Map<String, dynamic>.from((rec['recordData'] as Map)['bookReadPages'] as Map);
      }
      return const <String, dynamic>{};
    }();

    // ✅ 최우선: 외부에서 주입한 타겟(풀/참여/필수 변환 결과)
    List<BookModel> books;
    if (booksOverride != null && booksOverride!.isNotEmpty) {
      books = booksOverride!;
    } else if (isSystemDefined && (challenge.requiredBooks?.isNotEmpty ?? false)) {
      // 운영자 지정: 먼저 requiredBooks를 가져오고, savedBooks로 보강
      books = challenge.requiredBooks!;
    } else if (isUserDefined &&
        challenge.attempts.isNotEmpty &&
        (challenge.attempts.last.participatedBooks?.isNotEmpty ?? false)) {
      books = challenge.attempts.last.participatedBooks!;
    } else {
      books = const <BookModel>[];
    }

    // ✅ savedBooks로 이미지/페이지 보강 (모든 시나리오 공통)
    books = _enrichWithSaved(books, savedBooks);

    // ── 타이틀은 즉시 표기 ──────────────────────────────────────────────
    final title = Text(
      "🔸 읽어야 할 책",
      style: TextStyle(
        color: Colors.white,
        fontSize: titleFontSize,
        fontFamily: 'Kopub',
      ),
    );

    // ── 로딩 인디케이터 (책 목록 대신) ─────────────────────────────────
    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          SizedBox(height: spacing),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: spacing * 1.5),
              child: const SizedBox(
                width: 28, height: 28,
                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.amberAccent),
              ),
            ),
          ),
        ],
      );
    }

    // ✅ 풀 기반에서 아직 목록이 비어있을 수 있음 (부모가 setState로 다시 빌드해줄 것)
    if (books.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          SizedBox(height: spacing),
          Text(
            "목록을 불러오는 중이거나, 표시할 도서가 없어요.",
            style: TextStyle(color: Colors.white70, fontSize: infoFontSize),
          ),
        ],
      );
    }

    // ── 정상 목록 렌더 ─────────────────────────────────────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        SizedBox(height: spacing),
        ...books.map((book) {
          final pageCount = book.pageCount ?? 0;

          // savedBooks 진행도와 record 진행도 중 큰 값 사용
          final readFromBook = savedBooks.firstWhere(
                (b) => _keyForBook(b) == _keyForBook(book),
            orElse: () => book,
          ).pageRead ?? 0;

          // recordPages는 id 또는 isbn 키일 수 있음 → 둘 다 시도
          final recKeyId   = book.id;
          final recKeyIsbn = book.isbn ?? '';
          final readFromRecord = () {
            final v1 = recordPages[recKeyId];
            if (v1 != null) return int.tryParse(v1.toString()) ?? 0;
            final v2 = (recKeyIsbn.isNotEmpty) ? recordPages[recKeyIsbn] : null;
            if (v2 != null) return int.tryParse(v2.toString()) ?? 0;
            return 0;
          }();

          final pageRead = isDoneMode
              ? (book.pageCount ?? 0)
              : (readFromBook > readFromRecord ? readFromBook : readFromRecord);

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
                  child: _cover(book.imageUrl, coverWidth, coverHeight),
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