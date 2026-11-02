import 'package:flutter/material.dart';

import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/challenge_attempt_model.dart';
import 'package:dayverse_book/utils/challenge_check_utils.dart';
import 'package:dayverse_book/utils/challenge_progress_utils.dart';
import 'package:dayverse_book/widget/card_box.dart';

class StageCalendar extends StatefulWidget {
  final Challenge challenge;
  final dynamic recordDataOrBooks;
  final bool isDoneMode;

  const StageCalendar({
    super.key,
    required this.challenge,
    required this.recordDataOrBooks,
    this.isDoneMode = false,
  });

  @override
  State<StageCalendar> createState() =>
      _StageCalendarState();
}

class _StageCalendarState
    extends State<StageCalendar> {
  late DateTime currentMonth;

  @override
  void initState() {
    super.initState();

    currentMonth =
        DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width;

    final startOfMonth =
    DateTime(
      currentMonth.year,
      currentMonth.month,
      1,
    );

    final checkType =
    getChallengeCheckActionType(
      widget.challenge,
    );

    final requiredMinutes =
        widget.challenge.requiredMinutes ?? 0;

    final calendarCellSize =
        screenWidth * 0.10;

    final calendarMargin =
        screenWidth * 0.008;

    // =========================================================
    // ⚠️ 아래 attempt 관련 로직은 기존 그대로 유지
    //
    // 달력에는 다음 기록만 표시
    // 1. 성공 완료된 스테이지
    // 2. 현재 실제로 진행 중인 최신 스테이지
    //
    // 실패·포기한 attempt와 과거 재도전 기록은
    // 달력에서 제외한다.
    // =========================================================

    final attempts =
        widget.challenge.attempts;

    // 현재 진행 중인 attempt는 반드시 마지막 attempt이며,
    // 챌린지가 실제 참여 중이고 완료되지 않은 경우만 인정한다.
    final ChallengeAttempt?
    activeAttempt =
    widget.challenge.isJoined &&
        attempts.isNotEmpty &&
        !attempts.last.completed
        ? attempts.last
        : null;

    // 스테이지별 표시할 attempt를 하나만 보관한다.
    final Map<int, ChallengeAttempt>
    visibleAttemptsByStage = {};

    // 성공 완료된 스테이지 기록
    for (final attempt in attempts) {
      final stageIndex =
          attempt.stageIndex;

      if (stageIndex == null) {
        continue;
      }

      if (attempt.completed &&
          attempt.isSuccessful) {
        visibleAttemptsByStage[
        stageIndex] = attempt;
      }
    }

    // 현재 진행 중인 최신 스테이지
    if (activeAttempt?.stageIndex !=
        null) {
      visibleAttemptsByStage[
      activeAttempt!
          .stageIndex!] =
          activeAttempt;
    }

    // 스테이지 순서대로 정렬
    final visibleAttempts =
    visibleAttemptsByStage.entries
        .toList()
      ..sort(
            (a, b) =>
            a.key.compareTo(b.key),
      );

    final stageData =
    visibleAttempts.map(
          (entry) {
        final stageIndex =
            entry.key;

        final attempt =
            entry.value;

        final start =
        DateTime(
          attempt.startDate.year,
          attempt.startDate.month,
          attempt.startDate.day,
        );

        final duration =
            attempt.selectedDuration ??
                0;

        final end =
        duration > 0
            ? start.add(
          Duration(
            days:
            duration - 1,
          ),
        )
            : start;

        return <String, dynamic>{
          'stageIndex':
          stageIndex,
          'start':
          start,
          'end':
          end,
          'color':
          _stageColor(
            stageIndex,
          ),
          'attempt':
          attempt,
        };
      },
    ).toList();

    // =========================================================
    // UI
    // =========================================================

    return CardBox(
      margin:
      EdgeInsets.zero,
      padding:
      EdgeInsets.all(
        screenWidth * 0.035,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          // ===================================================
          // 안내
          // ===================================================

          Row(
            children: [
              Container(
                width:
                screenWidth * 0.075,
                height:
                screenWidth * 0.075,
                decoration:
                BoxDecoration(
                  color: Colors.amberAccent
                      .withOpacity(0.10),
                  borderRadius:
                  BorderRadius.circular(
                    9,
                  ),
                ),
                child: Icon(
                  Icons
                      .event_available_outlined,
                  color:
                  Colors.amberAccent,
                  size:
                  screenWidth * 0.039,
                ),
              ),

              SizedBox(
                width:
                screenWidth * 0.022,
              ),

              Expanded(
                child: Text(
                  '완료된 날은 자동으로 체크돼요.',
                  style:
                  TextStyle(
                    color: Colors.white
                        .withOpacity(0.60),
                    fontSize:
                    screenWidth * 0.028,
                    fontFamily:
                    'kopub',
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(
            height:
            screenWidth * 0.035,
          ),

          // ===================================================
          // MONTH HEADER
          // ===================================================

          Row(
            children: [
              _buildMonthButton(
                screenWidth:
                screenWidth,
                icon:
                Icons.chevron_left_rounded,
                onPressed: () {
                  setState(() {
                    currentMonth =
                        DateTime(
                          currentMonth.year,
                          currentMonth.month -
                              1,
                        );
                  });
                },
              ),

              Expanded(
                child: Text(
                  '${currentMonth.year}년 '
                      '${currentMonth.month}월',
                  textAlign:
                  TextAlign.center,
                  style:
                  TextStyle(
                    color:
                    Colors.white,
                    fontSize:
                    screenWidth * 0.036,
                    fontFamily:
                    'kopub',
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),

              _buildMonthButton(
                screenWidth:
                screenWidth,
                icon:
                Icons.chevron_right_rounded,
                onPressed: () {
                  setState(() {
                    currentMonth =
                        DateTime(
                          currentMonth.year,
                          currentMonth.month +
                              1,
                        );
                  });
                },
              ),
            ],
          ),

          SizedBox(
            height:
            screenWidth * 0.028,
          ),

          // ===================================================
          // WEEK DAYS
          // ===================================================

          _buildWeekdayHeader(
            screenWidth,
            calendarCellSize,
            calendarMargin,
          ),

          SizedBox(
            height:
            screenWidth * 0.012,
          ),

          // ===================================================
          // CALENDAR
          // ===================================================

          ..._buildCalendarGrid(
            startOfMonth,
            stageData,
            checkType,
            requiredMinutes,
            calendarCellSize,
            calendarMargin,
          ),

          if (stageData.isNotEmpty) ...[
            SizedBox(
              height:
              screenWidth * 0.03,
            ),

            Divider(
              color: Colors.white
                  .withOpacity(0.07),
              thickness: 1,
              height: 1,
            ),

            SizedBox(
              height:
              screenWidth * 0.025,
            ),

            _buildLegend(
              stageData,
              screenWidth * 0.026,
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================
  // MONTH BUTTON
  // =========================================================

  Widget _buildMonthButton({
    required double screenWidth,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.white
          .withOpacity(0.045),
      borderRadius:
      BorderRadius.circular(10),
      child: InkWell(
        borderRadius:
        BorderRadius.circular(10),
        onTap:
        onPressed,
        child: SizedBox(
          width:
          screenWidth * 0.085,
          height:
          screenWidth * 0.085,
          child: Icon(
            icon,
            color:
            Colors.white60,
            size:
            screenWidth * 0.05,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // WEEKDAY
  // =========================================================

  Widget _buildWeekdayHeader(
      double screenWidth,
      double cellSize,
      double margin,
      ) {
    const weekdays = [
      '일',
      '월',
      '화',
      '수',
      '목',
      '금',
      '토',
    ];

    return Row(
      mainAxisAlignment:
      MainAxisAlignment.center,
      children:
      List.generate(
        weekdays.length,
            (index) {
          return Container(
            width:
            cellSize,
            margin:
            EdgeInsets.symmetric(
              horizontal:
              margin,
            ),
            alignment:
            Alignment.center,
            child: Text(
              weekdays[index],
              style:
              TextStyle(
                color: Colors.white
                    .withOpacity(
                  0.35,
                ),
                fontFamily:
                'kopub',
                fontSize:
                screenWidth *
                    0.025,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================================================
  // STAGE COLOR
  // =========================================================

  Color _stageColor(int stageIndex) {
    const colors = [
      Color(0xFFFFE082), // 1단계
      Color(0xFFFFD740), // 2단계
      Color(0xFFFFB300), // 3단계
      Color(0xFFFF8F00), // 4단계
    ];

    return colors[stageIndex % colors.length];
  }

  // =========================================================
  // CALENDAR GRID
  //
  // ⚠️ 기존 날짜 생성 로직 그대로
  // =========================================================

  List<Widget> _buildCalendarGrid(
      DateTime startOfMonth,
      List<Map<String, dynamic>>
      stageData,
      ChallengeCheckActionType
      checkType,
      int requiredMinutes,
      double cellSize,
      double margin,
      ) {
    final List<Widget> rows =
    [];

    final firstWeekday =
        startOfMonth.weekday % 7;

    int dayCounter =
        1 - firstWeekday;

    for (int week = 0;
    week < 6;
    week++) {
      List<Widget> days = [];

      for (int weekday = 0;
      weekday < 7;
      weekday++) {
        final date =
        DateTime(
          currentMonth.year,
          currentMonth.month,
          1,
        ).add(
          Duration(
            days:
            dayCounter - 1,
          ),
        );

        days.add(
          _buildCalendarDayCell(
            date,
            stageData,
            checkType,
            requiredMinutes,
            cellSize,
            margin,
          ),
        );

        dayCounter++;
      }

      rows.add(
        Row(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children:
          days,
        ),
      );
    }

    return rows;
  }

  // =========================================================
  // DAY CELL
  //
  // ⚠️ 체크 판정 로직 그대로
  // =========================================================

  Widget _buildCalendarDayCell(
      DateTime date,
      List<Map<String, dynamic>>
      stageData,
      ChallengeCheckActionType
      checkType,
      int requiredMinutes,
      double cellSize,
      double margin,
      ) {
    final screenWidth =
        MediaQuery.of(context)
            .size
            .width;

    final today =
    DateTime.now().toLocal();

    final dateOnly =
    DateTime(
      date.year,
      date.month,
      date.day,
    );

    final todayOnly =
    DateTime(
      today.year,
      today.month,
      today.day,
    );

    final isToday =
        dateOnly == todayOnly;

    final isInMonth =
        date.month ==
            currentMonth.month;

    Color? backgroundColor;

    for (var stage
    in stageData) {
      final DateTime start =
      stage['start'];

      final DateTime end =
      stage['end'];

      if (!dateOnly.isBefore(start) &&
          !dateOnly.isAfter(end)) {
        final ChallengeAttempt
        attempt =
        stage['attempt'];

        bool isChecked =
        false;

        if (widget.isDoneMode) {
          isChecked =
          true;
        } else {
          try {
            isChecked =
                checkRoutineDateChecked(
                  challenge:
                  widget.challenge,
                  date:
                  dateOnly,
                  recordDataOrSavedBooks:
                  attempt.recordData ??
                      widget
                          .recordDataOrBooks,
                  attemptOverride:
                  attempt,
                );
          } catch (e) {
            debugPrint(
              '❗️체크 오류: $e',
            );
          }
        }

        if (isChecked) {
          backgroundColor =
          stage['color'];
        }

        break;
      }
    }

    final border =
    isToday
        ? Border.all(
      color: Colors
          .amberAccent,
      width: 1.5,
    )
        : null;

    final isInChallengePeriod =
    stageData.any(
          (stage) {
        final start =
        stage['start'];

        final end =
        stage['end'];

        return !dateOnly
            .isBefore(start) &&
            !dateOnly.isAfter(end);
      },
    );

    final textColor =
    backgroundColor != null
        ? const Color(
      0xFF013328,
    )
        : isInChallengePeriod
        ? Colors.white
        .withOpacity(
      0.78,
    )
        : Colors.white
        .withOpacity(
      0.25,
    );

    return Container(
      margin:
      EdgeInsets.all(
        margin,
      ),
      width:
      cellSize,
      height:
      cellSize,
      alignment:
      Alignment.center,
      decoration:
      BoxDecoration(
        color:
        backgroundColor ??
            Colors.white
                .withOpacity(
              0.045,
            ),
        border:
        border,
        borderRadius:
        BorderRadius.circular(
          8,
        ),
      ),
      child:
      isInMonth
          ? backgroundColor !=
          null
          ? Icon(
        Icons
            .check_rounded,
        color:
        const Color(
          0xFF013328,
        ),
        size:
        screenWidth *
            0.043,
      )
          : Text(
        '${date.day}',
        style:
        TextStyle(
          color:
          textColor,
          fontFamily:
          'kopub',
          fontSize:
          screenWidth *
              0.032,
          fontWeight:
          isToday
              ? FontWeight
              .bold
              : FontWeight
              .normal,
        ),
      )
          : const SizedBox
          .shrink(),
    );
  }

  // =========================================================
  // LEGEND
  //
  // ⚠️ 실제 표시 중인 스테이지만 노출하는 기존 로직 유지
  // =========================================================

  Widget _buildLegend(
      List<Map<String, dynamic>>
      stageData,
      double fontSize,
      ) {
    if (stageData.isEmpty) {
      return const SizedBox
          .shrink();
    }

    return Center(
      child: Wrap(
        alignment:
        WrapAlignment.center,
        crossAxisAlignment:
        WrapCrossAlignment.center,
        spacing:
        14,
        runSpacing:
        10,
        children:
        stageData.map(
              (stage) {
            final stageIndex =
            stage['stageIndex']
            as int;

            return Row(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                Container(
                  width:
                  9,
                  height:
                  9,
                  decoration:
                  BoxDecoration(
                    color:
                    _stageColor(
                      stageIndex,
                    ),
                    shape:
                    BoxShape.circle,
                  ),
                ),

                const SizedBox(
                  width: 6,
                ),

                Text(
                  '${stageIndex + 1}단계',
                  style:
                  TextStyle(
                    color: Colors.white
                        .withOpacity(
                      0.50,
                    ),
                    fontSize:
                    fontSize,
                    fontFamily:
                    'kopub',
                  ),
                ),
              ],
            );
          },
        ).toList(),
      ),
    );
  }
}