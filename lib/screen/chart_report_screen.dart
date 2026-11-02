import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:provider/provider.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/service/reading_log_service.dart';
import 'package:dayverse_book/widget/share_card_action_bar.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:dayverse_book/widget/share_card_style.dart';
import 'package:dayverse_book/service/yes24_book_service.dart';
import 'package:dayverse_book/widget/book_spine_widget.dart';

enum ChartReportType {
  monthly,
  yearly,
}

enum ChartBookDisplayType {
  cover,
  spine,
}

class ChartReportScreen extends StatefulWidget {
  final ChartReportType initialType;

  const ChartReportScreen({
    super.key,
    required this.initialType,
  });

  @override
  State<ChartReportScreen> createState() => _ChartReportScreenState();
}

class _ChartReportScreenState extends State<ChartReportScreen> {
  late ChartReportType _selectedType;

  late DateTime _selectedMonth;
  late int _selectedYear;

  final List<_ReportBookData> _reportBooks = [];

  int _completedBookCount = 0;
  int _totalReadingMinutes = 0;

  bool _isLoading = false;
  String? _errorMessage;

  int _loadRequestId = 0;

  final GlobalKey _reportCardKey =
  GlobalKey();

  bool _isProcessing = false;

  ChartBookDisplayType _selectedBookDisplayType =
      ChartBookDisplayType.cover;

  bool _isLoadingSpines = false;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _selectedType = widget.initialType;

    _selectedMonth = DateTime(
      now.year,
      now.month,
      1,
    );

    _selectedYear = now.year;

