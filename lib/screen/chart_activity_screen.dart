import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/provider/reading_stats_provider.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/service/reading_log_service.dart';
import 'package:dayverse_book/widget/card_box.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:dayverse_book/model/memo_model.dart';
import 'package:dayverse_book/screen/memo_edit_screen.dart';

class ChartActivityScreen extends StatefulWidget {
  const ChartActivityScreen({super.key});

  @override
  State<ChartActivityScreen> createState() =>
      _ChartActivityScreenState();
}

class _ChartActivityScreenState
    extends State<ChartActivityScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  bool _showAllRecords = false;

  late Future<List<Map<String, dynamic>>>
  _selectedDayLogsFuture;

  @override
  void initState() {
    super.initState();

    _selectedDayLogsFuture =
        ReadingLogService.getTimerLogsForDate(
          _selectedDay,
        );
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

    final allMemos =
        savedBooksProvider.allMemos;

    final dailyReadingMinutes =
        readingStatsProvider.dailyReadingMinutes;

    final currentStreak =
        readingStatsProvider.weeklySummary.streakDays;

    final monthMemoCount =
    _calculateMonthMemoCount(
      memos: allMemos,
      focusedMonth: _focusedDay,
    );

    final monthReadingDays =
    _calculateMonthReadingDays(
      dailyReadingMinutes: dailyReadingMinutes,
      focusedMonth: _focusedDay,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF013328),
      appBar: AppBar(
        backgroundColor: const Color(0xFF013328),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '독서 활동',
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
        backgroundColor: const Color(0xFF16483F),
        onRefresh: () async {
          await readingStatsProvider.refresh();

          if (!mounted) return;

          setState(() {
            _selectedDayLogsFuture =
                ReadingLogService
                    .getTimerLogsForDate(
                  _selectedDay,
                );
          });
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
              _buildSectionTitle(
                screenWidth,
                'ACTIVITY OVERVIEW',
              ),

              SizedBox(
                height: screenHeight * 0.014,
              ),

              _buildActivityOverviewCard(
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                currentStreak: currentStreak,
                monthReadingDays: monthReadingDays,
                monthMemoCount: monthMemoCount,
              ),

              SizedBox(
                height: screenHeight * 0.03,
              ),

              _buildSectionTitle(
                screenWidth,
                'READING CALENDAR',
              ),

              SizedBox(
                height: screenHeight * 0.014,
              ),

              _buildCalendarCard(
                context: context,
                screenWidth: screenWidth,
                dailyReadingMinutes:
                dailyReadingMinutes,
                memos: allMemos,
              ),

              SizedBox(
                height: screenHeight * 0.03,
              ),

              _buildSelectedDaySection(
                context: context,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                dailyReadingMinutes:
                dailyReadingMinutes,
                memos: allMemos,
              ),
            ],
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

  Widget _buildActivityOverviewCard({
    required double screenWidth,
    required double screenHeight,
    required int currentStreak,
    required int monthReadingDays,
    required int monthMemoCount,
  }) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.025,
        vertical: screenHeight * 0.022,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildActivityOverviewItem(
              screenWidth: screenWidth,
              icon:
              Icons.local_fire_department_rounded,
              value: '$currentStreak일',
              label: '현재 연속',
            ),
          ),

          _buildVerticalDivider(screenHeight),

          Expanded(
            child: _buildActivityOverviewItem(
              screenWidth: screenWidth,
              icon: Icons.check_circle,
              value: '$monthReadingDays일',
              label: '${_focusedDay.month}월 독서',
            ),
          ),

          _buildVerticalDivider(screenHeight),

          Expanded(
            child: _buildActivityOverviewItem(
              screenWidth: screenWidth,
              icon: Icons.edit_note_rounded,
              value: '$monthMemoCount개',
              label: '${_focusedDay.month}월 메모',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityOverviewItem({
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
          size: screenWidth * 0.048,
        ),

        SizedBox(
          height: screenWidth * 0.014,
        ),

        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'kopub',
            fontSize: screenWidth * 0.038,
            fontWeight: FontWeight.bold,
          ),
        ),

        SizedBox(
          height: screenWidth * 0.007,
        ),

        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.58),
            fontFamily: 'kopub',
            fontSize: screenWidth * 0.025,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider(
      double screenHeight,
      ) {
    return Container(
      width: 1,
      height: screenHeight * 0.065,
      color: Colors.white.withOpacity(0.1),
    );
  }

  Widget _buildCalendarCard({
    required BuildContext context,
    required double screenWidth,
    required Map<String, int>
    dailyReadingMinutes,
    required List<MemoModel> memos,
  }) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.fromLTRB(
        screenWidth * 0.025,
        screenWidth * 0.018,
        screenWidth * 0.025,
        screenWidth * 0.025,
      ),
      child: TableCalendar<int>(
        locale: 'ko_KR',
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2035, 12, 31),
        focusedDay: _focusedDay,

        selectedDayPredicate: (day) {
          return isSameDay(
            _selectedDay,
            day,
          );
        },

        onDaySelected: (
            selectedDay,
            focusedDay,
            ) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
            _showAllRecords = false;

            _selectedDayLogsFuture =
                ReadingLogService
                    .getTimerLogsForDate(
                  selectedDay,
                );
          });
        },

        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
          });
        },

        startingDayOfWeek:
        StartingDayOfWeek.monday,

        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          headerPadding: EdgeInsets.symmetric(
            vertical: screenWidth * 0.025,
          ),
          titleTextFormatter: (
              date,
              locale,
              ) {
            return '${date.year}년 ${date.month}월';
          },
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontFamily: 'kopub',
            fontSize: screenWidth * 0.037,
            fontWeight: FontWeight.bold,
          ),
          leftChevronIcon: Icon(
            Icons.chevron_left_rounded,
            color: Colors.white,
            size: screenWidth * 0.06,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right_rounded,
            color: Colors.white,
            size: screenWidth * 0.06,
          ),
        ),

        daysOfWeekHeight:
        screenWidth * 0.09,

        rowHeight:
        screenWidth * 0.13,

        daysOfWeekStyle:
        DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: Colors.white
                .withOpacity(0.62),
            fontFamily: 'kopub',
            fontSize:
            screenWidth * 0.027,
          ),
          weekendStyle: TextStyle(
            color: Colors.white
                .withOpacity(0.62),
            fontFamily: 'kopub',
            fontSize:
            screenWidth * 0.027,
          ),
        ),

        calendarStyle:
        const CalendarStyle(
          outsideDaysVisible: true,
        ),

        calendarBuilders:
        CalendarBuilders<int>(
          defaultBuilder: (
              context,
              day,
              focusedDay,
              ) {
            return _buildActivityCalendarCell(
              screenWidth: screenWidth,
              day: day,
              dailyReadingMinutes:
              dailyReadingMinutes,
              memos: memos,
              isOutsideMonth: false,
            );
          },

          todayBuilder: (
              context,
              day,
              focusedDay,
              ) {
            return _buildActivityCalendarCell(
              screenWidth: screenWidth,
              day: day,
              dailyReadingMinutes:
              dailyReadingMinutes,
              memos: memos,
              isToday: true,
              isOutsideMonth: false,
            );
          },

          selectedBuilder: (
              context,
              day,
              focusedDay,
              ) {
            return _buildActivityCalendarCell(
              screenWidth: screenWidth,
              day: day,
              dailyReadingMinutes:
              dailyReadingMinutes,
              memos: memos,
              isSelected: true,
              isToday:
              isSameDay(day, DateTime.now()),
              isOutsideMonth: false,
            );
          },

          outsideBuilder: (
              context,
              day,
              focusedDay,
              ) {
            return _buildActivityCalendarCell(
              screenWidth: screenWidth,
              day: day,
              dailyReadingMinutes:
              dailyReadingMinutes,
              memos: memos,
              isOutsideMonth: true,
            );
          },
        ),
      ),
    );
  }

  Widget _buildActivityCalendarCell({
    required double screenWidth,
    required DateTime day,
    required Map<String, int>
    dailyReadingMinutes,
    required List<MemoModel> memos,
    bool isSelected = false,
    bool isToday = false,
    bool isOutsideMonth = false,
  }) {
    final dateKey = _formatDateKey(day);

    final hasRead =
        (dailyReadingMinutes[dateKey] ?? 0) > 0;

    final hasMemo = memos.any(
          (memo) => _isSameDate(
        memo.createdAt,
        day,
      ),
    );

    final circleSize =
        screenWidth * 0.071;

    return Center(
      child: Opacity(
        opacity: isOutsideMonth ? 0.25 : 1,
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: circleSize,
                  height: circleSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hasRead
                        ? Colors.amberAccent
                        : Colors.white
                        .withOpacity(0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : isToday
                          ? Colors.amberAccent
                          : Colors.white
                          .withOpacity(0.15),
                      width: isSelected
                          ? 2
                          : isToday
                          ? 1.5
                          : 1,
                    ),
                  ),
                  child: hasRead
                      ? Icon(
                    Icons.check_rounded,
                    color: const Color(
                      0xFF013328,
                    ),
                    size:
                    screenWidth * 0.038,
                  )
                      : Text(
                    '${day.day}',
                    style: TextStyle(
                      color: isToday
                          ? Colors.amberAccent
                          : Colors.white
                          .withOpacity(0.72),
                      fontFamily: 'kopub',
                      fontSize:
                      screenWidth * 0.026,
                      fontWeight: isToday
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),

                if (hasMemo)
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      width:
                      screenWidth * 0.033,
                      height:
                      screenWidth * 0.033,
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFF16483F,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.amberAccent,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        color: Colors.amberAccent,
                        size:
                        screenWidth * 0.019,
                      ),
                    ),
                  ),
              ],
            ),

            SizedBox(
              height: screenWidth * 0.008,
            ),

            if (hasRead)
              Text(
                '${day.day}',
                style: TextStyle(
                  color: Colors.white
                      .withOpacity(0.68),
                  fontFamily: 'kopub',
                  fontSize:
                  screenWidth * 0.022,
                ),
              )
            else
              SizedBox(
                height: screenWidth * 0.022,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDaySection({
    required BuildContext context,
    required double screenWidth,
    required double screenHeight,
    required Map<String, int>
    dailyReadingMinutes,
    required List<MemoModel> memos,
  }) {

    final selectedMemos = memos
        .where(
          (memo) => _isSameDate(
        memo.createdAt,
        _selectedDay,
      ),
    )
        .toList();

    selectedMemos.sort(
          (a, b) =>
          b.createdAt.compareTo(a.createdAt),
    );
    final selectedDateText =
        '${_selectedDay.month}월 ${_selectedDay.day}일 활동';

    final totalMinutes =
        dailyReadingMinutes[
        _formatDateKey(
          _selectedDay,
        )] ??
            0;

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSectionTitle(
                screenWidth,
                'READING LOG',
              ),
            ),

            _buildActivityChip(
              screenWidth: screenWidth,
              screenHeight: screenHeight,
              icon: Icons.schedule_rounded,
              text: _formatMinutes(totalMinutes),
            ),
          ],
        ),

        SizedBox(
          height: screenHeight * 0.014,
        ),

        FutureBuilder<
            List<Map<String, dynamic>>>(
          future: _selectedDayLogsFuture,
          builder: (
              context,
              snapshot,
              ) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return CardBox(
                margin: EdgeInsets.zero,
                padding: EdgeInsets.all(
                  screenWidth * 0.08,
                ),
                child: const Center(
                  child:
                  CircularProgressIndicator(
                    color: Colors.amberAccent,
                    strokeWidth: 2.5,
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return _buildEmptyRecordCard(
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                icon:
                Icons.error_outline_rounded,
                title:
                '독서 기록을 불러오지 못했어요',
                description:
                '잠시 후 다시 확인해주세요.',
              );
            }

            final records =
                snapshot.data ?? [];

            if (records.isEmpty) {
              return _buildEmptyRecordCard(
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                icon: Icons
                    .menu_book_outlined,
                title:
                '이날의 독서 기록이 없어요',
                description:
                '독서 타이머를 사용하면 기록이 자동으로 저장돼요.',
              );
            }

            final groupedRecords =
            _groupRecordsByBook(records);

            final allRecords =
            groupedRecords.values
                .toList();

            final visibleRecords =
            _showAllRecords
                ? allRecords
                : allRecords
                .take(3)
                .toList();

            final hasMore =
                allRecords.length > 3;

            return Column(
              children: [
                ...visibleRecords.map(
                      (record) {
                    return _buildBookRecordCard(
                      context: context,
                      screenWidth:
                      screenWidth,
                      screenHeight:
                      screenHeight,
                      title:
                      record['title']
                          ?.toString() ??
                          '',
                      minutes:
                      (record[
                      'durationMinutes']
                      as num?)
                          ?.toInt() ??
                          0,
                    );
                  },
                ),

                if (hasMore)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showAllRecords =
                        !_showAllRecords;
                      });
                    },
                    child: Padding(
                      padding:
                      EdgeInsets.symmetric(
                        vertical:
                        screenHeight * 0.012,
                      ),
                      child: Row(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                        children: [
                          Text(
                            _showAllRecords
                                ? '접기'
                                : '기록 더보기',
                            style: TextStyle(
                              color: Colors.white
                                  .withOpacity(
                                0.65,
                              ),
                              fontFamily:
                              'kopub',
                              fontSize:
                              screenWidth *
                                  0.029,
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),

                          SizedBox(
                            width:
                            screenWidth *
                                0.008,
                          ),

                          Icon(
                            _showAllRecords
                                ? Icons
                                .keyboard_arrow_up_rounded
                                : Icons
                                .keyboard_arrow_down_rounded,
                            color: Colors.white
                                .withOpacity(0.65),
                            size:
                            screenWidth *
                                0.05,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        SizedBox(
          height: screenHeight * 0.025,
        ),

        _buildSelectedDayMemoSection(
          context: context,
          screenWidth: screenWidth,
          screenHeight: screenHeight,
          memos: selectedMemos,
        ),
      ],
    );
  }

  Widget _buildActivityChip({
    required double screenWidth,
    required double screenHeight,
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal:
        screenWidth * 0.022,
        vertical:
        screenHeight * 0.006,
      ),
      decoration: BoxDecoration(
        color:
        Colors.amberAccent.withOpacity(0.1),
        borderRadius:
        BorderRadius.circular(999),
        border: Border.all(
          color: Colors.amberAccent
              .withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.amberAccent,
            size: screenWidth * 0.032,
          ),

          SizedBox(
            width: screenWidth * 0.009,
          ),

          Text(
            text,
            style: TextStyle(
              color: Colors.amberAccent,
              fontFamily: 'kopub',
              fontSize:
              screenWidth * 0.025,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookRecordCard({
    required BuildContext context,
    required double screenWidth,
    required double screenHeight,
    required String title,
    required int minutes,
  }) {
    final savedBooksProvider =
    context.read<SavedBooksProvider>();

    final savedBooks =
        savedBooksProvider.savedBooks;

    BookModel? matchedBook;

    for (final book in savedBooks) {
      if (book.title.trim() ==
          title.trim()) {
        matchedBook = book;
        break;
      }
    }

    final author =
    matchedBook?.author.trim().isNotEmpty ==
        true
        ? matchedBook!.author
        : '작자 미상';

    final imageUrl =
        matchedBook?.imageUrl;

    final imageWidth =
        screenWidth * 0.14;

    final imageHeight =
        imageWidth * 1.4;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(
        bottom: screenHeight * 0.014,
      ),
      padding: EdgeInsets.all(
        screenWidth * 0.035,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF16483F),
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color:
          Colors.white.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // =================================================
          // 1. 책 표지
          // =================================================

          Container(
            decoration: BoxDecoration(
              borderRadius:
              BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withOpacity(0.25),
                  blurRadius: 8,
                  offset:
                  const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius:
              BorderRadius.circular(8),
              child: imageUrl
                  ?.trim()
                  .isNotEmpty ==
                  true
                  ? Image.network(
                imageUrl!,
                width: imageWidth,
                height: imageHeight,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) {
                  return _buildBookPlaceholder(
                    imageWidth,
                    imageHeight,
                  );
                },
              )
                  : _buildBookPlaceholder(
                imageWidth,
                imageHeight,
              ),
            ),
          ),

          SizedBox(
            width: screenWidth * 0.035,
          ),

          // =================================================
          // 2. 책 제목 + 저자
          // =================================================

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                Text(
                  title.isNotEmpty
                      ? title
                      : '도서 정보 없음',
                  maxLines: 2,
                  overflow:
                  TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'kopub',
                    fontSize:
                    screenWidth * 0.035,
                    fontWeight:
                    FontWeight.bold,
                    height: 1.3,
                  ),
                ),

                SizedBox(
                  height:
                  screenHeight * 0.007,
                ),

                Text(
                  author,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white
                        .withOpacity(0.55),
                    fontFamily: 'kopub',
                    fontSize:
                    screenWidth * 0.029,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            width: screenWidth * 0.025,
          ),

          // =================================================
          // 3. 읽은 시간
          // =================================================

          Container(
            padding: EdgeInsets.symmetric(
              horizontal:
              screenWidth * 0.022,
              vertical:
              screenHeight * 0.007,
            ),
            decoration: BoxDecoration(
              color: Colors.amberAccent
                  .withOpacity(0.1),
              borderRadius:
              BorderRadius.circular(999),
              border: Border.all(
                color: Colors.amberAccent
                    .withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  color:
                  Colors.amberAccent,
                  size:
                  screenWidth * 0.034,
                ),

                SizedBox(
                  width:
                  screenWidth * 0.009,
                ),

                Text(
                  _formatMinutes(minutes),
                  style: TextStyle(
                    color:
                    Colors.amberAccent,
                    fontFamily: 'kopub',
                    fontSize:
                    screenWidth * 0.027,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRecordCard({
    required double screenWidth,
    required double screenHeight,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(
        screenWidth * 0.04,
      ),
      child: Row(
        children: [
          Container(
            width: screenWidth * 0.14,
            height: screenWidth * 0.14,
            decoration: BoxDecoration(
              color:
              Colors.white.withOpacity(0.07),
              borderRadius:
              BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: Colors.white
                  .withOpacity(0.42),
              size: screenWidth * 0.065,
            ),
          ),

          SizedBox(
            width: screenWidth * 0.035,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'kopub',
                    fontSize:
                    screenWidth * 0.034,
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
                  style: TextStyle(
                    color: Colors.white
                        .withOpacity(0.52),
                    fontFamily: 'kopub',
                    fontSize:
                    screenWidth * 0.028,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookPlaceholder(
      double width,
      double height,
      ) {
    return Container(
      width: width,
      height: height,
      color: Colors.white.withOpacity(0.08),
      child: Icon(
        Icons.book_rounded,
        color:
        Colors.white.withOpacity(0.35),
      ),
    );
  }

  Map<String, Map<String, dynamic>>
  _groupRecordsByBook(
      List<Map<String, dynamic>> records,
      ) {
    final Map<String, Map<String, dynamic>>
    groupedRecords = {};

    for (final record in records) {
      final title =
          record['title']?.toString().trim() ??
              '';

      final duration =
          (record['durationMinutes'] as num?)
              ?.toInt() ??
              0;

      final key =
      title.isEmpty ? '도서 정보 없음' : title;

      if (!groupedRecords.containsKey(key)) {
        groupedRecords[key] = {
          'title': key,
          'durationMinutes': 0,
        };
      }

      groupedRecords[key]![
      'durationMinutes'] =
          (groupedRecords[key]![
          'durationMinutes']
          as int) +
              duration;
    }

    return groupedRecords;
  }

  int _calculateMonthReadingDays({
    required Map<String, int>
    dailyReadingMinutes,
    required DateTime focusedMonth,
  }) {
    int readingDays = 0;

    for (final entry
    in dailyReadingMinutes.entries) {
      final date =
      DateTime.tryParse(entry.key);

      if (date == null ||
          entry.value <= 0) {
        continue;
      }

      if (date.year ==
          focusedMonth.year &&
          date.month ==
              focusedMonth.month) {
        readingDays++;
      }
    }

    return readingDays;
  }

  int _calculateLongestStreak(
      Map<String, int> dailyReadingMinutes,
      ) {
    final readingDates =
    dailyReadingMinutes.entries
        .where(
          (entry) => entry.value > 0,
    )
        .map(
          (entry) =>
          DateTime.tryParse(entry.key),
    )
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

    for (int i = 1;
    i < readingDates.length;
    i++) {
      final difference =
          readingDates[i]
              .difference(
            readingDates[i - 1],
          )
              .inDays;

      if (difference == 1) {
        currentStreak++;
      } else {
        currentStreak = 1;
      }

      if (currentStreak >
          longestStreak) {
        longestStreak =
            currentStreak;
      }
    }

    return longestStreak;
  }

  String _formatDateKey(
      DateTime date,
      ) {
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

  Widget _buildSelectedDayMemoSection({
    required BuildContext context,
    required double screenWidth,
    required double screenHeight,
    required List<MemoModel> memos,
  }) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSectionTitle(
                screenWidth,
                'MEMOS',
              ),
            ),

            _buildActivityChip(
              screenWidth: screenWidth,
              screenHeight: screenHeight,
              icon: Icons.edit_note_rounded,
              text: '메모 ${memos.length}개',
            ),
          ],
        ),

        SizedBox(
          height: screenHeight * 0.014,
        ),

        if (memos.isEmpty)
          _buildEmptyRecordCard(
            screenWidth: screenWidth,
            screenHeight: screenHeight,
            icon: Icons.edit_note_rounded,
            title: '이날 남긴 메모가 없어요',
            description:
            '책을 읽으며 떠오른 생각을 기록해보세요.',
          )
        else
          ...memos.map(
                (memo) => _buildMemoCard(
              context: context,
              screenWidth: screenWidth,
              screenHeight: screenHeight,
              memo: memo,
            ),
          ),
      ],
    );
  }

  Widget _buildMemoCard({
    required BuildContext context,
    required double screenWidth,
    required double screenHeight,
    required MemoModel memo,
  }) {
    final savedBooksProvider =
    context.read<SavedBooksProvider>();

    final book =
    savedBooksProvider.getBookByIdOrNull(
      memo.bookId,
    );

    final imageWidth =
        screenWidth * 0.14;

    final imageHeight =
        imageWidth * 1.4;

    return GestureDetector(
      onTap: book == null
          ? null
          : () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                MemoEditScreen(
                  book: book,
                  memo: memo,
                ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(
          bottom: screenHeight * 0.014,
        ),
        padding: EdgeInsets.all(
          screenWidth * 0.035,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF16483F),
          borderRadius:
          BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white
                .withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius:
              BorderRadius.circular(8),
              child: book?.imageUrl
                  ?.trim()
                  .isNotEmpty ==
                  true
                  ? Image.network(
                book!.imageUrl!,
                width: imageWidth,
                height: imageHeight,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) {
                  return _buildBookPlaceholder(
                    imageWidth,
                    imageHeight,
                  );
                },
              )
                  : _buildBookPlaceholder(
                imageWidth,
                imageHeight,
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
                    book?.title ??
                        '도서 정보 없음',
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'kopub',
                      fontSize:
                      screenWidth * 0.034,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  SizedBox(
                    height:
                    screenHeight * 0.007,
                  ),

                  Text(
                    memo.content.trim().isEmpty
                        ? '이미지 메모'
                        : memo.content.trim(),
                    maxLines: 3,
                    overflow:
                    TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white
                          .withOpacity(0.64),
                      fontFamily: 'kopub',
                      fontSize:
                      screenWidth * 0.029,
                      height: 1.4,
                    ),
                  ),

                  if (memo.hasImages) ...[
                    SizedBox(
                      height:
                      screenHeight * 0.009,
                    ),

                    Row(
                      children: [
                        Icon(
                          Icons.image_rounded,
                          color:
                          Colors.amberAccent,
                          size:
                          screenWidth * 0.034,
                        ),

                        SizedBox(
                          width:
                          screenWidth * 0.008,
                        ),

                        Text(
                          '이미지 ${memo.imageUrls.length}장',
                          style: TextStyle(
                            color: Colors
                                .amberAccent,
                            fontFamily:
                            'kopub',
                            fontSize:
                            screenWidth *
                                0.025,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            if (book != null)
              Icon(
                Icons
                    .arrow_forward_ios_rounded,
                color: Colors.white
                    .withOpacity(0.55),
                size: screenWidth * 0.035,
              ),
          ],
        ),
      ),
    );
  }

  bool _isSameDate(
      DateTime first,
      DateTime second,
      ) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  int _calculateMonthMemoCount({
    required List<MemoModel> memos,
    required DateTime focusedMonth,
  }) {
    return memos.where((memo) {
      return memo.createdAt.year ==
          focusedMonth.year &&
          memo.createdAt.month ==
              focusedMonth.month;
    }).length;
  }

}
