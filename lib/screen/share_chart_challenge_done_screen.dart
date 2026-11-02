import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/widget/card_box.dart';
import 'package:dayverse_book/widget/share_card_action_bar.dart';
import 'package:dayverse_book/widget/recurring_challenge_cover.dart';

class ShareChartChallengeDoneScreen extends StatefulWidget {
  final List<Challenge> challenges;

  const ShareChartChallengeDoneScreen({
    super.key,
    required this.challenges,
  });

  @override
  State<ShareChartChallengeDoneScreen> createState() =>
      _ShareChallengeDoneScreenState();
}

class _ShareChallengeDoneScreenState
    extends State<ShareChartChallengeDoneScreen> {
  final GlobalKey _shareCardKey = GlobalKey();

  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final screenWidth = size.width;
    final screenHeight = size.height;

    final completedCount =
        widget.challenges.length;

    final successfulAttempts =
    _getTotalSuccessfulAttempts(
      widget.challenges,
    );

    final repeatedChallengeCount =
    _getRepeatedChallengeCount(
      widget.challenges,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF013328),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          '달성한 챌린지 공유',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'kopub',
            fontSize: screenWidth * 0.045,
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
                physics:
                const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  screenWidth * 0.05,
                  screenHeight * 0.015,
                  screenWidth * 0.05,
                  screenHeight * 0.04,
                ),
                child: RepaintBoundary(
                  key: _shareCardKey,
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xFF013328),
                    padding: EdgeInsets.fromLTRB(
                      screenWidth * 0.035,
                      screenWidth * 0.04,
                      screenWidth * 0.035,
                      screenWidth * 0.045,
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        /// TROPHY
                        _buildAchievementHero(
                          completedCount:
                          completedCount,
                          screenWidth:
                          screenWidth,
                        ),

                        SizedBox(
                          height:
                          screenHeight * 0.018,
                        ),

                        /// SUMMARY
                        _buildAchievementSummary(
                          completedCount:
                          completedCount,
                          successfulAttempts:
                          successfulAttempts,
                          repeatedChallengeCount:
                          repeatedChallengeCount,
                          screenWidth:
                          screenWidth,
                        ),

                        SizedBox(
                          height:
                          screenHeight * 0.035,
                        ),

                        /// CHALLENGE COLLECTION
                        _buildSectionTitle(
                          screenWidth,
                          'CHALLENGE COLLECTION',
                        ),

                        SizedBox(
                          height:
                          screenHeight * 0.015,
                        ),

                        _buildChallengeCollection(
                          challenges:
                          widget.challenges,
                          screenWidth:
                          screenWidth,
                        ),

                        SizedBox(
                          height: screenWidth * 0.055,
                        ),

                        _buildShareFooter(
                          screenWidth,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            ShareCardActionBar(
              isProcessing:
              _isProcessing,
              onSave:
              _saveImage,
              onShare:
              _shareImage,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // HERO
  // =========================================================

  Widget _buildAchievementHero({
    required int completedCount,
    required double screenWidth,
  }) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05,
          vertical: screenWidth * 0.065,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.amberAccent.withOpacity(0.10),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          children: [
            Container(
              width: screenWidth * 0.19,
              height: screenWidth * 0.19,
              decoration: BoxDecoration(
                color: Colors.amberAccent.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.amberAccent.withOpacity(
                    0.28,
                  ),
                ),
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                color: Colors.amberAccent,
                size: screenWidth * 0.095,
              ),
            ),

            SizedBox(
              height: screenWidth * 0.035,
            ),

            Text(
              '$completedCount',
              style: TextStyle(
                color: Colors.amberAccent,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.11,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
            ),

            SizedBox(
              height: screenWidth * 0.015,
            ),

            Text(
              'CHALLENGES COMPLETED',
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.025,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),

            SizedBox(
              height: screenWidth * 0.035,
            ),

            Text(
              _getAchievementMessage(
                completedCount,
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.033,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getAchievementMessage(
      int count,
      ) {
    if (count >= 50) {
      return '꾸준한 도전이 당신만의 기록이 되었어요.';
    }

    if (count >= 20) {
      return '수많은 도전을 끝까지 완주했어요.';
    }

    if (count >= 10) {
      return '하나씩 쌓아온 도전이 멋진 성취가 되었어요.';
    }

    if (count >= 5) {
      return '꾸준히 도전하며 성취를 쌓아가고 있어요.';
    }

    return '첫 성취부터 하나씩 기록을 만들어가고 있어요.';
  }

  // =========================================================
  // SUMMARY
  // =========================================================

  Widget _buildAchievementSummary({
    required int completedCount,
    required int successfulAttempts,
    required int repeatedChallengeCount,
    required double screenWidth,
  }) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(
        vertical: screenWidth * 0.04,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              value: '$completedCount',
              label: '총 달성',
              screenWidth: screenWidth,
            ),
          ),

          _buildVerticalDivider(
            screenWidth,
          ),

          Expanded(
            child: _buildSummaryItem(
              value: '$successfulAttempts',
              label: '총 완주',
              screenWidth: screenWidth,
            ),
          ),

          _buildVerticalDivider(
            screenWidth,
          ),

          Expanded(
            child: _buildSummaryItem(
              value: '$repeatedChallengeCount',
              label: '반복 달성',
              screenWidth: screenWidth,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String value,
    required String label,
    required double screenWidth,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.amberAccent,
            fontFamily: 'kopub',
            fontSize: screenWidth * 0.046,
            fontWeight: FontWeight.bold,
          ),
        ),

        SizedBox(
          height: screenWidth * 0.01,
        ),

        Text(
          label,
          style: TextStyle(
            color: Colors.white54,
            fontFamily: 'kopub',
            fontSize: screenWidth * 0.028,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider(
      double screenWidth,
      ) {
    return Container(
      width: 1,
      height: screenWidth * 0.09,
      color: Colors.white.withOpacity(0.08),
    );
  }

  // =========================================================
  // CHALLENGE COLLECTION
  // =========================================================

  Widget _buildChallengeCollection({
    required List<Challenge> challenges,
    required double screenWidth,
  }) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(
        screenWidth * 0.035,
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: challenges.length,
        gridDelegate:
        const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 18,
          childAspectRatio: 0.80,
        ),
        itemBuilder: (
            context,
            index,
            ) {
          final challenge = challenges[index];

          return _buildCollectionItem(
            challenge: challenge,
            screenWidth: screenWidth,
          );
        },
      ),
    );
  }

  Widget _buildCollectionItem({
    required Challenge challenge,
    required double screenWidth,
  }) {
    final successfulCount =
        challenge.attempts
            .where(
              (attempt) =>
          attempt.completed &&
              attempt.isSuccessful,
        )
            .length;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: _buildCollectionImage(
                  challenge,
                ),
              ),

              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius:
                    BorderRadius.circular(12),
                    color:
                    Colors.black.withOpacity(0.16),
                  ),
                ),
              ),

              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: screenWidth * 0.065,
                  height: screenWidth * 0.065,
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFF013328,
                    ).withOpacity(0.9),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.amberAccent
                          .withOpacity(0.65),
                    ),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.amberAccent,
                    size: screenWidth * 0.038,
                  ),
                ),
              ),

              if (successfulCount > 1)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal:
                      screenWidth * 0.018,
                      vertical:
                      screenWidth * 0.008,
                    ),
                    decoration: BoxDecoration(
                      color:
                      Colors.black.withOpacity(0.55),
                      borderRadius:
                      BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${successfulCount}회',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontFamily: 'kopub',
                        fontSize:
                        screenWidth * 0.023,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        SizedBox(
          height: screenWidth * 0.018,
        ),

        Text(
          challenge.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontFamily: 'kopub',
            fontSize: screenWidth * 0.027,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }


  Widget _buildCollectionImage(
      Challenge challenge,
      ) {
    // =================================================
    // 정기 챌린지: Flutter 자동 커버
    // =================================================
    if (RecurringChallengeCover.supports(challenge)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: RecurringChallengeCover(
          challenge: challenge,
        ),
      );
    }

    // =================================================
    // 일반 챌린지: 기존 이미지 방식 유지
    // =================================================
    final url = challenge.imageUrl.trim();

    if (url.isEmpty) {
      return _buildCollectionFallback();
    }

    if (url.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return _buildCollectionFallback();
          },
        ),
      );
    }

    if (url.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return _buildCollectionFallback();
          },
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(url),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return _buildCollectionFallback();
        },
      ),
    );
  }

  Widget _buildCollectionFallback() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(
          Icons.emoji_events_outlined,
          color: Colors.white38,
        ),
      ),
    );
  }

  // =========================================================
  // COMMON
  // =========================================================

  Widget _buildSectionTitle(
      double screenWidth,
      String title,
      ) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white.withOpacity(0.72),
        fontFamily: 'kopub',
        fontSize: screenWidth * 0.032,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
      ),
    );
  }

  int _getTotalSuccessfulAttempts(
      List<Challenge> challenges,
      ) {
    int total = 0;

    for (final challenge in challenges) {
      total += challenge.attempts
          .where(
            (attempt) =>
        attempt.completed &&
            attempt.isSuccessful,
      )
          .length;
    }

    return total;
  }

  int _getRepeatedChallengeCount(
      List<Challenge> challenges,
      ) {
    return challenges.where(
          (challenge) {
        final successfulCount =
            challenge.attempts
                .where(
                  (attempt) =>
              attempt.completed &&
                  attempt.isSuccessful,
            )
                .length;

        return successfulCount > 1;
      },
    ).length;
  }

  Future<Uint8List> _captureShareCard() async {
    await WidgetsBinding.instance.endOfFrame;

    final cardContext =
        _shareCardKey.currentContext;

    if (cardContext == null) {
      throw Exception(
        '챌린지 기록을 찾을 수 없습니다.',
      );
    }

    final renderObject =
    cardContext.findRenderObject();

    if (renderObject
    is! RenderRepaintBoundary) {
      throw Exception(
        '챌린지 기록을 이미지로 변환할 수 없습니다.',
      );
    }

    final boundary = renderObject;

    const preferredPixelRatio = 3.0;
    const maxOutputDimension = 8000.0;

    final logicalWidth =
        boundary.size.width;

    final logicalHeight =
        boundary.size.height;

    if (logicalWidth <= 0 ||
        logicalHeight <= 0) {
      throw Exception(
        '공유 이미지의 크기를 확인할 수 없습니다.',
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

    final safePixelRatio =
    math.max(
      pixelRatio,
      0.1,
    );

    debugPrint(
      '[CHALLENGE SHARE] '
          'logicalSize=${boundary.size}, '
          'pixelRatio=$safePixelRatio',
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

  Future<void> _shareImage(
      BuildContext shareContext,
      ) async {
    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final imageBytes =
      await _captureShareCard();

      final file =
      XFile.fromData(
        imageBytes,
        mimeType: 'image/png',
        name:
        'labrary_challenges.png',
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
          'labrary_challenges.png',
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

  Future<void> _saveImage() async {
    if (_isProcessing) {
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
      await _captureShareCard();

      final timestamp =
          DateTime.now()
              .millisecondsSinceEpoch;

      await Gal.putImageBytes(
        imageBytes,
        name:
        'labrary_challenges_$timestamp',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              '챌린지 기록을 사진 앨범에 저장했어요.',
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

  Widget _buildShareFooter(
      double screenWidth,
      ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.01,
      ),
      child: Row(
        children: [
          Text(
            'Labrary',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.034,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),

          const Spacer(),

          Text(
            'Read. Challenge. Grow.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.42),
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.023,
            ),
          ),
        ],
      ),
    );
  }

}