    WidgetsBinding.instance.addPostFrameCallback(
          (_) async {
        if (!mounted) {
          return;
        }

        await _loadReportData();
      },
    );
  }

  @override
  void dispose() {
    _styleScrollController.dispose();
    super.dispose();
  }

  final ScrollController _styleScrollController =
  ScrollController();

  ShareCardStyle _selectedStyle =
      ShareCardStyle.paper;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF013328),
      appBar: AppBar(
        backgroundColor: const Color(0xFF013328),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '독서 리포트',
          style: TextStyle(
            fontFamily: 'kopub',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  screenWidth * 0.05,
                  screenHeight * 0.018,
                  screenWidth * 0.05,
                  screenHeight * 0.025,
                ),
                child: Column(
                  children: [
                    _buildTypeSelector(
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
                    ),

                    SizedBox(
                      height:
                      screenHeight * 0.016,
                    ),

                    _buildPeriodNavigator(
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
                    ),

                    SizedBox(
                      height: screenHeight * 0.016,
                    ),

                    _buildBookDisplaySelector(
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
                    ),

                    SizedBox(
                      height: screenHeight * 0.02,
                    ),

                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        screenWidth * 0.02,
                        screenHeight * 0.01,
                        screenWidth * 0.02,
                        screenHeight * 0.03,
                      ),
                      child: RepaintBoundary(
                        key: _reportCardKey,
                        child: _buildReportPreview(
                          screenWidth: screenWidth,
                          screenHeight: screenHeight,
                        ),
                      ),
                    ),

                    SizedBox(
                      height: screenHeight * 0.022,
                    ),

                    _buildStyleSection(
                      screenWidth,
                    ),

                    SizedBox(
                      height: screenHeight * 0.025,
                    ),
                  ],
                ),
              ),
            ),

            ShareCardActionBar(
              isProcessing:
              _isProcessing ||
                  _isLoading,
              onSave:
              _saveReport,
              onShare:
              _shareReport,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector({
    required double screenWidth,
    required double screenHeight,
  }) {
    return Container(
      padding: EdgeInsets.all(
        screenWidth * 0.012,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeButton(
              screenWidth: screenWidth,
              screenHeight: screenHeight,
              type: ChartReportType.monthly,
              label: '월간',
            ),
          ),
          SizedBox(
            width: screenWidth * 0.012,
          ),
          Expanded(
            child: _buildTypeButton(
              screenWidth: screenWidth,
              screenHeight: screenHeight,
              type: ChartReportType.yearly,
              label: '연간',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton({
    required double screenWidth,
    required double screenHeight,
    required ChartReportType type,
    required String label,
  }) {
    final isSelected = _selectedType == type;

    return Material(
      color: isSelected ? Colors.amberAccent : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () {
          if (_selectedType == type) {
            return;
          }

          setState(() {
            _selectedType = type;
          });

          _loadReportData();
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: screenHeight * 0.013,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFF013328)
                  : Colors.white.withOpacity(0.62),
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.032,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodNavigator({
    required double screenWidth,
    required double screenHeight,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.018,
        vertical: screenHeight * 0.008,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          _buildNavigatorButton(
            screenWidth: screenWidth,
            icon: Icons.chevron_left_rounded,
            enabled: true,
            onTap: () {
              if (_selectedType == ChartReportType.monthly) {
                _changeMonth(-1);
              } else {
                _changeYear(-1);
              }
            },
          ),
          Expanded(
            child: Text(
              _getSelectedPeriodText(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.034,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildNavigatorButton(
            screenWidth: screenWidth,
            icon: Icons.chevron_right_rounded,
            enabled: _canMoveForward(),
            onTap: () {
              if (_selectedType == ChartReportType.monthly) {
                _changeMonth(1);
              } else {
                _changeYear(1);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBookDisplaySelector({
    required double screenWidth,
    required double screenHeight,
  }) {
    return Container(
      padding: EdgeInsets.all(
        screenWidth * 0.012,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildBookDisplayButton(
              screenWidth: screenWidth,
              screenHeight: screenHeight,
              type: ChartBookDisplayType.cover,
              label: '표지',
            ),
          ),
          SizedBox(
            width: screenWidth * 0.012,
          ),
          Expanded(
            child: _buildBookDisplayButton(
              screenWidth: screenWidth,
              screenHeight: screenHeight,
              type: ChartBookDisplayType.spine,
              label: '책등',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookDisplayButton({
    required double screenWidth,
    required double screenHeight,
    required ChartBookDisplayType type,
    required String label,
  }) {
    final isSelected =
        _selectedBookDisplayType == type;

    return Material(
      color: isSelected
          ? Colors.white
          : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () async {
          if (_selectedBookDisplayType == type) {
            return;
          }

          setState(() {
            _selectedBookDisplayType = type;
          });

          if (type == ChartBookDisplayType.spine) {
            await _loadSpineData();
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: screenHeight * 0.011,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFF013328)
                  : Colors.white.withOpacity(0.62),
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.03,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigatorButton({
    required double screenWidth,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: EdgeInsets.all(
            screenWidth * 0.012,
          ),
          child: Icon(
            icon,
            color: enabled ? Colors.white : Colors.white.withOpacity(0.18),
            size: screenWidth * 0.06,
          ),
        ),
      ),
    );
  }

  Widget _buildReportPreview({
    required double screenWidth,
    required double screenHeight,
  }) {
    final style =
    ShareCardTheme.fromStyle(
      _selectedStyle,
    );

    return LayoutBuilder(
      builder: (
          context,
          constraints,
          ) {
        final cardWidth =
            constraints.maxWidth;

        final bool isSpineMode =
            _selectedBookDisplayType ==
                ChartBookDisplayType.spine;

        late final int rowCount;
        late final double singleRowHeight;

        if (isSpineMode) {
          final shelves = _buildDynamicShelves(
            books: _reportBooks,
            cardWidth: cardWidth,
          );

          rowCount = math.max(
            1,
            shelves.length,
          );

          final spineHeight =
              cardWidth * 0.65;

          final shelfThickness =
              cardWidth * 0.016;

          singleRowHeight =
              spineHeight +
                  shelfThickness +
                  cardWidth * 0.02;
        } else {
          const booksPerRow = 5;

          rowCount = math.max(
            1,
            (_reportBooks.length / booksPerRow).ceil(),
          );

          final coverWidth =
              cardWidth * 0.17;

          final coverHeight =
              coverWidth * 1.45;

          singleRowHeight =
              coverHeight +
                  cardWidth * 0.045;
        }

        final collectionHeight =
            (rowCount * singleRowHeight) +
                ((rowCount - 1) *
                    cardWidth * 0.025);

        final baseHeight =
            cardWidth * 0.86;

        final cardHeight =
            baseHeight +
                collectionHeight;

        return Container(
          width: cardWidth,
          height: cardHeight,
          color: style.backgroundColor,
          padding: EdgeInsets.fromLTRB(
            cardWidth * 0.085,
            cardWidth * 0.07,
            cardWidth * 0.085,
            cardWidth * 0.065,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              _buildReportHeader(
                cardWidth: cardWidth,
                style: style,
              ),

              SizedBox(
                height:
                cardWidth * 0.055,
              ),

              _buildPeriodHero(
                cardWidth: cardWidth,
                style: style,
              ),

              SizedBox(
                height:
                cardWidth * 0.05,
              ),

              _buildReportMetrics(
                cardWidth: cardWidth,
                style: style,
              ),

              SizedBox(
                height:
                cardWidth * 0.1,
              ),

              Expanded(
                child:
                _selectedBookDisplayType ==
                    ChartBookDisplayType.cover
                    ? _buildBookCollection(
                  cardWidth: cardWidth,
                  style: style,
                )
                    : _buildSpineCollection(
                  cardWidth: cardWidth,
                  style: style,
                ),
              ),

              SizedBox(
                height:
                cardWidth * 0.045,
              ),

              _buildReportFooter(
                cardWidth: cardWidth,
                style: style,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportHeader({
    required double cardWidth,
    required ShareCardTheme style,
  }) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              _selectedType ==
                  ChartReportType.monthly
                  ? 'MONTHLY READING'
                  : 'YEARLY READING',
              style: TextStyle(
                color:
                style.accentColor,
                fontFamily: 'kopub',
                fontSize:
                cardWidth * 0.025,
                fontWeight:
                FontWeight.bold,
                letterSpacing: 2,
              ),
            ),

            SizedBox(
              height:
              cardWidth * 0.018,
            ),

            Container(
              width:
              cardWidth * 0.085,
              height: 2,
              color:
              style.accentColor,
            ),
          ],
        ),

        const Spacer(),

        Text(
          _selectedType ==
              ChartReportType.monthly
              ? '${_selectedMonth.year}'
              : 'YEAR',
          style: TextStyle(
            color:
            style.secondaryTextColor,
            fontFamily: 'kopub',
            fontSize:
            cardWidth * 0.022,
            fontWeight:
            FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodHero({
    required double cardWidth,
    required ShareCardTheme style,
  }) {
    if (_selectedType ==
        ChartReportType.monthly) {
      final month =
      _selectedMonth.month
          .toString()
          .padLeft(
        2,
        '0',
      );

      return Row(
        crossAxisAlignment:
        CrossAxisAlignment.end,
        children: [
          Text(
            month,
            style: TextStyle(
              color:
              style.primaryTextColor,
              fontFamily: 'kopub',
              fontSize:
              cardWidth * 0.15,
              fontWeight:
              FontWeight.bold,
              height: 0.9,
              letterSpacing: -4,
            ),
          ),

          SizedBox(
            width:
            cardWidth * 0.025,
          ),

          Padding(
            padding:
            EdgeInsets.only(
              bottom:
              cardWidth * 0.012,
            ),
            child: Text(
              _monthEnglishName(
                _selectedMonth.month,
              ),
              style: TextStyle(
                color: style
                    .secondaryTextColor,
                fontFamily: 'kopub',
                fontSize:
                cardWidth * 0.027,
                fontWeight:
                FontWeight.bold,
                letterSpacing: 1.8,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          '$_selectedYear',
          style: TextStyle(
            color:
            style.primaryTextColor,
            fontFamily: 'kopub',
            fontSize:
            cardWidth * 0.13,
            fontWeight:
            FontWeight.bold,
            height: 0.95,
            letterSpacing: -3,
          ),
        ),

        SizedBox(
          height:
          cardWidth * 0.012,
        ),

        Text(
          'YEAR IN BOOKS',
          style: TextStyle(
            color:
            style.secondaryTextColor,
            fontFamily: 'kopub',
            fontSize:
            cardWidth * 0.024,
            fontWeight:
            FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  String _monthEnglishName(
      int month,
      ) {
    const months = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];

    return months[month - 1];
  }

  Widget _buildReportMetrics({
    required double cardWidth,
    required ShareCardTheme style,
  }) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildReportMetric(
            value:
            '$_completedBookCount',
            label: 'BOOKS',
            cardWidth:
            cardWidth,
            style: style,
          ),
        ),

        Container(
          width: 1,
          height:
          cardWidth * 0.085,
          margin:
          EdgeInsets.symmetric(
            horizontal:
            cardWidth * 0.035,
          ),
          color:
          style.dividerColor,
        ),

        Expanded(
          child: _buildReportMetric(
            value:
            _formatReadingTimeShort(
              _totalReadingMinutes,
            ),
            label: 'READING',
            cardWidth:
            cardWidth,
            style: style,
          ),
        ),
      ],
    );
  }

  Widget _buildReportMetric({
    required String value,
    required String label,
    required double cardWidth,
    required ShareCardTheme style,
  }) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow:
          TextOverflow.ellipsis,
          style: TextStyle(
            color:
            style.primaryTextColor,
            fontFamily: 'kopub',
            fontSize:
            cardWidth * 0.046,
            fontWeight:
            FontWeight.bold,
            height: 1.05,
            letterSpacing: -0.8,
          ),
        ),

        SizedBox(
          height:
          cardWidth * 0.01,
        ),

        Text(
          label,
          style: TextStyle(
            color:
            style.secondaryTextColor,
            fontFamily: 'kopub',
            fontSize:
            cardWidth * 0.018,
            fontWeight:
            FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  String _formatReadingTimeShort(
      int totalMinutes,
      ) {
    if (totalMinutes <= 0) {
      return '0M';
    }

    if (totalMinutes < 60) {
      return '${totalMinutes}M';
    }

    final hours =
        totalMinutes ~/ 60;

    final minutes =
        totalMinutes % 60;

    if (minutes == 0) {
      return '${hours}H';
    }

    return '${hours}H ${minutes}M';
  }

  Widget _buildBookCollection({
    required double cardWidth,
    required ShareCardTheme style,
  }) {
    if (_isLoading) {
      return Center(
        child:
        CircularProgressIndicator(
          strokeWidth: 2,
          color: style.accentColor,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: TextStyle(
            color:
            style.secondaryTextColor,
            fontFamily: 'kopub',
            fontSize:
            cardWidth * 0.028,
          ),
        ),
      );
    }

    if (_reportBooks.isEmpty) {
      return Center(
        child: Text(
          'NO BOOKS YET',
          style: TextStyle(
            color:
            style.secondaryTextColor,
            fontFamily: 'kopub',
            fontSize:
            cardWidth * 0.02,
            fontWeight:
            FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      );
    }

    const booksPerRow = 5;

    final rows =
    <List<_ReportBookData>>[];

    for (
    int i = 0;
    i < _reportBooks.length;
    i += booksPerRow
    ) {
      rows.add(
        _reportBooks.sublist(
          i,
          math.min(
            i + booksPerRow,
            _reportBooks.length,
          ),
        ),
      );
    }

    return Column(
      mainAxisAlignment:
      MainAxisAlignment.start,
      children: List.generate(
        rows.length,
            (index) {
          return Padding(
            padding: EdgeInsets.only(
              bottom:
              index ==
                  rows.length - 1
                  ? 0
                  : cardWidth * 0.025,
            ),
            child: _buildBookRow(
              books: rows[index],
              cardWidth: cardWidth,
              style: style,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpineCollection({
    required double cardWidth,
    required ShareCardTheme style,
  }) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: style.accentColor,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: TextStyle(
            color: style.secondaryTextColor,
            fontFamily: 'kopub',
            fontSize: cardWidth * 0.028,
          ),
        ),
      );
    }

    if (_reportBooks.isEmpty) {
      return Center(
        child: Text(
          'NO BOOKS YET',
          style: TextStyle(
            color: style.secondaryTextColor,
            fontFamily: 'kopub',
            fontSize: cardWidth * 0.02,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      );
    }

    final shelves = _buildDynamicShelves(
      books: _reportBooks,
      cardWidth: cardWidth,
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: List.generate(
        shelves.length,
            (index) {
          return Padding(
            padding: EdgeInsets.only(
              bottom:
              index == shelves.length - 1
                  ? 0
                  : cardWidth * 0.025,
            ),
            child: _buildSpineShelf(
              items: shelves[index],
              cardWidth: cardWidth,
              style: style,
            ),
          );
        },
      ),
    );
  }

  List<List<_SpineLayoutItem>> _buildDynamicShelves({
    required List<_ReportBookData> books,
    required double cardWidth,
  }) {
    // 카드 좌우 padding을 뺀 실제 책장 폭
    final availableWidth =
        cardWidth * 0.83;

    // 이미지처럼 아주 작은 책 사이 간격
    final gap =
        cardWidth * 0.006;

    // 책등 기본 폭
    final baseWidth =
        cardWidth * 0.075;

    final shelves =
    <List<_SpineLayoutItem>>[];

    var currentShelf =
    <_SpineLayoutItem>[];

    double usedWidth = 0;

    for (final book in books) {
      /*
     * 책마다 두께는 약간만 다르게.
     *
     * 약 0.88 ~ 1.12배
     */
      final widthFactor =
          0.88 +
              ((book.title.hashCode.abs() % 25) / 100);

      final bookWidth =
          baseWidth * widthFactor;

      final requiredWidth =
      currentShelf.isEmpty
          ? bookWidth
          : gap + bookWidth;

      /*
     * 이 책을 더 넣으면 선반을 넘을 때만
     * 다음 선반으로 이동.
     */
      if (currentShelf.isNotEmpty &&
          usedWidth + requiredWidth >
              availableWidth) {
        shelves.add(currentShelf);

        currentShelf =
        <_SpineLayoutItem>[];

        usedWidth = 0;
      }

      if (currentShelf.isNotEmpty) {
        usedWidth += gap;
      }

      currentShelf.add(
        _SpineLayoutItem(
          book: book,
          width: bookWidth,
        ),
      );

      usedWidth += bookWidth;
    }

    if (currentShelf.isNotEmpty) {
      shelves.add(currentShelf);
    }

    return shelves;
  }

  Widget _buildSpineShelf({
    required List<_SpineLayoutItem> items,
    required double cardWidth,
    required ShareCardTheme style,
  }) {
    final shelfWidth =
        cardWidth * 0.83;

    final bookHeight =
        cardWidth * 0.65;

    final baseGap =
        cardWidth * 0.006;

    final maxGap =
        cardWidth * 0.018;

    final shelfThickness =
        cardWidth * 0.016;

    // 책 자체의 전체 폭
    final totalBookWidth =
    items.fold<double>(
      0,
          (sum, item) =>
      sum + item.width,
    );

    // 책을 제외한 남은 공간
    final remainingWidth =
    math.max(
      0,
      shelfWidth - totalBookWidth,
    );

    // 남은 공간을 책 사이에 분배
    double gap = baseGap;

    if (items.length > 1) {
      final distributedGap =
          remainingWidth /
              (items.length - 1);

      gap = math.min(
        maxGap,
        math.max(
          baseGap,
          distributedGap,
        ),
      );
    }

    double currentX = 0;

    final positionedBooks =
    <Widget>[];

    for (final item in items) {
      final x = currentX;

      positionedBooks.add(
        Positioned(
          left: x,
          bottom: shelfThickness,
          child: BookSpineWidget(
            title: item.book.title,
            author: item.book.author,
            spineUrl: item.book.spineUrl,
            coverUrl: item.book.imageUrl,
            width: item.width,
            height: bookHeight,
          ),
        ),
      );

      currentX +=
          item.width + gap;
    }

    return SizedBox(
      width: shelfWidth,
      height:
      bookHeight +
          shelfThickness +
          cardWidth * 0.02,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ...positionedBooks,

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: shelfThickness,
              decoration: BoxDecoration(
                color: style.primaryTextColor
                    .withOpacity(0.12),
                boxShadow: [
                  BoxShadow(
                    color: style.shadowColor,
                    blurRadius: 5,
                    offset:
                    const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookRow({
    required List<_ReportBookData> books,
    required double cardWidth,
    required ShareCardTheme style,
  }) {
    // 더 큰 표지
    final coverWidth =
        cardWidth * 0.17;

    final coverHeight =
        coverWidth * 1.45;

    final bookCount =
        books.length;

    /*
   * 실제 이 위젯이 사용할 수 있는 가로폭.
   *
   * 바깥 카드가 좌우 8.5% padding을 쓰므로
   * 내부 가용폭은 약 83%.
   *
   * 아주 약간의 안전 여백을 더 둔다.
   */
    final availableWidth =
        cardWidth * 0.81;

    if (bookCount == 0) {
      return const SizedBox.shrink();
    }

    /*
   * 한 권이면 그대로.
   * 여러 권이면 availableWidth 안에
   * 반드시 들어오도록 간격을 계산한다.
   */
    final itemStep =
    bookCount == 1
        ? 0.0
        : math.min(
      coverWidth,
      (availableWidth -
          coverWidth) /
          (bookCount - 1),
    );

    final totalWidth =
    bookCount == 1
        ? coverWidth
        : coverWidth +
        itemStep *
            (bookCount - 1);

    return SizedBox(
      width: double.infinity,
      height:
      coverHeight +
          cardWidth * 0.045,
      child: Center(
        child: SizedBox(
          width: totalWidth,
          height:
          coverHeight +
              cardWidth * 0.045,
          child: Stack(
            clipBehavior: Clip.none,
            children: List.generate(
              bookCount,
                  (index) {
                final center =
                    (bookCount - 1) / 2;

                final distance =
                    index - center;

                final rotation =
                    distance * 0.025;

                final verticalOffset =
                    distance.abs() *
                        cardWidth *
                        0.006;

                return Positioned(
                  left:
                  index *
                      itemStep,
                  top:
                  verticalOffset,
                  child: Transform.rotate(
                    angle: rotation,
                    child:
                    _buildReportCover(
                      book:
                      books[index],
                      coverWidth:
                      coverWidth,
                      coverHeight:
                      coverHeight,
                      style:
                      style,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportCover({
    required _ReportBookData book,
    required double coverWidth,
    required double coverHeight,
    required ShareCardTheme style,
  }) {
    final highResImageUrl =
    (book.imageUrl ?? '')
        .replaceAll(
      'coversum',
      'cover',
    );

    return Container(
      width: coverWidth,
      height: coverHeight,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: style.shadowColor,
            blurRadius: 12,
            offset: const Offset(
              0,
              6,
            ),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius:
        BorderRadius.circular(3),
        child:
        highResImageUrl
            .startsWith('http')
            ? Image.network(
          highResImageUrl,
          fit: BoxFit.cover,
          errorBuilder:
              (_, __, ___) {
            return _buildReportFallbackCover(
              style,
            );
          },
        )
            : _buildReportFallbackCover(
          style,
        ),
      ),
    );
  }

  Widget _buildReportFallbackCover(
      ShareCardTheme style,
      ) {
    return Container(
      color:
      style.fallbackCoverColor,
      alignment:
      Alignment.center,
      child: Icon(
        Icons.menu_book_rounded,
        color:
        style.secondaryTextColor,
        size: 26,
      ),
    );
  }

  Widget _buildReportFooter({
    required double cardWidth,
    required ShareCardTheme style,
  }) {
    return Container(
      padding: EdgeInsets.only(
        top:
        cardWidth * 0.03,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color:
            style.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.end,
        children: [
          Text(
            'LABRARY',
            style: TextStyle(
              color:
              style.primaryTextColor,
              fontFamily: 'kopub',
              fontSize:
              cardWidth * 0.026,
              fontWeight:
              FontWeight.bold,
              letterSpacing: 1.7,
            ),
          ),

          const Spacer(),

          Text(
            'Read. Challenge. Grow.',
            style: TextStyle(
              color: style
                  .secondaryTextColor,
              fontFamily: 'kopub',
              fontSize:
              cardWidth * 0.019,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleSection(
      double screenWidth,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          '카드 색상',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'kopub',
            fontWeight: FontWeight.bold,
            fontSize: screenWidth * 0.04,
          ),
        ),

        SizedBox(
          height: screenWidth * 0.03,
        ),

        SizedBox(
          height: screenWidth * 0.4,
          child: RawScrollbar(
            controller:
            _styleScrollController,
            thumbColor:
            Colors.white.withOpacity(0.95),
            trackBorderColor:
            Colors.white.withOpacity(0.12),
            thumbVisibility: true,
            scrollbarOrientation:
            ScrollbarOrientation.bottom,
            thickness: 5,
            radius:
            const Radius.circular(20),
            minThumbLength: 45,
            child: ListView.separated(
              controller:
              _styleScrollController,
              physics:
              const BouncingScrollPhysics(),
              scrollDirection:
              Axis.horizontal,
              padding: EdgeInsets.only(
                bottom:
                screenWidth * 0.06,
                right:
                screenWidth * 0.08,
              ),
              itemCount:
              shareCardStyles.length,
              separatorBuilder: (_, __) {
                return SizedBox(
                  width:
                  screenWidth * 0.025,
                );
              },
              itemBuilder:
                  (context, index) {
                final item =
                shareCardStyles[index];

                return SizedBox(
                  width:
                  screenWidth * 0.2,
                  child:
                  ShareCardStyleOption(
                    label: item.label,
                    backgroundColor:
                    item.backgroundColor,
                    accentColor:
                    item.accentColor,
                    isSelected:
                    _selectedStyle ==
                        item.style,
                    onTap: () {
                      setState(() {
                        _selectedStyle =
                            item.style;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _changeMonth(int offset) {
    final nextMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + offset,
      1,
    );

    final now = DateTime.now();
    final currentMonth = DateTime(
      now.year,
      now.month,
      1,
    );

    if (nextMonth.isAfter(currentMonth)) {
      return;
    }

    setState(() {
      _selectedMonth = nextMonth;
    });

    _loadReportData();
  }

  void _changeYear(int offset) {
    final nextYear = _selectedYear + offset;

    if (nextYear > DateTime.now().year) {
      return;
    }

    setState(() {
      _selectedYear = nextYear;
    });

    _loadReportData();
  }

  bool _canMoveForward() {
    final now = DateTime.now();

    if (_selectedType == ChartReportType.monthly) {
      final currentMonth = DateTime(
        now.year,
        now.month,
        1,
      );

      final nextMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        1,
      );

      return !nextMonth.isAfter(
        currentMonth,
      );
    }

    return _selectedYear < now.year;
  }

  DateTimeRange _getSelectedRange() {
    switch (_selectedType) {
      case ChartReportType.monthly:
        final start = DateTime(
          _selectedMonth.year,
          _selectedMonth.month,
          1,
        );

        final end = DateTime(
          _selectedMonth.year,
          _selectedMonth.month + 1,
          1,
        );

        return DateTimeRange(
          start: start,
          end: end,
        );

      case ChartReportType.yearly:
        return DateTimeRange(
          start: DateTime(
            _selectedYear,
            1,
            1,
          ),
          end: DateTime(
            _selectedYear + 1,
            1,
            1,
          ),
        );
    }
  }

  String _getSelectedPeriodText() {
    if (_selectedType == ChartReportType.monthly) {
      return '${_selectedMonth.year}년 '
          '${_selectedMonth.month}월';
    }

    return '$_selectedYear년';
  }

  String _formatMinutes(int totalMinutes) {
    if (totalMinutes <= 0) {
      return '0분';
    }

    if (totalMinutes < 60) {
      return '$totalMinutes분';
    }

    final hours = totalMinutes ~/ 60;

    final minutes = totalMinutes % 60;

    if (minutes == 0) {
      return '$hours시간';
    }

    return '$hours시간 $minutes분';
  }

  Future<void> _loadReportData() async {
    final requestId = ++_loadRequestId;
    final range = _getSelectedRange();

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final savedBooksProvider = context.read<SavedBooksProvider>();

      final dailyMinutes = await ReadingLogService.getReadingMinutesByRange(
        start: range.start,
        end: range.end,
      );

      final totalMinutes = dailyMinutes.values.fold<int>(
        0,
        (sum, minutes) => sum + minutes,
      );

      final completedBooks = savedBooksProvider.savedBooks
          .where((book) {
        // 현재 완독 상태인 책만
        if (book.category != 'done') {
          return false;
        }

        final endDate = book.endDate;

        if (endDate == null) {
          return false;
        }

        return !endDate.isBefore(
          range.start,
        ) &&
            endDate.isBefore(
              range.end,
            );
      })
          .map(
            (book) => _ReportBookData(
          id: book.id,
          title: book.title.trim().isEmpty
              ? '제목 없는 책'
              : book.title.trim(),
          author: book.author.trim(),
          isbn: book.isbn,
          imageUrl: book.imageUrl,
          yes24ItemId: book.yes24ItemId,
          spineUrl: book.spineUrl,
              spineChecked: book.spineChecked,
          completedAt: book.endDate!,
        ),
          )
          .toList();

      completedBooks.sort(
            (a, b) => b.completedAt.compareTo(
          a.completedAt,
        ),
      );


      if (!mounted || requestId != _loadRequestId) {
        return;
      }

      setState(() {
        _reportBooks
          ..clear()
          ..addAll(completedBooks);

        _completedBookCount = completedBooks.length;
        _totalReadingMinutes = totalMinutes;
      });

      if (_selectedBookDisplayType ==
          ChartBookDisplayType.spine) {
        await _loadSpineData();
      }
    } catch (e) {
      debugPrint(
        '[ChartReportScreen] '
        '리포트 로드 실패: $e',
      );

      if (!mounted || requestId != _loadRequestId) {
        return;
      }

      setState(() {
        _reportBooks.clear();
        _completedBookCount = 0;
        _totalReadingMinutes = 0;
        _errorMessage = '리포트를 불러오지 못했어요.';
      });
    } finally {
      if (!mounted || requestId != _loadRequestId) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Uint8List> _captureReportCard() async {
    // 현재 프레임의 레이아웃/페인팅이 완전히 끝날 때까지 대기
    await WidgetsBinding.instance.endOfFrame;

    final cardContext =
        _reportCardKey.currentContext;

    if (cardContext == null) {
      throw Exception(
        '독서 리포트를 찾을 수 없습니다.',
      );
    }

    final renderObject =
    cardContext.findRenderObject();

    if (renderObject
    is! RenderRepaintBoundary) {
      throw Exception(
        '독서 리포트를 이미지로 변환할 수 없습니다.',
      );
    }

    final boundary = renderObject;

    /*
   * 일반적인 리포트:
   *   pixelRatio 3.0 → 고화질 저장
   *
   * 책이 아주 많아서 카드가 길어지는 경우:
   *   최종 이미지의 한 변이 8000px을 넘지 않도록
   *   pixelRatio를 자동으로 낮춘다.
   *
   * 이렇게 해야 긴 연간 리포트도
   * 하단 책들이 잘리지 않고 모두 저장된다.
   */
    const preferredPixelRatio = 3.0;
    const maxOutputDimension = 8000.0;

    final logicalWidth =
        boundary.size.width;

    final logicalHeight =
        boundary.size.height;

    if (logicalWidth <= 0 ||
        logicalHeight <= 0) {
      throw Exception(
        '독서 리포트의 크기를 확인할 수 없습니다.',
      );
    }

    final widthRatio =
        maxOutputDimension /
            logicalWidth;

    final heightRatio =
        maxOutputDimension /
            logicalHeight;

    final pixelRatio = math.min(
      preferredPixelRatio,
      math.min(
        widthRatio,
        heightRatio,
      ),
    );

    // 비정상적으로 작은 값 방지
    final safePixelRatio =
    math.max(
      pixelRatio,
      0.1,
    );

    debugPrint(
      '[REPORT CAPTURE] '
          'logicalSize=${boundary.size}, '
          'pixelRatio=$safePixelRatio, '
          'output=${(logicalWidth * safePixelRatio).round()}'
          'x'
          '${(logicalHeight * safePixelRatio).round()}',
    );

    final ui.Image image =
    await boundary.toImage(
      pixelRatio:
      safePixelRatio,
    );

    final byteData =
    await image.toByteData(
      format:
      ui.ImageByteFormat.png,
    );

    image.dispose();

    if (byteData == null) {
      throw Exception(
        '이미지 데이터를 생성하지 못했습니다.',
      );
    }

    return byteData.buffer
        .asUint8List();
  }

  Future<void> _saveReport() async {
    if (_isProcessing ||
        _isLoading) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      bool hasAccess =
      await Gal.hasAccess();

      if (!hasAccess) {
        hasAccess =
        await Gal.requestAccess();
      }

      if (!hasAccess) {
        throw Exception(
          '사진 앨범 접근 권한이 필요합니다.',
        );
      }

      final imageBytes =
      await _captureReportCard();

      final timestamp =
          DateTime.now()
              .millisecondsSinceEpoch;

      final periodName =
      _getReportFilePeriodName();

      await Gal.putImageBytes(
        imageBytes,
        name:
        'labrary_report_${periodName}_$timestamp',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              '독서 리포트를 사진 앨범에 저장했어요.',
              style: TextStyle(
                fontFamily: 'kopub',
              ),
            ),
          ),
        );
    } on GalException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _galErrorMessage(e),
              style: const TextStyle(
                fontFamily: 'kopub',
              ),
            ),
            backgroundColor:
            Colors.redAccent,
          ),
        );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              e
                  .toString()
                  .replaceFirst(
                'Exception: ',
                '',
              ),
              style: const TextStyle(
                fontFamily: 'kopub',
              ),
            ),
            backgroundColor:
            Colors.redAccent,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _shareReport(
      BuildContext shareContext,
      ) async {
    if (_isProcessing ||
        _isLoading) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final imageBytes =
      await _captureReportCard();

      final periodName =
      _getReportFilePeriodName();

      final file = XFile.fromData(
        imageBytes,
        mimeType: 'image/png',
        name:
        'labrary_report_$periodName.png',
      );

      final renderBox =
      shareContext.findRenderObject()
      as RenderBox?;

      final shareOrigin =
      renderBox != null
          ? renderBox.localToGlobal(
        Offset.zero,
      ) &
      renderBox.size
          : const Rect.fromLTWH(
        0,
        0,
        1,
        1,
      );

      await Share.shareXFiles(
        [file],
        fileNameOverrides: [
          'labrary_report_$periodName.png',
        ],
        sharePositionOrigin:
        shareOrigin,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '공유 준비 중 오류가 발생했습니다.\n$e',
              style: const TextStyle(
                fontFamily: 'kopub',
              ),
            ),
            backgroundColor:
            Colors.redAccent,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  String _getReportFilePeriodName() {
    if (_selectedType ==
        ChartReportType.monthly) {
      final month =
      _selectedMonth.month
          .toString()
          .padLeft(2, '0');

      return '${_selectedMonth.year}_$month';
    }

    return '$_selectedYear';
  }

  String _galErrorMessage(
      GalException exception,
      ) {
    switch (exception.type) {
      case GalExceptionType.accessDenied:
        return '사진 앨범 접근 권한이 거부되었습니다.';

      case GalExceptionType.notEnoughSpace:
        return '기기의 저장 공간이 부족합니다.';

      case GalExceptionType.notSupportedFormat:
        return '지원하지 않는 이미지 형식입니다.';

      case GalExceptionType.unexpected:
        return '이미지를 저장하는 중 오류가 발생했습니다.';
    }
  }

  Future<void> _loadSpineData() async {
    if (_isLoadingSpines) {
      return;
    }

    setState(() {
      _isLoadingSpines = true;
    });

    try {
      final updatedBooks =
      List<_ReportBookData>.from(_reportBooks);

      // 한 번에 너무 많이 호출하지 않도록 3권씩 처리
      const batchSize = 5;

      for (int i = 0; i < updatedBooks.length; i += batchSize) {
        final end =
        math.min(i + batchSize, updatedBooks.length);

        final batch = updatedBooks.sublist(i, end);

        final results = await Future.wait(
          batch.map((book) async {
            debugPrint(
              '[SPINE CHECK] '
                  'title=${book.title} / '
                  'isbn=${book.isbn} / '
                  'spineUrl=${book.spineUrl}',
            );
            if (book.spineChecked) {
              debugPrint(
                '[SPINE CACHE HIT] '
                    '${book.title} / '
                    'spineUrl=${book.spineUrl}',
              );

              return book;
            }

            if (book.isbn == null ||
                book.isbn!.trim().isEmpty) {
              debugPrint(
                '[SPINE SKIP] ISBN 없음: ${book.title}',
              );

              return book;
            }

            try {
              final result =
              await Yes24BookService.findByIsbn(
                book.isbn!,
              );

              debugPrint(
                '[YES24 RESULT] '
                    'title=${book.title} / '
                    'isbn=${book.isbn} / '
                    'found=${result.found} / '
                    'itemId=${result.itemId} / '
                    'spineUrl=${result.spineUrl}',
              );

              final savedBooksProvider =
              context.read<SavedBooksProvider>();

              if (!result.found) {
                await savedBooksProvider.updateBookSpineCache(
                  bookId: book.id,
                  yes24ItemId: null,
                  spineUrl: null,
                );

                return book.copyWith(
                  spineChecked: true,
                );
              }

              await savedBooksProvider.updateBookSpineCache(
                bookId: book.id,
                yes24ItemId: result.itemId,
                spineUrl: result.spineUrl,
              );

              return book.copyWith(
                yes24ItemId: result.itemId,
                spineUrl: result.spineUrl,
                spineChecked: true,
              );
            } catch (e) {
              debugPrint(
                '[YES24] 책등 조회 실패: ${book.title} / $e',
              );

              return book;
            }
          }),
        );

        for (int j = 0; j < results.length; j++) {
          updatedBooks[i + j] = results[j];
        }

        if (!mounted) {
          return;
        }

        // 받아오는 족족 화면 반영
        setState(() {
          _reportBooks
            ..clear()
            ..addAll(updatedBooks);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSpines = false;
        });
      }
    }
  }

}

class _ReportBookData {
  final String id;
  final String title;
  final String author;
  final String? isbn;
  final String? imageUrl;

  final String? yes24ItemId;
  final String? spineUrl;
  final bool spineChecked;

  final DateTime completedAt;

  const _ReportBookData({
    required this.id,
    required this.title,
    required this.author,
    required this.isbn,
    required this.imageUrl,
    required this.yes24ItemId,
    required this.spineUrl,
    required this.spineChecked,
    required this.completedAt,
  });

  _ReportBookData copyWith({
    String? yes24ItemId,
    String? spineUrl,
    bool? spineChecked,
  }) {
    return _ReportBookData(
      id: id,
      title: title,
      author: author,
      isbn: isbn,
      imageUrl: imageUrl,
      yes24ItemId:
      yes24ItemId ?? this.yes24ItemId,
      spineUrl:
      spineUrl ?? this.spineUrl,
      spineChecked:
      spineChecked ?? this.spineChecked,
      completedAt: completedAt,
    );
  }
}

class _SpineLayoutItem {
  final _ReportBookData book;
  final double width;

  const _SpineLayoutItem({
    required this.book,
    required this.width,
  });
}
