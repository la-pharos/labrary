import 'package:flutter/material.dart';
import 'package:dayverse_book/utils/level_utils.dart';
import 'package:dayverse_book/widget/ad_banner_placeholder.dart';


class LevelScreen extends StatelessWidget {
  final int totalRead;
  final LevelInfo currentLevel;
  final int booksToNext;

  const LevelScreen({
    super.key,
    required this.totalRead,
    required this.currentLevel,
    required this.booksToNext,
  });

  @override
  Widget build(BuildContext context) {
    final levels = LevelUtils.getAllLevels(totalRead);

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final horizontalPadding = screenWidth * 0.05;
    final cardPadding = screenWidth * 0.045;
    final cardMargin = screenHeight * 0.02;
    final levelFontSize = screenWidth * 0.045;
    final descFontSize = screenWidth * 0.035;
    final progressFontSize = screenWidth * 0.03;

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
          title: Text(
            "LEVEL",
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontWeight: FontWeight.w600,
              fontSize: screenWidth * 0.045,
              letterSpacing: 1.5,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Stack(
          children: [
            // ✅ 스크롤 가능한 본문 영역
            SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: horizontalPadding,
                  right: horizontalPadding,
                  bottom: screenHeight * 0.08, // ⬅ 광고 높이만큼 패딩 확보
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: screenHeight * 0.025),
                    _buildCurrentLevelCard(screenWidth, cardPadding, cardMargin, levelFontSize, descFontSize, progressFontSize),
                    SizedBox(height: screenHeight * 0.02),
                    const Divider(color: Colors.white30, thickness: 1),
                    SizedBox(height: screenHeight * 0.02),
                    Column(
                      children: levels.map((level) => _buildLevelRow(level, screenWidth)).toList(),
                    ),
                    SizedBox(height: screenHeight * 0.03),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.local_fire_department, color: Colors.redAccent),
                        SizedBox(width: screenWidth * 0.015),
                        Flexible(
                          child: Text(
                            "110권부터 10권마다 레전드 그랄 단계가 추가됩니다!",
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'kopub',
                              fontSize: descFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.05), // 콘텐츠 마무리 여백
                  ],
                ),
              ),
            ),

            // ✅ 광고 하단 고정
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BottomAdBannerBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentLevelCard(double screenWidth, double padding, double margin, double levelFontSize, double descFontSize, double progressFontSize) {
    double progress = ((totalRead - currentLevel.start) /
        (currentLevel.end - currentLevel.start + 1))
        .clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.all(padding),
      margin: EdgeInsets.only(bottom: margin),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LevelUtils.buildShieldIcon(currentLevel),
              SizedBox(width: screenWidth * 0.02),
              Text(
                currentLevel.name,
                style: TextStyle(
                  fontFamily: 'kopub',
                  fontSize: levelFontSize,
                  fontWeight: FontWeight.bold,
                  color: currentLevel.color,
                ),
              ),
            ],
          ),
          SizedBox(height: margin * 0.45),
          Text(
            currentLevel.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'kopub',
              fontSize: descFontSize,
            ),
          ),
          SizedBox(height: margin * 0.8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white24,
            color: currentLevel.color,
            minHeight: screenWidth * 0.02,
            borderRadius: BorderRadius.circular(10),
          ),
          SizedBox(height: margin * 0.4),
          Text(
            "다음 레벨까지 $booksToNext권 남음",
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'kopub',
              fontSize: progressFontSize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelRow(LevelInfo level, double screenWidth) {
    final fontSize = screenWidth * 0.04;
    final descFontSize = screenWidth * 0.032;
    final verticalMargin = screenWidth * 0.03;

    return Container(
      margin: EdgeInsets.only(bottom: verticalMargin),
      padding: EdgeInsets.all(screenWidth * 0.03),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LevelUtils.buildShieldIcon(level),
          SizedBox(width: screenWidth * 0.03),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level.name,
                  style: TextStyle(
                    color: level.color,
                    fontFamily: 'kopub',
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: screenWidth * 0.01),
                Text(
                  "${level.start}~${level.end}권",
                  style: TextStyle(
                    color: Colors.white70,
                    fontFamily: 'kopub',
                    fontSize: descFontSize,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              level.description,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontSize: descFontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }

}
