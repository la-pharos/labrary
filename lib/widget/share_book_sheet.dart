import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/screen/share_note_screen.dart';
import 'package:dayverse_book/screen/share_reading_screen.dart';

Future<void> showBookShareSheet({
  required BuildContext context,
  required BookModel book,
}) async {
  final provider = context.read<SavedBooksProvider>();

  final memos = provider
      .getRecordsForBook(book.id)
      .where(
        (record) =>
    (record['content'] ?? '').toString() !=
        '독서 타이머 기록',
  )
      .toList();

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      final screenWidth =
          MediaQuery
              .of(sheetContext)
              .size
              .width;

      return SafeArea(
        top: false,
        child: Container(
          margin: EdgeInsets.all(screenWidth * 0.03),
          padding: EdgeInsets.all(screenWidth * 0.045),
          decoration: BoxDecoration(
            color: const Color(0xFF1B2C2E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: screenWidth * 0.11,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius:
                    BorderRadius.circular(20),
                  ),
                ),
              ),

              SizedBox(height: screenWidth * 0.04),

              Text(
                '공유하기',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: screenWidth * 0.03),

              _ShareOptionTile(
                icon: Icons.auto_stories_rounded,
                title: '독서 상태 공유',
                description:
                '해당 책의 독서 현황 상태를 카드로 공유해요.',
                onTap: () {
                  Navigator.of(sheetContext).pop();

                  Future<void>.delayed(
                    const Duration(milliseconds: 180),
                        () {
                      if (!context.mounted) return;

                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ShareReadingScreen(
                            book: book,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              SizedBox(height: screenWidth * 0.02),

              _ShareOptionTile(
                icon: Icons.edit_note_rounded,
                title: '메모 공유',
                description: memos.isEmpty
                    ? '공유할 메모가 없어요.'
                    : '공유할 메모 하나를 선택해요.',
                enabled: memos.isNotEmpty,
                onTap: () {
                  Navigator.of(sheetContext).pop();

                  _handleMemoShare(
                    context: context,
                    book: book,
                    memos: memos,
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
  Future<void> _handleMemoShare({
    required BuildContext context,
    required BookModel book,
    required List<Map<String, dynamic>> memos,
  }) async {
    if (memos.isEmpty) return;

    if (memos.length == 1) {
      _openShareNoteScreen(
        context: context,
        book: book,
        memo: memos.first,
      );
      return;
    }

    await _showMemoSelectionSheet(
      context: context,
      book: book,
      memos: memos,
    );
  }

  void _openShareNoteScreen({
    required BuildContext context,
    required BookModel book,
    required Map<String, dynamic> memo,
  }) {
    final content =
    (memo['content'] ?? '').toString();

    final savedAt = DateTime.tryParse(
      (memo['savedAt'] ?? '').toString(),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShareNoteScreen(
          book: book,
          memoContent: content,
          savedAt: savedAt,
        ),
      ),
    );
  }

  Future<void> _showMemoSelectionSheet({
    required BuildContext context,
    required BookModel book,
    required List<Map<String, dynamic>> memos,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final screenWidth =
            MediaQuery.of(sheetContext).size.width;

        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight:
              MediaQuery.of(sheetContext).size.height *
                  0.72,
            ),
            margin: EdgeInsets.all(screenWidth * 0.03),
            padding: EdgeInsets.all(screenWidth * 0.04),
            decoration: BoxDecoration(
              color: const Color(0xFF1B2C2E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  '공유할 메모 선택',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'kopub',
                    fontWeight: FontWeight.bold,
                    fontSize: screenWidth * 0.043,
                  ),
                ),

                SizedBox(height: screenWidth * 0.025),

                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: memos.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(
                          height: screenWidth * 0.02,
                        ),
                    itemBuilder: (context, index) {
                      final memo = memos[index];

                      final content =
                      (memo['content'] ?? '')
                          .toString();

                      final savedAt =
                      DateTime.tryParse(
                        (memo['savedAt'] ?? '')
                            .toString(),
                      );

                      final dateText = savedAt == null
                          ? ''
                          : DateFormat(
                        'yyyy.MM.dd',
                      ).format(savedAt);

                      return InkWell(
                        onTap: () {
                          Navigator.of(sheetContext).pop();

                          _openShareNoteScreen(
                            context: context,
                            book: book,
                            memo: memo,
                          );
                        },
                        borderRadius:
                        BorderRadius.circular(12),
                        child: Container(
                          padding: EdgeInsets.all(
                            screenWidth * 0.035,
                          ),
                          decoration: BoxDecoration(
                            color:
                            Colors.white.withOpacity(
                              0.055,
                            ),
                            borderRadius:
                            BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              if (dateText.isNotEmpty)
                                Text(
                                  dateText,
                                  style: TextStyle(
                                    color:
                                    Colors.amberAccent,
                                    fontFamily: 'kopub',
                                    fontSize:
                                    screenWidth * 0.03,
                                    fontWeight:
                                    FontWeight.bold,
                                  ),
                                ),

                              if (dateText.isNotEmpty)
                                SizedBox(
                                  height:
                                  screenWidth * 0.015,
                                ),

                              Text(
                                content,
                                maxLines: 3,
                                overflow:
                                TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'kopub',
                                  fontSize:
                                  screenWidth * 0.034,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

class _ShareOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool enabled;

  const _ShareOptionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.all(
            screenWidth * 0.035,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(
              enabled ? 0.065 : 0.025,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(
                enabled ? 0.08 : 0.04,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: screenWidth * 0.105,
                height: screenWidth * 0.105,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(
                    enabled ? 0.08 : 0.035,
                  ),
                  borderRadius:
                  BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: enabled
                      ? Colors.amberAccent
                      : Colors.white24,
                ),
              ),

              SizedBox(width: screenWidth * 0.03),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: enabled
                            ? Colors.white
                            : Colors.white30,
                        fontFamily: 'kopub',
                        fontWeight: FontWeight.bold,
                        fontSize:
                        screenWidth * 0.037,
                      ),
                    ),

                    SizedBox(
                      height: screenWidth * 0.008,
                    ),

                    Text(
                      description,
                      style: TextStyle(
                        color: enabled
                            ? Colors.white54
                            : Colors.white24,
                        fontFamily: 'kopub',
                        fontSize:
                        screenWidth * 0.03,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right_rounded,
                color: enabled
                    ? Colors.white38
                    : Colors.white12,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

