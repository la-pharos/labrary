import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/widget/share_card_action_bar.dart';
import 'package:dayverse_book/widget/share_card_style.dart';


class ShareNoteScreen extends StatefulWidget {
  final BookModel book;
  final String memoContent;
  final DateTime? savedAt;

  const ShareNoteScreen({
    super.key,
    required this.book,
    required this.memoContent,
    required this.savedAt,
  });

  @override
  State<ShareNoteScreen> createState() =>
      _ShareNoteScreenState();
}

class _ShareNoteScreenState
    extends State<ShareNoteScreen> {
  final PageController _memoPageController = PageController();
  final ScrollController _styleScrollController = ScrollController();

  List<String> _memoPages = const [''];
  List<GlobalKey> _shareCardKeys = [];
  bool _didBuildMemoPages = false;

  int _currentMemoPage = 0;

  bool _isProcessing = false;

  ShareCardStyle _selectedStyle = ShareCardStyle.paper;

  static const int _maxMemoLinesPerPage = 8;

  String _trimPageStart(String text) {
    return text.replaceFirst(
      RegExp(r'^[\s\u00A0]+'),
      '',
    );
  }

  @override
  void initState() {
    super.initState();

    _memoPages = const [''];
    _shareCardKeys = [
      GlobalKey(),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didBuildMemoPages) return;
    _didBuildMemoPages = true;

    final screenWidth = MediaQuery.of(context).size.width;

    /*
   * 실제 카드 폭
   *
   * 미리보기 폭: screenWidth * 0.9
   * 미리보기 Container 좌우 padding
   * PageView item 좌우 padding 제외
   */
    final cardWidth = (screenWidth * 0.9) -
        (screenWidth * 0.025 * 2) -
        (screenWidth * 0.008 * 2);

    /*
   * 카드 자체 좌우 여백과
   * 메모 박스 내부 좌우 여백 제외
   */
    final cardHeight =
        cardWidth * 5 / 4;

// 카드 좌우 padding
    final memoTextWidth =
        cardWidth -
            (cardWidth * 0.085 * 2);

/*
 * 카드 전체 높이에서
 *
 * 상단 padding
 * header
 * header → memo 여백
 * memo → book 여백
 * book info
 * book → footer 여백
 * footer
 * 하단 padding
 *
 * 을 제외한 실제 memo 영역 높이
 */

// 상단 READING NOTE 영역
    final headerHeight =
        cardWidth * 0.065;

// 작은 책 표지 높이
    final bookInfoHeight =
        (cardWidth * 0.105 * 1.45) +
            (cardWidth * 0.035);

// footer 예상 높이
    final footerHeight =
        cardWidth * 0.04;

    final memoAreaHeight =
        cardHeight
            // 카드 top/bottom padding
            - cardWidth * 0.07
            - cardWidth * 0.065

            // header
            - headerHeight

            // header → memo
            - cardWidth * 0.055

            // memo → book info
            - cardWidth * 0.05

            // book info
            - bookInfoHeight

            // book info → footer
            - cardWidth * 0.045

            // footer
            - footerHeight;

// 따옴표가 차지하는 공간까지 제외
    final memoTextHeight =
        memoAreaHeight -
            (cardWidth * 0.085);

    _memoPages = _splitMemoByHeight(
      widget.memoContent,
      maxWidth: memoTextWidth,
      maxHeight: memoTextHeight,
      fontSize: cardWidth * 0.044,
      lineHeight: 1.62,
      textScaler:
      MediaQuery.textScalerOf(context),
    );

    _shareCardKeys = List.generate(
      _memoPages.length,
          (_) => GlobalKey(),
    );
  }

  @override
  void dispose() {
    _memoPageController.dispose();
    _styleScrollController.dispose();
    super.dispose();
  }

  List<String> _splitMemoByHeight(
      String text, {
        required double maxWidth,
        required double maxHeight,
        required double fontSize,
        required double lineHeight,
        required TextScaler textScaler,
      }) {
    final normalized = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    if (normalized.isEmpty) {
      return const [''];
    }

    final textStyle = TextStyle(
      fontFamily: 'kopub',
      fontSize: fontSize,
      height: lineHeight,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.15,
    );

    final pages = <String>[];

    // =================================================
    // 1. 빈 줄(\n\n)을 기준으로 문단 분리
    // =================================================

    final paragraphs = normalized
        .split(
      RegExp(r'\n\s*\n'),
    )
        .map((paragraph) => paragraph.trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList();

    // =================================================
    // 2. 각 문단은 반드시 새 카드에서 시작
    // =================================================

    for (final paragraph in paragraphs) {
      String remaining = paragraph;

      while (remaining.isNotEmpty) {
        // -------------------------------------------------
        // 문단의 남은 내용 전체가 카드 한 장에 들어가면
        // 그대로 한 장 생성
        // -------------------------------------------------

        if (_fitsWithinHeight(
          remaining,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          style: textStyle,
          textScaler: textScaler,
        )) {
          pages.add(
            remaining.trim(),
          );

          break;
        }

        // =================================================
        // 카드에 들어가는 최대 글자 위치 탐색
        // =================================================

        int low = 1;
        int high = remaining.length;
        int bestFitIndex = 1;

        while (low <= high) {
          final middle =
              (low + high) ~/ 2;

          final candidate =
          remaining.substring(
            0,
            middle,
          );

          if (_fitsWithinHeight(
            candidate,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            style: textStyle,
            textScaler: textScaler,
          )) {
            bestFitIndex = middle;
            low = middle + 1;
          } else {
            high = middle - 1;
          }
        }

        // =================================================
        // 문장 끝 → 줄바꿈 → 공백 순서로
        // 최대한 자연스럽게 자름
        // =================================================

        final splitIndex =
        _findNaturalSplitIndex(
          remaining,
          bestFitIndex,
        );

        final pageText =
        remaining
            .substring(
          0,
          splitIndex,
        )
            .trim();

        if (pageText.isNotEmpty) {
          pages.add(pageText);
        }

        remaining =
            _trimPageStart(
              remaining.substring(
                splitIndex,
              ),
            ).trimRight();
      }
    }

    return pages.isEmpty
        ? const ['']
        : pages;
  }

  bool _fitsWithinHeight(
      String text, {
        required double maxWidth,
        required double maxHeight,
        required TextStyle style,
        required TextScaler textScaler,
      }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: style,
      ),
      textDirection:
      TextDirection.ltr,
      textScaler: textScaler,
    )..layout(
      maxWidth: maxWidth,
    );

    return painter.height <= maxHeight;
  }

  int _findNaturalSplitIndex(
      String text,
      int maximumIndex,
      ) {
    if (maximumIndex >= text.length) {
      return text.length;
    }

    if (maximumIndex <= 1) {
      return 1;
    }

    final candidate =
    text.substring(
      0,
      maximumIndex,
    );

    /*
   * 카드 공간을 최대한 채우되,
   * 너무 멀리 뒤로 후퇴하지 않도록
   * 마지막 약 20% 범위 안에서
   * 자연스러운 끊김 위치를 찾는다.
   */
    final searchBackDistance =
    (maximumIndex * 0.20)
        .round()
        .clamp(
      12,
      80,
    );

    final minimumIndex =
    (maximumIndex -
        searchBackDistance)
        .clamp(
      1,
      maximumIndex,
    );

    // =================================================
    // 1순위: 문장 끝
    // =================================================

    final sentenceEnd =
    _findLastSentenceEnd(
      candidate,
      minimumIndex,
    );

    if (sentenceEnd != null) {
      return sentenceEnd;
    }

    // =================================================
    // 2순위: 일반 줄바꿈
    // =================================================

    final lineBreak =
    candidate.lastIndexOf(
      '\n',
    );

    if (lineBreak >= minimumIndex) {
      return lineBreak + 1;
    }

    // =================================================
    // 3순위: 공백
    // =================================================

    final spaceIndex =
    candidate.lastIndexOf(
      ' ',
    );

    if (spaceIndex >= minimumIndex) {
      return spaceIndex + 1;
    }

    // =================================================
    // 마지막 수단: 카드에 들어가는 최대 위치
    // =================================================

    return maximumIndex;
  }

  int? _findLastSentenceEnd(
      String text,
      int minimumIndex,
      ) {
    const endings = [
      '.',
      '?',
      '!',
      '。',
      '？',
      '！',
    ];

    // 문장 끝 뒤에 붙어 있을 수 있는
    // 따옴표 / 괄호류
    const trailingClosers = [
      '"',
      "'",
      '”',
      '“',
      '’',
      '‘',
      '」',
      '』',
      '》',
      '〉',
      ')',
      ']',
      '}',
    ];

    int? bestIndex;

    for (final ending in endings) {
      final index = text.lastIndexOf(
        ending,
      );

      if (index >= minimumIndex) {
        int splitIndex =
            index + ending.length;

        // =================================================
        // 문장부호 바로 뒤의 닫는 따옴표/괄호도
        // 같은 문장에 포함
        // =================================================

        while (splitIndex < text.length) {
          final nextChar =
          text.substring(
            splitIndex,
            splitIndex + 1,
          );

          if (trailingClosers.contains(
            nextChar,
          )) {
            splitIndex++;
          } else {
            break;
          }
        }

        if (bestIndex == null ||
            splitIndex > bestIndex) {
          bestIndex = splitIndex;
        }
      }
    }

    return bestIndex;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 20) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF013328),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
          ),
          title: const Text(
            '메모 공유',
            style: TextStyle(
              color: Colors.white,
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
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    screenWidth * 0.05,
                    screenWidth * 0.03,
                    screenWidth * 0.05,
                    screenWidth * 0.05,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPreviewSection(screenWidth),
                      SizedBox(height: screenWidth * 0.06),
                      _buildStyleSection(screenWidth),
                    ],
                  ),
                ),
              ),
              ShareCardActionBar(
                isProcessing: _isProcessing,
                onSave: _saveImages,
                onShare: _shareImages,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewSection(double screenWidth) {
    final previewWidth = screenWidth * 0.9;
    final previewHeight = previewWidth * 1.25;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '미리보기',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'kopub',
                  fontWeight: FontWeight.bold,
                  fontSize: screenWidth * 0.04,
                ),
              ),
            ),

            if (_memoPages.length > 1)
              Text(
                '${_currentMemoPage + 1} / ${_memoPages.length}',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.033,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),

        SizedBox(height: screenWidth * 0.025),

        if (_memoPages.length > 1)
          Row(
            children: [
              Icon(
                Icons.swipe_rounded,
                color: Colors.white54,
                size: screenWidth * 0.045,
              ),
              SizedBox(width: screenWidth * 0.015),
              Text(
                '긴 메모를 여러 장으로 나눴어요. 옆으로 넘겨보세요.',
                style: TextStyle(
                  color: Colors.white60,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.03,
                ),
              ),
            ],
          ),

        if (_memoPages.length > 1)
          SizedBox(height: screenWidth * 0.025),

        Container(
          width: double.infinity,
          padding: EdgeInsets.all(screenWidth * 0.025),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          child: SizedBox(
            height: previewHeight,
            child: PageView.builder(
              controller: _memoPageController,
              itemCount: _memoPages.length,
              onPageChanged: (index) {
                setState(() {
                  _currentMemoPage = index;
                });
              },
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.008,
                  ),
                  child: RepaintBoundary(
                    key: _shareCardKeys[index],
                    child: AspectRatio(
                      aspectRatio: 4 / 5,
                      child: ColoredBox(
                        color: ShareCardTheme.fromStyle(
                          _selectedStyle,
                        ).backgroundColor,
                        child: _NoteShareCard(
                          book: widget.book,
                          memoContent: _memoPages[index],
                          savedAt: widget.savedAt,
                          cardStyle: _selectedStyle,
                          pageIndex: index,
                          pageCount: _memoPages.length,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        if (_memoPages.length > 1) ...[
          SizedBox(height: screenWidth * 0.025),
          _buildMemoPageIndicator(screenWidth),
        ],
      ],
    );
  }

  Widget _buildMemoPageIndicator(double screenWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _memoPages.length,
            (index) {
          final isSelected = index == _currentMemoPage;

          return GestureDetector(
            onTap: () {
              _memoPageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.008,
              ),
              width: isSelected
                  ? screenWidth * 0.055
                  : screenWidth * 0.018,
              height: screenWidth * 0.018,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.amberAccent
                    : Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
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
              physics: const BouncingScrollPhysics(),
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
                final item = shareCardStyles[index];

                return SizedBox(
                  width: screenWidth * 0.2,
                  child: ShareCardStyleOption(
                    label: item.label,
                    backgroundColor:
                    item.backgroundColor,
                    accentColor: item.accentColor,
                    isSelected:
                    _selectedStyle == item.style,
                    onTap: () {
                      setState(() {
                        _selectedStyle = item.style;
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

  Future<Uint8List> _captureCard(GlobalKey cardKey) async {
    final cardContext = cardKey.currentContext;

    if (cardContext == null) {
      throw Exception('공유카드를 찾을 수 없습니다.');
    }

    final renderObject = cardContext.findRenderObject();

    if (renderObject is! RenderRepaintBoundary) {
      throw Exception('공유카드를 이미지로 변환할 수 없습니다.');
    }

    final ui.Image image = await renderObject.toImage(
      pixelRatio: 3.0,
    );

    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) {
      throw Exception('이미지 데이터를 생성하지 못했습니다.');
    }

    return byteData.buffer.asUint8List();
  }

  Future<List<Uint8List>> _captureAllCards() async {
    if (!_memoPageController.hasClients) {
      throw Exception('공유카드가 아직 준비되지 않았습니다.');
    }

    final originalPage = _currentMemoPage;
    final images = <Uint8List>[];

    try {
      for (int index = 0; index < _memoPages.length; index++) {
        _memoPageController.jumpToPage(index);

        await WidgetsBinding.instance.endOfFrame;
        await Future<void>.delayed(
          const Duration(milliseconds: 80),
        );

        final imageBytes = await _captureCard(
          _shareCardKeys[index],
        );

        images.add(imageBytes);
      }
    } finally {
      if (_memoPageController.hasClients) {
        _memoPageController.jumpToPage(originalPage);
        await WidgetsBinding.instance.endOfFrame;
      }

      if (mounted) {
        setState(() {
          _currentMemoPage = originalPage;
        });
      }
    }

    return images;
  }

  Future<void> _saveImages() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      bool hasAccess = await Gal.hasAccess();

      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
      }

      if (!hasAccess) {
        throw Exception('사진 앨범 접근 권한이 필요합니다.');
      }

      final images = await _captureAllCards();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      for (int index = 0; index < images.length; index++) {
        await Gal.putImageBytes(
          images[index],
          name: 'labrary_note_${timestamp}_${index + 1}',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              images.length == 1
                  ? '공유카드를 사진 앨범에 저장했어요.'
                  : '공유카드 ${images.length}장을 사진 앨범에 저장했어요.',
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
            backgroundColor: Colors.redAccent,
          ),
        );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
            backgroundColor: Colors.redAccent,
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

  String _galErrorMessage(GalException exception) {
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

  Future<void> _shareImages(BuildContext shareContext) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final images = await _captureAllCards();

      final files = List.generate(
        images.length,
            (index) {
          return XFile.fromData(
            images[index],
            mimeType: 'image/png',
            name: 'labrary_note_${index + 1}.png',
          );
        },
      );

      final fileNames = List.generate(
        images.length,
            (index) => 'labrary_note_${index + 1}.png',
      );

      final renderBox =
      shareContext.findRenderObject() as RenderBox?;

      final shareOrigin = renderBox != null
          ? renderBox.localToGlobal(Offset.zero) & renderBox.size
          : const Rect.fromLTWH(0, 0, 1, 1);

      await Share.shareXFiles(
        files,
        fileNameOverrides: fileNames,
        sharePositionOrigin: shareOrigin,
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
            backgroundColor: Colors.redAccent,
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

}

class _NoteShareCard
    extends StatelessWidget {
  final BookModel book;
  final String memoContent;
  final DateTime? savedAt;

  final ShareCardStyle cardStyle;

  final int pageIndex;
  final int pageCount;

  const _NoteShareCard({
    required this.book,
    required this.memoContent,
    required this.savedAt,
    required this.cardStyle,
    required this.pageIndex,
    required this.pageCount,
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

          return Stack(
            children: [
              Padding(
                padding:
                EdgeInsets.fromLTRB(
                  cardWidth * 0.085,
                  cardWidth * 0.07,
                  cardWidth * 0.085,
                  cardWidth * 0.065,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    // =================================================
                    // TOP EDITORIAL HEADER
                    // =================================================

                    _buildTopHeader(
                      cardWidth:
                      cardWidth,
                      style: style,
                    ),

                    SizedBox(
                      height:
                      cardWidth * 0.055,
                    ),

                    // =================================================
                    // MEMO
                    // =================================================

                    Expanded(
                      child:
                      _buildMemoContent(
                        cardWidth:
                        cardWidth,
                        style: style,
                      ),
                    ),

                    SizedBox(
                      height:
                      cardWidth * 0.05,
                    ),

                    // =================================================
                    // BOOK INFO
                    // =================================================

                    _buildBookInfo(
                      cardWidth:
                      cardWidth,
                      style: style,
                      highResImageUrl:
                      highResImageUrl,
                    ),

                    SizedBox(
                      height:
                      cardWidth * 0.045,
                    ),

                    // =================================================
                    // FOOTER
                    // =================================================

                    _buildFooter(
                      cardWidth:
                      cardWidth,
                      style: style,
                    ),
                  ],
                ),
              ),
            ],
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
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                'READING NOTE',
                style: TextStyle(
                  color:
                  style.accentColor,
                  fontFamily: 'kopub',
                  fontSize:
                  cardWidth * 0.025,
                  fontWeight:
                  FontWeight.bold,
                  letterSpacing: 2.2,
                ),
              ),

              SizedBox(
                height:
                cardWidth * 0.022,
              ),

              Container(
                width:
                cardWidth * 0.09,
                height: 2,
                color:
                style.accentColor,
              ),
            ],
          ),
        ),

        Column(
          crossAxisAlignment:
          CrossAxisAlignment.end,
          children: [
            if (pageCount > 1)
              Text(
                '${(pageIndex + 1).toString().padLeft(2, '0')} / '
                    '${pageCount.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: style
                      .secondaryTextColor,
                  fontFamily: 'kopub',
                  fontSize:
                  cardWidth * 0.023,
                  fontWeight:
                  FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),

            if (savedAt != null) ...[
              if (pageCount > 1)
                SizedBox(
                  height:
                  cardWidth * 0.012,
                ),

              Text(
                _formatDate(
                  savedAt!,
                ),
                style: TextStyle(
                  color: style
                      .secondaryTextColor,
                  fontFamily: 'kopub',
                  fontSize:
                  cardWidth * 0.022,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMemoContent({
    required double cardWidth,
    required ShareCardTheme style,
  }) {
    return Align(
      alignment:
      Alignment.centerLeft,
      child: Column(
        mainAxisSize:
        MainAxisSize.min,
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            '“',
            style: TextStyle(
              color:
              style.accentColor,
              fontFamily: 'kopub',
              fontSize:
              cardWidth * 0.12,
              fontWeight:
              FontWeight.w400,
              height: 0.5,
            ),
          ),

          SizedBox(
            height:
            cardWidth * 0.005,
          ),

          Text(
            memoContent,
            textAlign:
            TextAlign.left,
            textWidthBasis:
            TextWidthBasis.parent,
            style: TextStyle(
              color:
              style.primaryTextColor,
              fontFamily: 'kopub',
              fontSize:
              cardWidth * 0.044,
              fontWeight:
              FontWeight.w500,
              height: 1.62,
              letterSpacing: -0.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookInfo({
    required double cardWidth,
    required ShareCardTheme style,
    required String highResImageUrl,
  }) {
    final coverWidth =
        cardWidth * 0.105;

    final coverHeight =
        coverWidth * 1.45;

    return Container(
      padding: EdgeInsets.only(
        top:
        cardWidth * 0.035,
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
        children: [
          // =================================================
          // 작은 책 표지
          // =================================================

          Container(
            width: coverWidth,
            height: coverHeight,
            decoration:
            BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color:
                  style.shadowColor,
                  blurRadius: 8,
                  offset:
                  const Offset(
                    0,
                    4,
                  ),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius:
              BorderRadius.circular(
                2,
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
          ),

          SizedBox(
            width:
            cardWidth * 0.032,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  book.title,
                  maxLines: 2,
                  overflow:
                  TextOverflow
                      .ellipsis,
                  style: TextStyle(
                    color: style
                        .primaryTextColor,
                    fontFamily:
                    'kopub',
                    fontSize:
                    cardWidth *
                        0.033,
                    fontWeight:
                    FontWeight
                        .bold,
                    height: 1.3,
                  ),
                ),

                if (book.author
                    .trim()
                    .isNotEmpty) ...[
                  SizedBox(
                    height:
                    cardWidth *
                        0.009,
                  ),

                  Text(
                    book.author,
                    maxLines: 1,
                    overflow:
                    TextOverflow
                        .ellipsis,
                    style:
                    TextStyle(
                      color: style
                          .secondaryTextColor,
                      fontFamily:
                      'kopub',
                      fontSize:
                      cardWidth *
                          0.026,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
            letterSpacing: 0.2,
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
        size: 24,
      ),
    );
  }

  String _formatDate(
      DateTime date,
      ) {
    final year =
    date.year.toString();

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
}

