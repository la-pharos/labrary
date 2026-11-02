import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:dayverse_book/provider/reading_stats_provider.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/service/reading_log_service.dart';
import 'package:dayverse_book/widget/card_box.dart';

enum ChartStatsPeriod {
  week,
  month,
  year,
}

class ChartStatsScreen extends StatefulWidget {
  const ChartStatsScreen({super.key});

  @override
  State<ChartStatsScreen> createState() =>
      _ChartStatsScreenState();
}

class _ChartStatsScreenState
    extends State<ChartStatsScreen> {
  ChartStatsPeriod _selectedPeriod =
      ChartStatsPeriod.week;

  late DateTime _selectedMonth;
  late int _selectedYear;
  late DateTime _selectedWeekStart;

  int _periodSessions = 0;

  Map<String, dynamic>? _mostReadBook;

  bool _isLoadingPeriodStats = false;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    _selectedWeekStart = today.subtract(
      Duration(
        days: today.weekday - DateTime.monday,
      ),
    );

    _selectedMonth = DateTime(
      now.year,
      now.month,
      1,
    );

    _selectedYear = now.year;

    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      _loadPeriodStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    final readingStatsProvider =
    context.watch<ReadingStatsProvider>();

    final savedBooksProvider =
    context.watch<SavedBooksProvider>();

    final range = _getSelectedRange(
      DateTime.now(),
    );

    final previousRange =
    _getPreviousRange(range);

    final dailyMinutes =
        readingStatsProvider.dailyReadingMinutes;

    final periodMinutes =
    _sumMinutesByRange(
      dailyMinutes: dailyMinutes,
      start: range.start,
      end: range.end,
    );

    final previousMinutes =
    _sumMinutesByRange(
      dailyMinutes: dailyMinutes,
      start: previousRange.start,
      end: previousRange.end,
    );


    final completedBooks =
        savedBooksProvider.savedBooks.where(
              (book) {
            if (book.category != 'done' ||
                book.endDate == null) {
              return false;
            }

            final completedDate = DateTime(
              book.endDate!.year,
              book.endDate!.month,
              book.endDate!.day,
            );

            return !completedDate.isBefore(
              range.start,
            ) &&
                completedDate.isBefore(range.end);
          },
        ).length;

    final averageReadingMinutes =
    _periodSessions > 0
        ? periodMinutes ~/ _periodSessions
        : 0;


    final longestDay =
    _findLongestReadingDay(
      dailyMinutes: dailyMinutes,
      start: range.start,
      end: range.end,
    );

    final chartData =
    _createChartData(
      dailyMinutes: dailyMinutes,
      range: range,
    );

    final difference =
        periodMinutes - previousMinutes;

    return Scaffold(
      backgroundColor:
      const Color(0xFF013328),
      appBar: AppBar(
        backgroundColor:
        const Color(0xFF013328),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '독서 통계',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'kopub',
            fontSize: screenWidth * 0.045,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: Colors.amberAccent,
        backgroundColor:
        const Color(0xFF16483F),
        onRefresh: () async {
          await readingStatsProvider.refresh();
          await _loadPeriodStats();
        },
        child: SingleChildScrollView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            screenWidth * 0.05,
            screenHeight * 0.01,
            screenWidth * 0.05,
            screenHeight * 0.08,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              _buildPeriodSelector(
                screenWidth,
                screenHeight,
              ),

              SizedBox(
                height: screenHeight * 0.014,
              ),

              _buildDateNavigator(
                screenWidth: screenWidth,
                screenHeight: screenHeight,
              ),

              SizedBox(
                height: screenHeight * 0.028,
              ),

              _buildSectionTitle(
                screenWidth,
                'PERIOD SUMMARY',
              ),

              SizedBox(
                height: screenHeight * 0.014,
              ),

              _buildSummaryGrid(
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                periodMinutes: periodMinutes,
                sessions: _periodSessions,
                averageReadingMinutes:
                averageReadingMinutes,
                completedBooks: completedBooks,
              ),

              SizedBox(
                height: screenHeight * 0.03,
              ),

              _buildSectionTitle(
                screenWidth,
                'READING TIME',
              ),

              SizedBox(
                height: screenHeight * 0.014,
              ),

              _buildChartCard(
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                data: chartData,
                totalMinutes:
                periodMinutes,
              ),

              SizedBox(
                height: screenHeight * 0.03,
              ),

              _buildSectionTitle(
                screenWidth,
                'INSIGHTS',
              ),

              SizedBox(
                height: screenHeight * 0.014,
              ),

              _buildInsightsCard(
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                longestDay: longestDay,
                mostReadBook: _mostReadBook,
                periodMinutes: periodMinutes,
                previousMinutes: previousMinutes,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(
      double screenWidth,
      double screenHeight,
      ) {
    return Container(
      padding: EdgeInsets.all(
        screenWidth * 0.012,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          _buildPeriodButton(
            screenWidth: screenWidth,
            screenHeight: screenHeight,
            period: ChartStatsPeriod.week,
            label: '주간',
          ),

          _buildPeriodButton(
            screenWidth: screenWidth,
            screenHeight: screenHeight,
            period: ChartStatsPeriod.month,
            label: '월간',
          ),

          _buildPeriodButton(
            screenWidth: screenWidth,
            screenHeight: screenHeight,
            period: ChartStatsPeriod.year,
            label: '연간',
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodButton({
    required double screenWidth,
    required double screenHeight,
    required ChartStatsPeriod period,
    required String label,
  }) {
    final isSelected =
        _selectedPeriod == period;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedPeriod == period) {
            return;
          }

          setState(() {
            _selectedPeriod = period;
          });

          _loadPeriodStats();
        },
        child: AnimatedContainer(
          duration:
          const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            vertical:
            screenHeight * 0.011,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.amberAccent
                : Colors.transparent,
            borderRadius:
            BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFF013328)
                  : Colors.white
                  .withOpacity(0.6),
              fontFamily: 'kopub',
              fontSize:
              screenWidth * 0.029,
              fontWeight: isSelected
                  ? FontWeight.bold
                  : FontWeight.w500,
            ),
          ),
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

  Widget _buildSummaryGrid({
    required double screenWidth,
    required double screenHeight,
    required int periodMinutes,
    required int sessions,
    required int averageReadingMinutes,
    required int completedBooks,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryItem(
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                icon: Icons.schedule_rounded,
                value: _formatMinutes(
                  periodMinutes,
                ),
                label: '총 독서 시간',
              ),
            ),

            SizedBox(
              width: screenWidth * 0.03,
            ),

            Expanded(
              child: _buildSummaryItem(
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                icon: Icons.timelapse_rounded,
                value: _isLoadingPeriodStats
                    ? '-'
                    : _formatMinutes(
                  averageReadingMinutes,
                ),
                label: '평균 독서 시간',
              ),
            ),

          ],
        ),

        SizedBox(
          height: screenWidth * 0.03,
        ),

        Row(
          children: [
            Expanded(
              child: _buildSummaryItem(
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                icon:
                Icons.check_circle,
                value: _isLoadingPeriodStats
                    ? '-'
                    : '$sessions회',
                label: '독서 횟수',
              ),
            ),

            SizedBox(
              width: screenWidth * 0.03,
            ),

            Expanded(
              child: _buildSummaryItem(
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                icon: Icons.menu_book_rounded,
                value: '$completedBooks권',
                label: '완독한 책',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryItem({
    required double screenWidth,
    required double screenHeight,
    required IconData icon,
    required String value,
    required String label,
  }) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.025,
        vertical: screenHeight * 0.021,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.amberAccent,
            size: screenWidth * 0.048,
          ),

          SizedBox(
            height: screenHeight * 0.012,
          ),

          Text(
            value,
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize:
              screenWidth * 0.037,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(
            height: screenHeight * 0.005,
          ),

          Text(
            label,
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white
                  .withOpacity(0.56),
              fontFamily: 'kopub',
              fontSize:
              screenWidth * 0.025,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({
    required double screenWidth,
    required double screenHeight,
    required List<_ChartPoint> data,
    required int totalMinutes,
  }) {
    final maxMinutes =
    data.fold<int>(
      0,
          (maxValue, item) =>
      item.minutes > maxValue
          ? item.minutes
          : maxValue,
    );

    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(
        screenWidth * 0.04,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _getPeriodTitle(),
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'kopub',
                    fontSize:
                    screenWidth * 0.035,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),

              Text(
                _formatMinutes(totalMinutes),
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontFamily: 'kopub',
                  fontSize:
                  screenWidth * 0.031,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ],
          ),

          SizedBox(
            height: screenHeight * 0.026,
          ),

          SizedBox(
            height: screenHeight * 0.19,
            child: Row(
              crossAxisAlignment:
              CrossAxisAlignment.end,
              children: data.map((point) {
                final ratio =
                maxMinutes <= 0
                    ? 0.0
                    : point.minutes /
                    maxMinutes;

                final barHeight =
                    screenHeight *
                        0.125 *
                        ratio;

                return Expanded(
                  child: Padding(
                    padding:
                    EdgeInsets.symmetric(
                      horizontal:
                      screenWidth *
                          0.006,
                    ),
                    child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment.end,
                      children: [
                        if (point.minutes > 0)
                          Text(
                            _formatChartValue(
                              point.minutes,
                            ),
                            maxLines: 1,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style: TextStyle(
                              color: Colors
                                  .white
                                  .withOpacity(
                                0.7,
                              ),
                              fontFamily:
                              'kopub',
                              fontSize:
                              screenWidth *
                                  0.019,
                            ),
                          ),

                        SizedBox(
                          height:
                          screenHeight *
                              0.005,
                        ),

                        AnimatedContainer(
                          duration:
                          const Duration(
                            milliseconds: 220,
                          ),
                          width:
                          screenWidth *
                              0.045,
                          height: point.minutes >
                              0
                              ? barHeight.clamp(
                            screenHeight *
                                0.012,
                            screenHeight *
                                0.125,
                          )
                              : screenHeight *
                              0.006,
                          decoration:
                          BoxDecoration(
                            color: point.minutes >
                                0
                                ? Colors
                                .amberAccent
                                : Colors.white
                                .withOpacity(
                              0.08,
                            ),
                            borderRadius:
                            BorderRadius
                                .circular(
                              8,
                            ),
                          ),
                        ),

                        SizedBox(
                          height:
                          screenHeight *
                              0.009,
                        ),

                        Text(
                          point.label,
                          maxLines: 1,
                          overflow:
                          TextOverflow
                              .ellipsis,
                          style: TextStyle(
                            color: Colors.white
                                .withOpacity(
                              0.8,
                            ),
                            fontFamily:
                            'kopub',
                            fontSize:
                            screenWidth *
                                0.023,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateNavigator({
    required double screenWidth,
    required double screenHeight,
  }) {
    final title = _getNavigatorTitle();

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
          _buildDateNavigatorButton(
            screenWidth: screenWidth,
            icon: Icons.chevron_left_rounded,
            onTap: () {
              switch (_selectedPeriod) {
                case ChartStatsPeriod.week:
                  _changeWeek(-1);
                  break;

                case ChartStatsPeriod.month:
                  _changeMonth(-1);
                  break;

                case ChartStatsPeriod.year:
                  _changeYear(-1);
                  break;
              }
            },
          ),

          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.034,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          _buildDateNavigatorButton(
            screenWidth: screenWidth,
            icon: Icons.chevron_right_rounded,
            enabled: _canMoveForward(),
            onTap: () {
              switch (_selectedPeriod) {
                case ChartStatsPeriod.week:
                  _changeWeek(1);
                  break;

                case ChartStatsPeriod.month:
                  _changeMonth(1);
                  break;

                case ChartStatsPeriod.year:
                  _changeYear(1);
                  break;
              }
            },
          ),
        ],
      ),
    );
  }

  String _getNavigatorTitle() {
    switch (_selectedPeriod) {
      case ChartStatsPeriod.week:
        final weekEnd = _selectedWeekStart.add(
          const Duration(days: 6),
        );

        // 시작일과 종료일의 연도가 같은 경우
        if (_selectedWeekStart.year == weekEnd.year) {
          return '${_selectedWeekStart.year}년 '
              '${_selectedWeekStart.month}월 '
              '${_selectedWeekStart.day}일'
              ' ~ '
              '${weekEnd.month}월 '
              '${weekEnd.day}일';
        }

        // 연도를 넘어가는 주
        return '${_selectedWeekStart.year}년 '
            '${_selectedWeekStart.month}월 '
            '${_selectedWeekStart.day}일'
            ' ~ '
            '${weekEnd.year}년 '
            '${weekEnd.month}월 '
            '${weekEnd.day}일';

      case ChartStatsPeriod.month:
        return '${_selectedMonth.year}년 '
            '${_selectedMonth.month}월';

      case ChartStatsPeriod.year:
        return '$_selectedYear년';
    }
  }

  Widget _buildDateNavigatorButton({
    required double screenWidth,
    required IconData icon,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(
        icon,
        color: enabled
            ? Colors.white
            : Colors.white.withOpacity(0.2),
        size: screenWidth * 0.06,
      ),
    );
  }

  void _changeWeek(int offset) {
    final nextWeekStart =
    _selectedWeekStart.add(
      Duration(days: offset * 7),
    );

    final now = DateTime.now();
    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final currentWeekStart = today.subtract(
      Duration(
        days: today.weekday - DateTime.monday,
      ),
    );

    if (nextWeekStart.isAfter(
      currentWeekStart,
    )) {
      return;
    }

    setState(() {
      _selectedWeekStart = nextWeekStart;
    });

    _loadPeriodStats();
  }

  void _changeMonth(int offset) {
    final nextMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + offset,
      1,
    );

    final currentMonth = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      1,
    );

    if (nextMonth.isAfter(currentMonth)) {
      return;
    }

    setState(() {
      _selectedMonth = nextMonth;
    });

    _loadPeriodStats();
  }

  void _changeYear(int offset) {
    final nextYear =
        _selectedYear + offset;

    if (nextYear > DateTime.now().year) {
      return;
    }

    setState(() {
      _selectedYear = nextYear;
    });

    _loadPeriodStats();
  }

  bool _canMoveForward() {
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case ChartStatsPeriod.week:
        final today = DateTime(
          now.year,
          now.month,
          now.day,
        );

        final currentWeekStart =
        today.subtract(
          Duration(
            days:
            today.weekday - DateTime.monday,
          ),
        );

        final nextWeekStart =
        _selectedWeekStart.add(
          const Duration(days: 7),
        );

        return !nextWeekStart.isAfter(
          currentWeekStart,
        );

      case ChartStatsPeriod.month:
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

      case ChartStatsPeriod.year:
        return _selectedYear < now.year;
    }
  }

  Widget _buildInsightsCard({
    required double screenWidth,
    required double screenHeight,
    required MapEntry<DateTime, int>?
    longestDay,
    required Map<String, dynamic>?
    mostReadBook,
    required int periodMinutes,
    required int previousMinutes,
  }) {
    final mostReadBookTitle =
    (mostReadBook?['title'] ?? '')
        .toString()
        .trim();

    final mostReadBookMinutes =
        (mostReadBook?['minutes'] as num?)
            ?.toInt() ??
            0;

    final difference =
        periodMinutes - previousMinutes;

    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(
        screenWidth * 0.04,
      ),
      child: Column(
        children: [
          _buildInsightRow(
            screenWidth: screenWidth,
            icon: Icons.star_rounded,
            label: '가장 많이 읽은 날',
            value: longestDay == null
                ? '기록 없음'
                : '${longestDay.key.month}월 '
                '${longestDay.key.day}일 / '
                '${_formatMinutes(
              longestDay.value,
            )}',
          ),

          _buildInsightDivider(
            screenHeight,
          ),

          if (_isLoadingPeriodStats)
            _buildInsightRow(
              screenWidth: screenWidth,
              icon: Icons.auto_stories_rounded,
              label: '가장 많이 읽은 책',
              value: '불러오는 중',
            )
          else if (mostReadBook == null ||
              mostReadBookTitle.isEmpty)
            _buildInsightRow(
              screenWidth: screenWidth,
              icon: Icons.auto_stories_rounded,
              label: '가장 많이 읽은 책',
              value: '기록 없음',
            )
          else
            _buildBookInsightRow(
              screenWidth: screenWidth,
              icon: Icons.auto_stories_rounded,
              label: '가장 많이 읽은 책',
              title: mostReadBookTitle,
              minutes: mostReadBookMinutes,
            ),

          _buildInsightDivider(
            screenHeight,
          ),

          _buildComparisonInsightRow(
            screenWidth: screenWidth,
            current: periodMinutes,
            previous: previousMinutes,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow({
    required double screenWidth,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: screenWidth * 0.1,
          height: screenWidth * 0.1,
          decoration: BoxDecoration(
            color: Colors.amberAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.amberAccent,
            size: screenWidth * 0.047,
          ),
        ),

        SizedBox(
          width: screenWidth * 0.03,
        ),

        SizedBox(
          width: screenWidth * 0.29,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.029,
            ),
          ),
        ),

        SizedBox(
          width: screenWidth * 0.02,
        ),

        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.03,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookInsightRow({
    required double screenWidth,
    required IconData icon,
    required String label,
    required String title,
    required int minutes,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: screenWidth * 0.1,
          height: screenWidth * 0.1,
          decoration: BoxDecoration(
            color: Colors.amberAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.amberAccent,
            size: screenWidth * 0.047,
          ),
        ),

        SizedBox(
          width: screenWidth * 0.03,
        ),

        SizedBox(
          width: screenWidth * 0.29,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.029,
            ),
          ),
        ),

        SizedBox(
          width: screenWidth * 0.02,
        ),

        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'kopub',
                    fontSize: screenWidth * 0.03,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              SizedBox(
                width: screenWidth * 0.012,
              ),

              Text(
                '/ ${_formatMinutes(minutes)}',
                maxLines: 1,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.03,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonInsightRow({
    required double screenWidth,
    required int current,
    required int previous,
  }) {
    final difference = current - previous;

    final trendIcon = difference > 0
        ? Icons.trending_up_rounded
        : difference < 0
        ? Icons.trending_down_rounded
        : Icons.remove_rounded;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: screenWidth * 0.1,
          height: screenWidth * 0.1,
          decoration: BoxDecoration(
            color: Colors.amberAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.compare_arrows_rounded,
            color: Colors.amberAccent,
            size: screenWidth * 0.047,
          ),
        ),

        SizedBox(
          width: screenWidth * 0.03,
        ),

        SizedBox(
          width: screenWidth * 0.29,
          child: Text(
            '이전 기간 비교',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.029,
            ),
          ),
        ),

        SizedBox(
          width: screenWidth * 0.02,
        ),

        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  _buildComparisonText(
                    current,
                    previous,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'kopub',
                    fontSize: screenWidth * 0.03,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              SizedBox(
                width: screenWidth * 0.012,
              ),

              Icon(
                trendIcon,
                color: Colors.amberAccent,
                size: screenWidth * 0.046,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightDivider(
      double screenHeight,
      ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: screenHeight * 0.014,
      ),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Colors.white.withOpacity(0.08),
      ),
    );
  }

  Future<void> _loadPeriodStats() async {
    final range = _getSelectedRange(
      DateTime.now(),
    );

    setState(() {
      _isLoadingPeriodStats = true;
    });

    try {
      final results = await Future.wait([
        ReadingLogService
            .getReadingSessionsByRange(
          start: range.start,
          end: range.end,
        ),
        ReadingLogService
            .getMostReadBookByRange(
          start: range.start,
          end: range.end,
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _periodSessions =
        results[0] as int;

        _mostReadBook =
        results[1]
        as Map<String, dynamic>?;
      });
    } catch (e) {
      debugPrint(
        '[ChartStatsScreen] '
            '기간 통계 로드 실패: $e',
      );

      if (!mounted) return;

      setState(() {
        _periodSessions = 0;
        _mostReadBook = null;
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoadingPeriodStats = false;
      });
    }
  }

  DateTimeRange _getSelectedRange(
      DateTime now,
      ) {
    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    switch (_selectedPeriod) {
      case ChartStatsPeriod.week:
        return DateTimeRange(
          start: _selectedWeekStart,
          end: _selectedWeekStart.add(
            const Duration(days: 7),
          ),
        );

      case ChartStatsPeriod.month:
        return DateTimeRange(
          start: DateTime(
            _selectedMonth.year,
            _selectedMonth.month,
            1,
          ),
          end: DateTime(
            _selectedMonth.year,
            _selectedMonth.month + 1,
            1,
          ),
        );

      case ChartStatsPeriod.year:
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

  DateTimeRange _getPreviousRange(
      DateTimeRange current,
      ) {
    switch (_selectedPeriod) {
      case ChartStatsPeriod.week:
        return DateTimeRange(
          start: current.start.subtract(
            const Duration(days: 7),
          ),
          end: current.start,
        );

      case ChartStatsPeriod.month:
        return DateTimeRange(
          start: DateTime(
            _selectedMonth.year,
            _selectedMonth.month - 1,
            1,
          ),
          end: DateTime(
            _selectedMonth.year,
            _selectedMonth.month,
            1,
          ),
        );

      case ChartStatsPeriod.year:
        return DateTimeRange(
          start: DateTime(
            _selectedYear - 1,
            1,
            1,
          ),
          end: DateTime(
            _selectedYear,
            1,
            1,
          ),
        );
    }
  }

  int _sumMinutesByRange({
    required Map<String, int>
    dailyMinutes,
    required DateTime start,
    required DateTime end,
  }) {
    int total = 0;

    for (final entry
    in dailyMinutes.entries) {
      final date =
      DateTime.tryParse(entry.key);

      if (date == null) continue;

      if (!date.isBefore(start) &&
          date.isBefore(end)) {
        total += entry.value;
      }
    }

    return total;
  }

  MapEntry<DateTime, int>?
  _findLongestReadingDay({
    required Map<String, int>
    dailyMinutes,
    required DateTime start,
    required DateTime end,
  }) {
    MapEntry<DateTime, int>? result;

    for (final entry
    in dailyMinutes.entries) {
      final date =
      DateTime.tryParse(entry.key);

      if (date == null ||
          date.isBefore(start) ||
          !date.isBefore(end)) {
        continue;
      }

      if (result == null ||
          entry.value > result.value) {
        result = MapEntry(
          date,
          entry.value,
        );
      }
    }

    return result;
  }

  List<_ChartPoint> _createChartData({
    required Map<String, int> dailyMinutes,
    required DateTimeRange range,
  }) {
    switch (_selectedPeriod) {
      case ChartStatsPeriod.week:
        return List.generate(7, (index) {
          final date = range.start.add(
            Duration(days: index),
          );

          return _ChartPoint(
            label: _weekdayLabel(
              date.weekday,
            ),
            minutes:
            dailyMinutes[
            _formatDateKey(date)] ??
                0,
          );
        });

      case ChartStatsPeriod.month:
        return _createMonthlyChartData(
          dailyMinutes: dailyMinutes,
          range: range,
        );

      case ChartStatsPeriod.year:
        return List.generate(12, (index) {
          final month = index + 1;

          return _ChartPoint(
            label: '$month월',
            minutes: _sumMonthMinutes(
              dailyMinutes,
              range.start.year,
              month,
            ),
          );
        });
    }
  }

  List<_ChartPoint> _createMonthlyChartData({
    required Map<String, int> dailyMinutes,
    required DateTimeRange range,
  }) {
    final daysInMonth = range.end
        .subtract(
      const Duration(days: 1),
    )
        .day;

    final points = <_ChartPoint>[];

    int startDay = 1;
    int weekNumber = 1;

    while (startDay <= daysInMonth) {
      final endDay =
      (startDay + 6).clamp(
        1,
        daysInMonth,
      );

      int minutes = 0;

      for (int day = startDay;
      day <= endDay;
      day++) {
        final date = DateTime(
          range.start.year,
          range.start.month,
          day,
        );

        minutes +=
            dailyMinutes[
            _formatDateKey(date)] ??
                0;
      }

      points.add(
        _ChartPoint(
          label: '$weekNumber주',
          minutes: minutes,
        ),
      );

      startDay += 7;
      weekNumber++;
    }

    return points;
  }

  int _sumMonthMinutes(
      Map<String, int> dailyMinutes,
      int year,
      int month,
      ) {
    int total = 0;

    for (final entry
    in dailyMinutes.entries) {
      final date =
      DateTime.tryParse(entry.key);

      if (date != null &&
          date.year == year &&
          date.month == month) {
        total += entry.value;
      }
    }

    return total;
  }

  String _getPeriodTitle() {
    switch (_selectedPeriod) {
      case ChartStatsPeriod.week:
        return '요일별 기록';

      case ChartStatsPeriod.month:
        return '주차별 기록';

      case ChartStatsPeriod.year:
        return '월별 기록';
    }
  }

  String _buildComparisonText(
      int current,
      int previous,
      ) {
    final difference = current - previous;

    if (difference == 0) {
      return '변화 없음';
    }

    return _formatMinutes(
      difference.abs(),
    );
  }

  String _formatChartValue(
      int minutes,
      ) {
    if (minutes < 60) {
      return '$minutes';
    }

    final hours = minutes / 60;

    if (hours >= 10) {
      return '${hours.round()}h';
    }

    return '${hours.toStringAsFixed(1)}h';
  }

  String _weekdayLabel(int weekday) {
    const labels = [
      '월',
      '화',
      '수',
      '목',
      '금',
      '토',
      '일',
    ];

    return labels[weekday - 1];
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatMinutes(
      int totalMinutes,
      ) {
    if (totalMinutes <= 0) {
      return '0분';
    }

    if (totalMinutes < 60) {
      return '$totalMinutes분';
    }

    final hours =
        totalMinutes ~/ 60;

    final minutes =
        totalMinutes % 60;

    if (minutes == 0) {
      return '$hours시간';
    }

    return '$hours시간 $minutes분';
  }

}

class _ChartPoint {
  final String label;
  final int minutes;

  const _ChartPoint({
    required this.label,
    required this.minutes,
  });
}
