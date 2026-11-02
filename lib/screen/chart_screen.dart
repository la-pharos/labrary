import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:dayverse_book/provider/reading_stats_provider.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';

import 'package:dayverse_book/screen/chart_activity_screen.dart';
import 'package:dayverse_book/screen/chart_report_screen.dart';
import 'package:dayverse_book/screen/chart_stats_screen.dart';
import 'package:dayverse_book/screen/level_screen.dart';

import 'package:dayverse_book/utils/level_utils.dart';
import 'package:dayverse_book/widget/card_box.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';

import 'package:dayverse_book/screen/memo_screen.dart';
import 'package:dayverse_book/screen/chart_challenge_done_screen.dart';

class ChartScreen extends StatelessWidget {
  const ChartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    final savedBooksProvider =
    context.watch<SavedBooksProvider>();

    final readingStatsProvider =
    context.watch<ReadingStatsProvider>();

    final challengeProvider =
    context.watch<ChallengeProvider>();

    final savedBooks =
        savedBooksProvider.savedBooks;

    final completedChallenges =
        challengeProvider.completedChallenges;

    final memoRecords = savedBooksProvider.bookRecords
        .where(
          (record) =>
      record['content'] != '독서 타이머 기록',
    )
        .toList();

    final totalMemoCount =
        memoRecords.length;

    final totalCompletedChallengeCount =
        completedChallenges.length;

    final summary =
        readingStatsProvider.weeklySummary;

    final longestStreakDays =
    _calculateLongestStreak(
      readingStatsProvider.dailyReadingMinutes,
    );

    final totalReadingDays =
    _calculateTotalReadingDays(
      readingStatsProvider.dailyReadingMinutes,
    );

    final totalRead = savedBooks
        .where((book) => book.category == 'done')
        .length;

    final currentLevel =
    LevelUtils.getCurrentLevel(totalRead);

    final booksToNext =
    LevelUtils.getBooksUntilNextLevel(totalRead);

