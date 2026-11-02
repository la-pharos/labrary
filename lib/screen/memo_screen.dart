import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/model/memo_model.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/screen/book_detail_screen.dart';
import 'package:dayverse_book/screen/memo_edit_screen.dart';
import 'package:dayverse_book/screen/share_note_screen.dart';
import 'package:dayverse_book/widget/ad_banner_placeholder.dart';
import 'package:dayverse_book/widget/card_box.dart';

enum MemoSortType {
  newestCreated,
  oldestCreated,
  recentlyUpdated,
}

class MemoScreen extends StatefulWidget {
  const MemoScreen({
    super.key,
  });

  @override
  State<MemoScreen> createState() => _MemoScreenState();
}

class _MemoScreenState extends State<MemoScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  MemoSortType _sortType = MemoSortType.newestCreated;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SavedBooksProvider>();

    final screenWidth = MediaQuery.of(context).size.width;

    final filteredMemos = _getFilteredMemos(provider);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;

        if (velocity > 500) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF013328),
        appBar: _buildAppBar(
          screenWidth,
        ),
        body: Column(
          children: [
            Expanded(
              child: SafeArea(
                top: false,
                bottom: false,
                child: Column(
                  children: [
                    _buildSearchField(
                      screenWidth,
                    ),
                    Expanded(
                      child: filteredMemos.isEmpty
                          ? _buildEmptyState(
                              screenWidth: screenWidth,
                              hasSearchQuery: _searchQuery.trim().isNotEmpty,
                            )
                          : _buildMemoList(
                              provider: provider,
                              memos: filteredMemos,
                              screenWidth: screenWidth,
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SafeArea(
              top: false,
              child: BottomAdBannerBar(),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    double screenWidth,
  ) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () {
          Navigator.pop(context);
        },
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
      title: Text(
        '메모',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'kopub',
          fontSize: screenWidth * 0.05,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      actions: [
        PopupMenuButton<MemoSortType>(
          tooltip: '메모 정렬',
          icon: const Icon(
            Icons.sort_rounded,
            color: Colors.white70,
          ),
          color: const Color(0xFF1B2C2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onSelected: (sortType) {
            setState(() {
              _sortType = sortType;
            });
          },
          itemBuilder: (_) => [
            _buildSortMenuItem(
              value: MemoSortType.newestCreated,
              icon: Icons.arrow_downward_rounded,
              title: '최신 등록순',
            ),
            _buildSortMenuItem(
              value: MemoSortType.oldestCreated,
              icon: Icons.arrow_upward_rounded,
              title: '오래된 등록순',
            ),
            _buildSortMenuItem(
              value: MemoSortType.recentlyUpdated,
              icon: Icons.update_rounded,
              title: '최근 수정순',
            ),
          ],
        ),
        SizedBox(
          width: screenWidth * 0.015,
        ),
      ],
    );
  }

  PopupMenuItem<MemoSortType> _buildSortMenuItem({
    required MemoSortType value,
    required IconData icon,
    required String title,
  }) {
    final isSelected = _sortType == value;

    return PopupMenuItem<MemoSortType>(
      value: value,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.amberAccent.withOpacity(0.14)
                  : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.amberAccent : Colors.white70,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.amberAccent : Colors.white,
                fontFamily: 'kopub',
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (isSelected)
            const Icon(
              Icons.check_rounded,
              color: Colors.amberAccent,
              size: 19,
            ),
        ],
      ),
    );
  }

  List<MemoModel> _getFilteredMemos(
    SavedBooksProvider provider,
  ) {
    final normalizedQuery = _searchQuery.trim().toLowerCase();

    final memos = List<MemoModel>.from(
      provider.allMemos,
    );

    final filtered = normalizedQuery.isEmpty
        ? memos
        : memos.where((memo) {
            final book = provider.getBookByIdOrNull(
              memo.bookId,
            );

            final memoMatches = memo.content.toLowerCase().contains(
                  normalizedQuery,
                );

            final titleMatches = book?.title.toLowerCase().contains(
                      normalizedQuery,
                    ) ??
                false;

            final authorMatches = book?.author.toLowerCase().contains(
                      normalizedQuery,
                    ) ??
                false;

            return memoMatches || titleMatches || authorMatches;
          }).toList();

    switch (_sortType) {
      case MemoSortType.newestCreated:
        filtered.sort(
          (a, b) => b.createdAt.compareTo(a.createdAt),
        );
        break;

      case MemoSortType.oldestCreated:
        filtered.sort(
          (a, b) => a.createdAt.compareTo(b.createdAt),
        );
        break;

      case MemoSortType.recentlyUpdated:
        filtered.sort(
          (a, b) => b.updatedAt.compareTo(a.updatedAt),
        );
        break;
    }

    return filtered;
  }

  Widget _buildSearchField(
    double screenWidth,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        screenWidth * 0.045,
        screenWidth * 0.02,
        screenWidth * 0.045,
        screenWidth * 0.025,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'kopub',
          fontSize: screenWidth * 0.034,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withOpacity(0.09),
          hintText: '책 제목, 작가, 메모 내용 검색',
          hintStyle: TextStyle(
            color: Colors.white38,
            fontFamily: 'kopub',
            fontSize: screenWidth * 0.032,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Colors.white54,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();

                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white54,
                  ),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildMemoList({
    required SavedBooksProvider provider,
    required List<MemoModel> memos,
    required double screenWidth,
  }) {
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        screenWidth * 0.045,
        0,
        screenWidth * 0.045,
        screenWidth * 0.05,
      ),
      itemCount: memos.length,
      separatorBuilder: (_, __) {
        return SizedBox(
          height: screenWidth * 0.025,
        );
      },
      itemBuilder: (context, index) {
        final memo = memos[index];

        final book = provider.getBookByIdOrNull(
          memo.bookId,
        );

        if (book == null) {
          return const SizedBox.shrink();
        }

        return _buildMemoCard(
          book: book,
          memo: memo,
          screenWidth: screenWidth,
        );
      },
    );
  }

  Widget _buildMemoCard({
    required BookModel book,
    required MemoModel memo,
    required double screenWidth,
  }) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(
        screenWidth * 0.04,
      ),
      onTap: () {
        _openMemo(
          book: book,
          memo: memo,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 날짜 + 메모 메뉴
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.022,
                  vertical: screenWidth * 0.012,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      color: Colors.white,
                      size: screenWidth * 0.032,
                    ),
                    SizedBox(
                      width: screenWidth * 0.012,
                    ),
                    Text(
                      _formatMemoDate(
                        memo.createdAt,
                      ),
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'kopub',
                        fontSize: screenWidth * 0.028,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (memo.imageUrls.isNotEmpty) ...[
                SizedBox(
                  width: screenWidth * 0.015,
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.018,
                    vertical: screenWidth * 0.011,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        color: Colors.white54,
                        size: screenWidth * 0.031,
                      ),
                      SizedBox(
                        width: screenWidth * 0.007,
                      ),
                      Text(
                        '${memo.imageUrls.length}',
                        style: TextStyle(
                          color: Colors.white54,
                          fontFamily: 'kopub',
                          fontSize: screenWidth * 0.026,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '메모 열기',
                style: TextStyle(
                  color: Colors.white38,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.028,
                ),
              ),
              SizedBox(
                width: screenWidth * 0.006,
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white38,
                size: screenWidth * 0.045,
              ),
            ],
          ),

          SizedBox(
            height: screenWidth * 0.028,
          ),

          // 2. 책 정보
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(
              screenWidth * 0.025,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.045),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
              ),
            ),
            child: Row(
              children: [
                _buildBookCover(
                  book: book,
                  width: screenWidth * 0.10,
                  height: screenWidth * 0.14,
                ),
                SizedBox(
                  width: screenWidth * 0.025,
                ),
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
                          fontSize: screenWidth * 0.033,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                      if (book.author.trim().isNotEmpty) ...[
                        SizedBox(
                          height: screenWidth * 0.008,
                        ),
                        Text(
                          book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white54,
                            fontFamily: 'kopub',
                            fontSize: screenWidth * 0.027,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            height: screenWidth * 0.03,
          ),

          // 3. 메모 내용
          if (memo.content.trim().isNotEmpty)
            Text(
              memo.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.035,
                height: 1.65,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBookCover({
    required BookModel book,
    required double width,
    required double height,
  }) {
    final imageUrl = book.imageUrl?.trim() ?? '';

    final highResolutionImageUrl = imageUrl.replaceAll(
      'coversum',
      'cover',
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: highResolutionImageUrl.startsWith('http')
            ? Image.network(
                highResolutionImageUrl,
                width: width,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return _buildCoverFallback(
                    width,
                    height,
                  );
                },
              )
            : _buildCoverFallback(
                width,
                height,
              ),
      ),
    );
  }

  Widget _buildCoverFallback(
    double width,
    double height,
  ) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade700,
      child: const Icon(
        Icons.book_rounded,
        color: Colors.white54,
      ),
    );
  }

  Widget _buildEmptyState({
    required double screenWidth,
    required bool hasSearchQuery,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(
          screenWidth * 0.08,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: screenWidth * 0.18,
              height: screenWidth * 0.18,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasSearchQuery
                    ? Icons.search_off_rounded
                    : Icons.edit_note_rounded,
                color: Colors.white38,
                size: screenWidth * 0.085,
              ),
            ),
            SizedBox(
              height: screenWidth * 0.04,
            ),
            Text(
              hasSearchQuery ? '검색 결과가 없습니다.' : '작성한 독서 메모가 없습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.038,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(
              height: screenWidth * 0.018,
            ),
            Text(
              hasSearchQuery
                  ? '다른 검색어로 다시 찾아보세요.'
                  : '책 상세 화면에서 기억하고 싶은\n문장과 생각을 남겨보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.031,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMemo({
    required BookModel book,
    required MemoModel memo,
  }) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MemoEditScreen(
          book: book,
          memo: memo,
        ),
      ),
    );

    if (!mounted) return;

    if (updated == true) {
      setState(() {});
    }
  }

  String _formatMemoDate(
    DateTime date,
  ) {
    return '${date.year}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.day.toString().padLeft(2, '0')}';
  }


}
