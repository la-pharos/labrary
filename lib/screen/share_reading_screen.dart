import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/service/reading_log_service.dart';
import 'package:dayverse_book/widget/share_card_action_bar.dart';
import 'package:dayverse_book/widget/share_card_style.dart';

class ShareReadingScreen extends StatefulWidget {
  final BookModel book;

  const ShareReadingScreen({
    super.key,
    required this.book,
  });

  @override
  State<ShareReadingScreen> createState() => _ShareReadingScreenState();
}

class _ShareReadingScreenState
    extends State<ShareReadingScreen> {
  late Future<int>
  _totalReadingMinutesFuture;

  final ScrollController
  _styleScrollController =
  ScrollController();

  final GlobalKey _shareCardKey =
  GlobalKey();

  ShareCardStyle _selectedStyle =
      ShareCardStyle.paper;

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    _totalReadingMinutesFuture = _loadTotalReadingMinutes(widget.book.id);
  }

  @override
  void dispose() {
    _styleScrollController.dispose();
    super.dispose();
  }

  Future<void> _saveImage() async {
    if (_isProcessing) return;

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
      await _captureCard();

      final timestamp =
          DateTime.now()
              .millisecondsSinceEpoch;

      await Gal.putImageBytes(
        imageBytes,
        name:
        'labrary_reading_$timestamp',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              '독서 상태 카드를 사진 앨범에 저장했어요.',
            ),
          ),
        );
    } on GalException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _galErrorMessage(e),
            ),
            backgroundColor:
            Colors.redAccent,
          ),
        );
    } catch (e) {
      if (!mounted) return;

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

  Future<void> _shareImage(
      BuildContext shareContext,
      ) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final imageBytes =
      await _captureCard();

      final file = XFile.fromData(
        imageBytes,
        mimeType: 'image/png',
        name:
        'labrary_reading.png',
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
        fileNameOverrides: const [
          'labrary_reading.png',
        ],
        sharePositionOrigin:
        shareOrigin,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '공유 준비 중 오류가 발생했습니다.\n$e',
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

  Future<Uint8List> _captureCard() async {
    await WidgetsBinding.instance.endOfFrame;

    final cardContext =
        _shareCardKey.currentContext;

    if (cardContext == null) {
      throw Exception(
        '공유카드를 찾을 수 없습니다.',
      );
    }

    final renderObject =
    cardContext.findRenderObject();

    if (renderObject
    is! RenderRepaintBoundary) {
      throw Exception(
        '공유카드를 이미지로 변환할 수 없습니다.',
      );
    }

    final ui.Image image =
    await renderObject.toImage(
      pixelRatio: 3.0,
    );

    final byteData =
    await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) {
      throw Exception(
        '이미지 데이터를 생성하지 못했습니다.',
      );
    }

    return byteData.buffer.asUint8List();
  }

  Future<int> _loadTotalReadingMinutes(
    String bookId,
  ) async {
    try {
      final logs = await ReadingLogService.getTimerLogsForBook(
        bookId,
      );

      int totalMinutes = 0;

      for (final log in logs) {
        final rawMinutes = log['durationMinutes'];

        if (rawMinutes is int) {
          totalMinutes += rawMinutes;
        } else if (rawMinutes is num) {
          totalMinutes += rawMinutes.toInt();
        } else {
          totalMinutes += int.tryParse(
                rawMinutes?.toString() ?? '',
              ) ??
              0;
        }
      }

      return totalMinutes;
    } catch (e) {
      debugPrint(
        '독서시간 불러오기 실패: $e',
      );

      return 0;
    }
  }

  Widget _buildStyleSection(
      double screenWidth,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            controller: _styleScrollController,
            thumbColor: Colors.white.withOpacity(0.95),
            trackBorderColor:
            Colors.white.withOpacity(0.12),
            thumbVisibility: true,
            scrollbarOrientation:
            ScrollbarOrientation.bottom,
            thickness: 5,
            radius: const Radius.circular(20),
            minThumbLength: 45,
            child: ListView.separated(
              controller: _styleScrollController,
              physics:
              const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(
                bottom: screenWidth * 0.06,
                right: screenWidth * 0.08,
              ),
              itemCount: shareCardStyles.length,
              separatorBuilder: (_, __) {
                return SizedBox(
                  width: screenWidth * 0.025,
                );
              },
              itemBuilder: (context, index) {
                final item =
                shareCardStyles[index];

                return SizedBox(
                  width: screenWidth * 0.2,
                  child: ShareCardStyleOption(
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

  Widget _buildPreviewSection(
      double screenWidth,
      int totalReadingMinutes,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          '미리보기',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'kopub',
            fontWeight: FontWeight.bold,
            fontSize: screenWidth * 0.04,
          ),
        ),

        SizedBox(
          height: screenWidth * 0.025,
        ),

        Container(
          width: double.infinity,
          padding: EdgeInsets.all(
            screenWidth * 0.025,
          ),
          decoration: BoxDecoration(
            color:
            Colors.black.withOpacity(0.14),
            borderRadius:
            BorderRadius.circular(18),
            border: Border.all(
              color:
              Colors.white.withOpacity(0.08),
            ),
          ),
          child: RepaintBoundary(
            key: _shareCardKey,
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: ColoredBox(
                color: ShareCardTheme.fromStyle(
                  _selectedStyle,
                ).backgroundColor,
                child: _ReadingShareCard(
                  book: widget.book,
                  totalReadingMinutes: totalReadingMinutes,
                  cardStyle: _selectedStyle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 20) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor:
        const Color(0xFF013328),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
          ),
          title: const Text(
            '독서 상태 공유',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: FutureBuilder<int>(
            future:
            _totalReadingMinutesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.amberAccent,
                  ),
                );
              }

              final totalMinutes =
                  snapshot.data ?? 0;

              return Column(
                children: [
                  Expanded(
                    child:
                    SingleChildScrollView(
                      physics:
                      const BouncingScrollPhysics(),
                      padding:
                      EdgeInsets.fromLTRB(
                        screenWidth * 0.05,
                        screenWidth * 0.03,
                        screenWidth * 0.05,
                        screenWidth * 0.05,
                      ),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          _buildPreviewSection(
                            screenWidth,
                            totalMinutes,
                          ),

                          SizedBox(
                            height:
                            screenWidth *
                                0.06,
                          ),

                          _buildStyleSection(
                            screenWidth,
                          ),
                        ],
                      ),
                    ),
                  ),

                  ShareCardActionBar(
                    isProcessing:
                    _isProcessing,
                    onSave: _saveImage,
                    onShare: _shareImage,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}


class _ReadingShareCard
    extends StatelessWidget {
  final BookModel book;
  final int totalReadingMinutes;
  final ShareCardStyle cardStyle;

  const _ReadingShareCard({
    required this.book,
    required this.totalReadingMinutes,
    required this.cardStyle,
  });

  @override
  Widget build(BuildContext context) {
    final style =
    ShareCardTheme.fromStyle(
      cardStyle,
    );

    final highResImageUrl =
    (book.imageUrl ?? '')
        .replaceAll(
      'coversum',
      'cover',
    );

    return ColoredBox(
      color: style.backgroundColor,
      child: LayoutBuilder(
        builder: (
            context,
            constraints,
            ) {
          final cardWidth =
              constraints.maxWidth;

          return Padding(
            padding:
            EdgeInsets.fromLTRB(
              cardWidth * 0.085,
              cardWidth * 0.07,
              cardWidth * 0.085,
              cardWidth * 0.065,
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                // =================================================
                // TOP HEADER
                // =================================================

                _buildTopHeader(
                  cardWidth: cardWidth,
                  style: style,
                ),

                SizedBox(
                  height: cardWidth * 0.04,
                ),

                Center(
                  child: _buildCover(
                    cardWidth: cardWidth,
                    style: style,
                    highResImageUrl: highResImageUrl,
                  ),
                ),

                SizedBox(
                  height: cardWidth * 0.035,
                ),

                _buildBookTitle(
                  cardWidth: cardWidth,
                  style: style,
                ),

                SizedBox(
                  height: cardWidth * 0.01,
                ),

                Expanded(
                  child: _buildRecordContent(
                    cardWidth: cardWidth,
                    style: style,
                  ),
                ),

                SizedBox(
                  height: cardWidth * 0.03,
                ),

                _buildFooter(
                  cardWidth: cardWidth,
                  style: style,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopHeader({
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
              _editorialLabel(),
              style: TextStyle(
                color:
                style.accentColor,
                fontFamily: 'kopub',
                fontSize:
                cardWidth * 0.025,
                fontWeight:
                FontWeight.bold,
                letterSpacing: 2.0,
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

        _buildTopMetric(
          cardWidth:
          cardWidth,
          style: style,
        ),
      ],
    );
  }

  Widget _buildTopMetric({
    required double cardWidth,
    required ShareCardTheme style,
  }) {
    switch (book.category) {
      case 'reading':
        return Text(
          '${book.progressPercent}%',
          style: TextStyle(
            color:
            style.primaryTextColor,
            fontFamily: 'kopub',
            fontSize:
            cardWidth * 0.047,
            fontWeight:
            FontWeight.bold,
            letterSpacing: -0.5,
          ),
        );

      case 'done':
        final rating =
            book.rating ?? 0.0;

        if (rating <= 0) {
          return Icon(
            Icons.check_rounded,
            color:
            style.accentColor,
            size:
            cardWidth * 0.055,
          );
        }

        return Row(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Icon(
              Icons.star_rounded,
              color:
              style.ratingColor,
              size:
              cardWidth * 0.042,
            ),

            SizedBox(
              width:
              cardWidth * 0.008,
            ),

            Text(
              rating.toStringAsFixed(
                1,
              ),
              style: TextStyle(
                color: style
                    .primaryTextColor,
                fontFamily: 'kopub',
                fontSize:
                cardWidth *
                    0.036,
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ],
        );

      case 'want':
      default:
        return Icon(
          Icons.bookmark_border_rounded,
          color:
          style.accentColor,
          size:
          cardWidth * 0.05,
        );
    }
  }

  Widget _buildCover({
    required double cardWidth,
    required ShareCardTheme style,
    required String highResImageUrl,
  }) {
    final coverWidth =
        cardWidth * 0.28;

    final coverHeight =
        coverWidth * 1.45;

    return Container(
      width: coverWidth,
      height: coverHeight,
      decoration:
      BoxDecoration(
        boxShadow: [
          BoxShadow(
            color:
            style.shadowColor,
            blurRadius: 18,
            offset:
            const Offset(
              0,
              9,
            ),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius:
        BorderRadius.circular(
          3,
        ),
        child:
        highResImageUrl
            .startsWith(
          'http',
        )
            ? Image.network(
          highResImageUrl,
          fit:
          BoxFit.cover,
          errorBuilder:
              (
              _,
              __,
              ___,
              ) {
            return _buildFallbackCover(
              style,
            );
          },
        )
            : _buildFallbackCover(
          style,
        ),
      ),
    );
  }

  Widget _buildBookTitle({
    required double cardWidth,
    required ShareCardTheme style,
  }) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          book.title,
          maxLines: 2,
          overflow:
          TextOverflow.ellipsis,
          style: TextStyle(
            color:
            style.primaryTextColor,
            fontFamily: 'kopub',
            fontSize:
            cardWidth * 0.047,
            fontWeight:
            FontWeight.bold,
            height: 1.3,
            letterSpacing: -0.3,
          ),
        ),

        if (book.author
            .trim()
            .isNotEmpty) ...[
          SizedBox(
            height:
            cardWidth * 0.012,
          ),

          Text(
            book.author,
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
            style: TextStyle(
              color: style
                  .secondaryTextColor,
              fontFamily: 'kopub',
              fontSize:
              cardWidth * 0.029,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecordContent({
    required double cardWidth,
    required ShareCardTheme style,
  }) {
    switch (book.category) {
      case 'reading':
        return _buildReadingContent(
          cardWidth:
          cardWidth,
          style: style,
        );

      case 'done':
        return _buildDoneContent(
          cardWidth:
          cardWidth,
          style: style,
        );

      case 'want':
      default:
        return _buildWantContent(
          cardWidth:
          cardWidth,
          style: style,
        );
    }
  }

  // =================================================
  // READING
  // =================================================

  Widget _buildReadingContent({
    required double cardWidth,
    required ShareCardTheme style,
  }) {
    final progress =
    book.progressRatio
        .clamp(0.0, 1.0)
        .toDouble();

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      mainAxisAlignment:
      MainAxisAlignment.center,
      children: [
        if (book.pageCount > 0) ...[
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.end,
            children: [
              Text(
                '${book.pageRead} / ${book.pageCount}',
                style: TextStyle(
                  color:
                  style.primaryTextColor,
                  fontFamily: 'kopub',
                  fontSize:
                  cardWidth * 0.058,
                  fontWeight:
                  FontWeight.bold,
                  height: 1,
                  letterSpacing: -1,
                ),
              ),

              SizedBox(
                width:
                cardWidth * 0.018,
              ),

              Padding(
                padding: EdgeInsets.only(
                  bottom:
                  cardWidth * 0.004,
                ),
                child: Text(
                  'PAGES',
                  style: TextStyle(
                    color: style
                        .secondaryTextColor,
                    fontFamily: 'kopub',
                    fontSize:
                    cardWidth * 0.019,
                    fontWeight:
                    FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(
            height:
            cardWidth * 0.022,
          ),

          ClipRRect(
            borderRadius:
            BorderRadius.circular(20),
            child:
            LinearProgressIndicator(
              value: progress,
              minHeight:
              cardWidth * 0.012,
              backgroundColor:
              style
                  .progressBackgroundColor,
              valueColor:
              AlwaysStoppedAnimation<
                  Color>(
                style.accentColor,
              ),
            ),
          ),

          SizedBox(
            height:
            cardWidth * 0.04,
          ),
        ],

        _buildMetricRow(
          cardWidth: cardWidth,
          style: style,
          leftValue:
          book.startDate != null
              ? _formatDateShort(
            book.startDate!,
          )
              : '—',
          leftLabel: 'START',
          rightValue:
          _formatReadingTime(
            totalReadingMinutes,
          ),
          rightLabel: 'READING',
        ),
      ],
    );
  }

  // =================================================
  // DONE
  // =================================================

  Widget _buildDoneContent({
    required double cardWidth,
    required ShareCardTheme style,
  }) {
    final hasPeriod =
        book.startDate != null &&
            book.endDate != null;

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      mainAxisAlignment:
      MainAxisAlignment.center,
      children: [
        _buildMetricRow(
          cardWidth: cardWidth,
          style: style,
          leftValue: hasPeriod
              ? _readingPeriodText()
              : '—',
          leftLabel: 'READING PERIOD',
          rightValue:
          _formatReadingTime(
            totalReadingMinutes,
          ),
          rightLabel: 'READING',
        ),

        if (hasPeriod) ...[
          SizedBox(
            height:
            cardWidth * 0.034,
          ),

          Container(
            width: double.infinity,
            height: 1,
            color:
            style.dividerColor,
          ),

          SizedBox(
            height:
            cardWidth * 0.024,
          ),

          Text(
            '${_formatDate(book.startDate!)}'
                '  —  '
                '${_formatDate(book.endDate!)}',
            style: TextStyle(
              color:
              style.secondaryTextColor,
              fontFamily: 'kopub',
              fontSize:
              cardWidth * 0.023,
              fontWeight:
              FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ],
    );
  }

  // =================================================
  // WANT
  // =================================================

  Widget _buildWantContent({
    required double cardWidth,
    required ShareCardTheme style,
  }) {
    final hasPublisher =
        book.publisher
            ?.trim()
            .isNotEmpty ==
            true;

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      mainAxisAlignment:
      MainAxisAlignment.center,
      children: [
        if (book.pageCount > 0 &&
            hasPublisher)
          _buildMetricRow(
            cardWidth: cardWidth,
            style: style,
            leftValue:
            '${book.pageCount}',
            leftLabel: 'PAGES',
            rightValue:
            book.publisher!.trim(),
            rightLabel: 'PUBLISHER',
            smallerRightValue: true,
          )
        else if (book.pageCount > 0)
          _buildMetric(
            value:
            '${book.pageCount}',
            label: 'PAGES',
            cardWidth:
            cardWidth,
            style: style,
          )
        else if (hasPublisher)
            _buildMetric(
              value:
              book.publisher!.trim(),
              label: 'PUBLISHER',
              cardWidth:
              cardWidth,
              style: style,
              smallerValue: true,
            ),
      ],
    );
  }

  Widget _buildMetricRow({
    required double cardWidth,
    required ShareCardTheme style,
    required String leftValue,
    required String leftLabel,
    required String rightValue,
    required String rightLabel,
    bool smallerRightValue = false,
  }) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildMetric(
            value: leftValue,
            label: leftLabel,
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
            cardWidth * 0.032,
          ),
          color:
          style.dividerColor,
        ),

        Expanded(
          child: _buildMetric(
            value: rightValue,
            label: rightLabel,
            cardWidth:
            cardWidth,
            style: style,
            smallerValue:
            smallerRightValue,
          ),
        ),
      ],
    );
  }

  Widget _buildMetric({
    required String value,
    required String label,
    required double cardWidth,
    required ShareCardTheme style,
    bool smallerValue = false,
  }) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines:
          smallerValue ? 2 : 1,
          overflow:
          TextOverflow.ellipsis,
          style: TextStyle(
            color:
            style.primaryTextColor,
            fontFamily: 'kopub',
            fontSize:
            cardWidth *
                (smallerValue
                    ? 0.03
                    : 0.04),
            fontWeight:
            FontWeight.bold,
            height: 1.15,
            letterSpacing:
            smallerValue
                ? -0.2
                : -0.4,
          ),
        ),

        SizedBox(
          height:
          cardWidth * 0.009,
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
            letterSpacing: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter({
    required double cardWidth,
    required ShareCardTheme style,
  }) {
    return Row(
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
    );
  }

  Widget _buildFallbackCover(
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
        size: 28,
      ),
    );
  }

  String _editorialLabel() {
    switch (book.category) {
      case 'reading':
        return 'READING NOW';

      case 'done':
        return 'FINISHED';

      case 'want':
      default:
        return 'READING LIST';
    }
  }

  String _readingPeriodText() {
    final start =
        book.startDate;

    final end =
        book.endDate;

    if (start == null ||
        end == null) {
      return '-';
    }

    final startDay =
    DateTime(
      start.year,
      start.month,
      start.day,
    );

    final endDay =
    DateTime(
      end.year,
      end.month,
      end.day,
    );

    final days =
        endDay
            .difference(
          startDay,
        )
            .inDays +
            1;

    return '$days DAYS';
  }

  String _formatDate(
      DateTime date,
      ) {
    final year =
    date.year
        .toString();

    final month =
    date.month
        .toString()
        .padLeft(
      2,
      '0',
    );

    final day =
    date.day
        .toString()
        .padLeft(
      2,
      '0',
    );

    return '$year.$month.$day';
  }

  String _formatDateShort(
      DateTime date,
      ) {
    final month =
    date.month
        .toString()
        .padLeft(
      2,
      '0',
    );

    final day =
    date.day
        .toString()
        .padLeft(
      2,
      '0',
    );

    return '$month.$day';
  }

  String _formatReadingTime(
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
}