    return Scaffold(
      backgroundColor: const Color(0xFF013328),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(screenWidth),

            Expanded(
              child: RefreshIndicator(
                color: Colors.amberAccent,
                backgroundColor:
                const Color(0xFF16483F),
                onRefresh: () async {
                  await readingStatsProvider.refresh();
                },
                child: SingleChildScrollView(
                  physics:
                  const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    screenWidth * 0.05,
                    screenHeight * 0.012,
                    screenWidth * 0.05,
                    screenHeight * 0.18,
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [

                      SizedBox(height: screenHeight * 0.02),

                      _buildSectionTitle(
                        screenWidth,
                        'READING OVERVIEW',
                      ),

                      SizedBox(
                        height: screenHeight * 0.014,
                      ),

                      _buildOverviewCard(
                        context: context,
                        totalRead: totalRead,
                        totalReadingMinutes:
                        readingStatsProvider.totalReadingMinutes,
                        totalReadingDays:
                        totalReadingDays,
                        longestStreakDays:
                        longestStreakDays,
                      ),

                      SizedBox(
                        height: screenHeight * 0.03,
                      ),

                      _buildSectionTitle(
                        screenWidth,
                        'READING ACTIVITY',
                      ),

                      SizedBox(
                        height: screenHeight * 0.014,
                      ),

                      _buildActivityCard(
                        context: context,
                        screenWidth: screenWidth,
                        screenHeight: screenHeight,
                        readingStatsProvider:
                        readingStatsProvider,
                      ),

                      SizedBox(
                        height: screenHeight * 0.03,
                      ),

                      _buildSectionTitle(
                        screenWidth,
                        'READING STATS',
                      ),

                      SizedBox(
                        height: screenHeight * 0.014,
                      ),

                      _buildStatsCard(
                        context: context,
                        screenWidth: screenWidth,
                        screenHeight: screenHeight,
                        readingStatsProvider:
                        readingStatsProvider,
                      ),

                      SizedBox(
                        height: screenHeight * 0.03,
                      ),

                      _buildSectionTitle(
                        screenWidth,
                        'MY LEVEL',
                      ),

                      SizedBox(
                        height: screenHeight * 0.014,
                      ),

                      _buildLevelCard(
                        context: context,
                        screenWidth: screenWidth,
                        screenHeight: screenHeight,
                        totalRead: totalRead,
                        currentLevel: currentLevel,
                        booksToNext: booksToNext,
                      ),


                      SizedBox(
                        height: screenHeight * 0.03,
                      ),

                      _buildSectionTitle(
                        screenWidth,
                        'MY ARCHIVE',
                      ),

                      SizedBox(
                        height: screenHeight * 0.014,
                      ),

                      _buildArchiveSection(
                        context: context,
                        screenWidth: screenWidth,
                        screenHeight: screenHeight,
                        totalMemoCount: totalMemoCount,
                        totalCompletedChallengeCount:
                        totalCompletedChallengeCount,
                      ),

                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.05,
        vertical: screenWidth * 0.0055,
      ),
      child: Text(
        'CHART',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'kopub',
          fontSize: screenWidth * 0.045,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

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

  Widget _buildOverviewCard({
    required BuildContext context,
    required int totalRead,
    required int totalReadingMinutes,
    required int totalReadingDays,
    required int longestStreakDays,
  }) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.022,
        vertical: screenHeight * 0.018,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildOverviewItem(
              screenWidth: screenWidth,
              icon: Icons.schedule_rounded,
              value: _formatOverviewMinutes(
                totalReadingMinutes,
              ),
              label: '총 독서시간',
            ),
          ),

          _buildOverviewDivider(
            screenHeight,
          ),

          Expanded(
            child: _buildOverviewItem(
              screenWidth: screenWidth,
              icon: Icons.menu_book_rounded,
              value: '$totalRead권',
              label: '총 완독',
            ),
          ),

          _buildOverviewDivider(
            screenHeight,
          ),

          Expanded(
            child: _buildOverviewItem(
              screenWidth: screenWidth,
              icon: Icons.check_circle,
              value: '$totalReadingDays일',
              label: '총 독서일',
            ),
          ),

          _buildOverviewDivider(
            screenHeight,
          ),

          Expanded(
            child: _buildOverviewItem(
              screenWidth: screenWidth,
              icon: Icons.local_fire_department_rounded,
              value: '$longestStreakDays일',
              label: '최장 연속',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewItem({
    required double screenWidth,
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.amberAccent,
          size: screenWidth * 0.04,
        ),

        SizedBox(
          height: screenWidth * 0.011,
        ),

        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'kopub',
            fontSize: screenWidth * 0.032,
            fontWeight: FontWeight.bold,
          ),
        ),

        SizedBox(
          height: screenWidth * 0.005,
        ),

        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.52),
            fontFamily: 'kopub',
            fontSize: screenWidth * 0.022,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewDivider(
      double screenHeight,
      ) {
    return Container(
      width: 1,
      height: screenHeight * 0.055,
      color: Colors.white.withOpacity(0.1),
    );
  }

  String _formatOverviewMinutes(
      int totalMinutes,
      ) {
    if (totalMinutes <= 0) {
      return '0분';
    }

    if (totalMinutes < 60) {
      return '$totalMinutes분';
    }

    final hours = totalMinutes ~/ 60;

    return '$hours시간';
  }

  Widget _buildActivityCard({
    required BuildContext context,
    required double screenWidth,
    required double screenHeight,
    required ReadingStatsProvider readingStatsProvider,
  }) {
    final summary =
        readingStatsProvider.weeklySummary;

    final weeklyReadingDays =
        summary.dailyMinutes
            .where((minutes) => minutes > 0)
            .length;

    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(
        screenWidth * 0.045,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
            const ChartActivityScreen(),
          ),
        );
      },
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: screenWidth * 0.13,
                height: screenWidth * 0.13,
                decoration: BoxDecoration(
                  color: Colors.amberAccent
                      .withOpacity(0.1),
                  borderRadius:
                  BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons
                      .local_fire_department_rounded,
                  color: Colors.amberAccent,
                  size: screenWidth * 0.065,
                ),
              ),

              SizedBox(
                width: screenWidth * 0.04,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      _buildStreakMessage(
                        streakDays:
                        summary.streakDays,
                        hasReadToday:
                        summary.hasReadToday,
                      ),
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'kopub',
                        fontSize:
                        screenWidth * 0.037,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    SizedBox(
                      height:
                      screenHeight * 0.007,
                    ),

                    Text(
                      weeklyReadingDays > 0
                          ? '이번 주 $weeklyReadingDays일 독서했어요'
                          : '이번 주 첫 독서를 시작해보세요',
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white
                            .withOpacity(0.58),
                        fontFamily: 'kopub',
                        fontSize:
                        screenWidth * 0.029,
                      ),
                    ),
                  ],
                ),
              ),

              _buildArrow(screenWidth),
            ],
          ),

          SizedBox(
            height: screenHeight * 0.021,
          ),

          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withOpacity(0.1),
          ),

          SizedBox(
            height: screenHeight * 0.019,
          ),

          _buildWeekDays(
            screenWidth: screenWidth,
            dailyMinutes:
            summary.dailyMinutes,
          ),
        ],
      ),
    );
  }

  Widget _buildWeekDays({
    required double screenWidth,
    required List<int> dailyMinutes,
  }) {
    const labels = [
      '월',
      '화',
      '수',
      '목',
      '금',
      '토',
      '일',
    ];

    return Row(
      children: List.generate(
        labels.length,
            (index) {
          final hasRead =
              index < dailyMinutes.length &&
                  dailyMinutes[index] > 0;

          final isToday =
              index ==
                  DateTime.now().weekday - 1;

          return Expanded(
            child: Column(
              children: [
                Container(
                  width: screenWidth * 0.047,
                  height: screenWidth * 0.047,
                  decoration: BoxDecoration(
                    color: hasRead
                        ? Colors.amberAccent
                        : Colors.white
                        .withOpacity(0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isToday
                          ? Colors.white
                          .withOpacity(0.9)
                          : Colors.white
                          .withOpacity(0.16),
                      width: isToday ? 1.5 : 1,
                    ),
                  ),
                  child: hasRead
                      ? Icon(
                    Icons.check_rounded,
                    color: const Color(
                      0xFF013328,
                    ),
                    size:
                    screenWidth * 0.03,
                  )
                      : null,
                ),

                SizedBox(
                  height: screenWidth * 0.01,
                ),

                Text(
                  labels[index],
                  style: TextStyle(
                    color: isToday
                        ? Colors.white
                        : Colors.white
                        .withOpacity(0.48),
                    fontFamily: 'kopub',
                    fontSize:
                    screenWidth * 0.024,
                    fontWeight: isToday
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsCard({
    required BuildContext context,
    required double screenWidth,
    required double screenHeight,
    required ReadingStatsProvider readingStatsProvider,
  }) {
    final summary =
        readingStatsProvider.weeklySummary;

    final difference =
        summary.thisWeekMinutes -
            summary.lastWeekMinutes;

    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(
        screenWidth * 0.045,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
            const ChartStatsScreen(),
          ),
        );
      },
      child: Row(
        children: [
          Container(
            width: screenWidth * 0.13,
            height: screenWidth * 0.13,
            decoration: BoxDecoration(
              color:
              Colors.amberAccent.withOpacity(
                0.1,
              ),
              borderRadius:
              BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.bar_chart_rounded,
              color: Colors.amberAccent,
              size: screenWidth * 0.065,
            ),
          ),

          SizedBox(
            width: screenWidth * 0.04,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  '이번 주 ${_formatMinutes(summary.thisWeekMinutes)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'kopub',
                    fontSize:
                    screenWidth * 0.037,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(
                  height: screenHeight * 0.007,
                ),

                Text(
                  _buildDifferenceMessage(
                    difference,
                  ),
                  style: TextStyle(
                    color:
                    Colors.white.withOpacity(
                      0.58,
                    ),
                    fontFamily: 'kopub',
                    fontSize:
                    screenWidth * 0.029,
                  ),
                ),
              ],
            ),
          ),

          _buildArrow(screenWidth),
        ],
      ),
    );
  }

  Widget _buildLevelCard({
    required BuildContext context,
    required double screenWidth,
    required double screenHeight,
    required int totalRead,
    required LevelInfo currentLevel,
    required int booksToNext,
  }) {
    final progress =
    LevelUtils.getLevelProgress(totalRead);

    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(
        screenWidth * 0.045,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LevelScreen(
              totalRead: totalRead,
              currentLevel: currentLevel,
              booksToNext: booksToNext,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: screenWidth * 0.13,
                height: screenWidth * 0.13,
                decoration: BoxDecoration(
                  color: currentLevel.color
                      .withOpacity(0.1),
                  borderRadius:
                  BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: LevelUtils.buildLevelIcon(
                  currentLevel,
                  size: screenWidth * 0.065,
                ),
              ),

              SizedBox(
                width: screenWidth * 0.04,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentLevel.name,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: TextStyle(
                        color: currentLevel.color,
                        fontFamily: 'kopub',
                        fontSize:
                        screenWidth * 0.037,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    SizedBox(
                      height:
                      screenHeight * 0.007,
                    ),

                    Text(
                      currentLevel.end == null
                          ? '총 $totalRead권 완독 · 최고 레벨을 달성했어요'
                          : '총 $totalRead권 완독 · 다음 레벨까지 $booksToNext권',
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white
                            .withOpacity(0.58),
                        fontFamily: 'kopub',
                        fontSize:
                        screenWidth * 0.029,
                      ),
                    ),
                  ],
                ),
              ),

              _buildArrow(screenWidth),
            ],
          ),

          SizedBox(
            height: screenHeight * 0.02,
          ),

          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius:
                  BorderRadius.circular(999),
                  child:
                  LinearProgressIndicator(
                    value: progress,
                    minHeight:
                    screenHeight * 0.008,
                    backgroundColor:
                    Colors.white
                        .withOpacity(0.1),
                    valueColor:
                    AlwaysStoppedAnimation<
                        Color>(
                      currentLevel.color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArrow(double screenWidth) {
    return Icon(
      Icons.chevron_right_rounded,
      color: Colors.white.withOpacity(0.55),
      size: screenWidth * 0.06,
    );
  }

  String _buildStreakMessage({
    required int streakDays,
    required bool hasReadToday,
  }) {
    if (streakDays >= 2) {
      return '$streakDays일 연속 독서 중';
    }

    if (hasReadToday) {
      return '오늘도 독서를 완료했어요';
    }

    if (streakDays == 1) {
      return '오늘도 읽으면 기록이 이어져요';
    }

    return '오늘부터 독서 기록을 시작해보세요';
  }

  String _buildDifferenceMessage(
      int difference,
      ) {
    if (difference > 0) {
      return '지난주보다 ${_formatMinutes(difference)} 더 읽었어요';
    }

    if (difference < 0) {
      return '지난주보다 ${_formatMinutes(difference.abs())} 적게 읽었어요';
    }

    return '지난주와 같은 시간만큼 읽었어요';
  }

  int _calculateLongestStreak(
      Map<String, int> dailyMinutes,
      ) {
    final readingDates = dailyMinutes.entries
        .where((entry) => entry.value > 0)
        .map((entry) => DateTime.tryParse(entry.key))
        .whereType<DateTime>()
        .map(
          (date) => DateTime(
        date.year,
        date.month,
        date.day,
      ),
    )
        .toSet()
        .toList()
      ..sort();

    if (readingDates.isEmpty) {
      return 0;
    }

    int longestStreak = 1;
    int currentStreak = 1;

    for (int index = 1;
    index < readingDates.length;
    index++) {
      final difference = readingDates[index]
          .difference(
        readingDates[index - 1],
      )
          .inDays;

      if (difference == 1) {
        currentStreak++;
      } else {
        currentStreak = 1;
      }

      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }
    }

    return longestStreak;
  }

  int _calculateTotalReadingDays(
      Map<String, int> dailyMinutes,
      ) {
    return dailyMinutes.entries
        .where((entry) => entry.value > 0)
        .map((entry) => DateTime.tryParse(entry.key))
        .whereType<DateTime>()
        .map(
          (date) => DateTime(
        date.year,
        date.month,
        date.day,
      ),
    )
        .toSet()
        .length;
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

  Widget _buildArchiveSection({
    required BuildContext context,
    required double screenWidth,
    required double screenHeight,
    required int totalMemoCount,
    required int totalCompletedChallengeCount,
  }) {
    return Column(
      children: [
        /// 독서 결산
        _buildArchiveListCard(
          screenWidth: screenWidth,
          screenHeight: screenHeight,
          icon: Icons.auto_awesome_outlined,
          title: '독서 결산',
          description: '월간 · 연간 독서 기록을 돌아보세요',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                const ChartReportScreen(
                  initialType:
                  ChartReportType.monthly,
                ),
              ),
            );
          },
        ),

        SizedBox(
          height: screenHeight * 0.014,
        ),

        /// 달성한 챌린지
        _buildArchiveListCard(
          screenWidth: screenWidth,
          screenHeight: screenHeight,
          icon: Icons.emoji_events_rounded,
          title: '달성한 챌린지',
          description:
          '총 $totalCompletedChallengeCount개의 챌린지를 달성했어요',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                const ChartChallengeDoneScreen(),
              ),
            );
          },
        ),

        SizedBox(
          height: screenHeight * 0.014,
        ),

        /// 독서 메모
        _buildArchiveListCard(
          screenWidth: screenWidth,
          screenHeight: screenHeight,
          icon: Icons.edit_note_rounded,
          title: '메모',
          description:
          '총 $totalMemoCount개의 메모를 남겼어요',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                const MemoScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildArchiveListCard({
    required double screenWidth,
    required double screenHeight,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(
        screenWidth * 0.045,
      ),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: screenWidth * 0.13,
            height: screenWidth * 0.13,
            decoration: BoxDecoration(
              color: Colors.amberAccent
                  .withOpacity(0.1),
              borderRadius:
              BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: Colors.amberAccent,
              size: screenWidth * 0.062,
            ),
          ),

          SizedBox(
            width: screenWidth * 0.04,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'kopub',
                    fontSize:
                    screenWidth * 0.036,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                SizedBox(
                  height:
                  screenHeight * 0.006,
                ),

                Text(
                  description,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white
                        .withOpacity(0.52),
                    fontFamily: 'kopub',
                    fontSize:
                    screenWidth * 0.028,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            width: screenWidth * 0.02,
          ),

          Icon(
            Icons.chevron_right_rounded,
            color:
            Colors.white.withOpacity(0.5),
            size: screenWidth * 0.055,
          ),
        ],
      ),
    );
  }

}
