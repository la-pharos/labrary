import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

/// 공용 날짜 선택 달력
class CalendarWidget extends StatefulWidget {
  final DateTime selectedDate;
  final DateTime minDate;
  final DateTime maxDate;
  final bool isStartDate;
  final void Function(DateTime) onDatePicked;

  /// 선택 불가 날짜 리스트
  final List<DateTime> disabledDates;

  const CalendarWidget({
    super.key,
    required this.selectedDate,
    required this.minDate,
    required this.maxDate,
    required this.onDatePicked,
    required this.isStartDate,
    this.disabledDates = const [],
  });

  @override
  State<CalendarWidget> createState() =>
      _CalendarWidgetState();
}

class _CalendarWidgetState
    extends State<CalendarWidget> {
  late DateTime focusedDay;
  late DateTime tempSelectedDate;

  @override
  void initState() {
    super.initState();

    focusedDay =
        widget.selectedDate;

    tempSelectedDate =
        widget.selectedDate;
  }

  bool isSameDate(
      DateTime a,
      DateTime b,
      ) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width;

    final fontSize =
        screenWidth * 0.032;

    return Column(
      mainAxisSize:
      MainAxisSize.min,
      children: [
        // =====================================================
        // 안내
        // =====================================================

        Container(
          width:
          double.infinity,
          padding:
          EdgeInsets.symmetric(
            horizontal:
            screenWidth * 0.035,
            vertical:
            screenWidth * 0.03,
          ),
          decoration:
          BoxDecoration(
            color: Colors.amberAccent
                .withOpacity(0.07),
            borderRadius:
            BorderRadius.circular(12),
            border: Border.all(
              color: Colors.amberAccent
                  .withOpacity(0.16),
            ),
          ),
          child: Row(
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
                  widget.isStartDate
                      ? Icons
                      .play_arrow_rounded
                      : Icons
                      .flag_outlined,
                  color:
                  Colors.amberAccent,
                  size:
                  screenWidth * 0.04,
                ),
              ),

              SizedBox(
                width:
                screenWidth * 0.022,
              ),

              Expanded(
                child: Text(
                  widget.isStartDate
                      ? '시작일을 선택하세요.'
                      : '종료일을 선택하세요.',
                  style:
                  TextStyle(
                    fontSize:
                    screenWidth * 0.03,
                    fontFamily:
                    'kopub',
                    color:
                    Colors.white70,
                    fontWeight:
                    FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(
          height:
          screenWidth * 0.025,
        ),

        // =====================================================
        // CALENDAR
        // =====================================================

        TableCalendar(
          firstDay:
          DateTime(2000),
          lastDay:
          DateTime(2100),
          focusedDay:
          focusedDay,

          selectedDayPredicate: (day) =>
              isSameDate(
                day,
                tempSelectedDate,
              ),

          enabledDayPredicate:
              (day) {
            final d =
            DateTime(
              day.year,
              day.month,
              day.day,
            );

            final isInRange =
                !d.isBefore(
                  widget.minDate,
                ) &&
                    !d.isAfter(
                      widget.maxDate,
                    );

            final isDisabled =
            widget.disabledDates.any(
                  (disabledDate) =>
                  isSameDate(
                    d,
                    disabledDate,
                  ),
            );

            return isInRange &&
                !isDisabled;
          },

          onDaySelected:
              (
              selected,
              focused,
              ) {
            final d =
            DateTime(
              selected.year,
              selected.month,
              selected.day,
            );

            final isInRange =
                !d.isBefore(
                  widget.minDate,
                ) &&
                    !d.isAfter(
                      widget.maxDate,
                    );

            final isDisabled =
            widget.disabledDates.any(
                  (disabledDate) =>
                  isSameDate(
                    d,
                    disabledDate,
                  ),
            );

            if (isInRange &&
                !isDisabled) {
              setState(() {
                tempSelectedDate = d;
                focusedDay = focused;
              });
            }
          },

          onPageChanged:
              (focused) {
            setState(() {
              focusedDay =
                  focused;
            });
          },

          // ===================================================
          // HEADER
          // ===================================================

          headerStyle:
          HeaderStyle(
            formatButtonVisible:
            false,
            titleCentered:
            true,

            leftChevronIcon:
            _buildChevron(
              Icons.chevron_left_rounded,
              screenWidth,
            ),

            rightChevronIcon:
            _buildChevron(
              Icons.chevron_right_rounded,
              screenWidth,
            ),

            headerPadding:
            EdgeInsets.symmetric(
              vertical:
              screenWidth * 0.015,
            ),

            titleTextStyle:
            TextStyle(
              fontFamily:
              'kopub',
              fontWeight:
              FontWeight.bold,
              fontSize:
              screenWidth * 0.036,
              color:
              Colors.white,
            ),
          ),

          // ===================================================
          // WEEK DAYS
          // ===================================================

          daysOfWeekHeight:
          screenWidth * 0.085,

          daysOfWeekStyle:
          DaysOfWeekStyle(
            weekdayStyle:
            TextStyle(
              color:
              Colors.white38,
              fontFamily:
              'kopub',
              fontSize:
              screenWidth * 0.026,
              fontWeight:
              FontWeight.w600,
            ),

            weekendStyle:
            TextStyle(
              color:
              Colors.white38,
              fontFamily:
              'kopub',
              fontSize:
              screenWidth * 0.026,
              fontWeight:
              FontWeight.w600,
            ),
          ),

          // ===================================================
          // CELL STYLE
          // ===================================================

          calendarStyle:
          CalendarStyle(
            outsideDaysVisible:
            false,

            cellMargin:
            EdgeInsets.all(
              screenWidth * 0.009,
            ),

            defaultTextStyle:
            TextStyle(
              color:
              Colors.white70,
              fontFamily:
              'kopub',
              fontSize:
              fontSize,
            ),

            weekendTextStyle:
            TextStyle(
              color:
              Colors.white70,
              fontFamily:
              'kopub',
              fontSize:
              fontSize,
            ),

            disabledTextStyle:
            TextStyle(
              color:
              Colors.white24,
              fontFamily:
              'kopub',
              fontSize:
              fontSize,
            ),

            // 선택한 날짜
            selectedDecoration:
            const BoxDecoration(
              color:
              Colors.amberAccent,
              shape:
              BoxShape.circle,
            ),

            selectedTextStyle:
            TextStyle(
              color:
              const Color(
                0xFF013328,
              ),
              fontFamily:
              'kopub',
              fontWeight:
              FontWeight.bold,
              fontSize:
              fontSize,
            ),

            // 오늘
            todayDecoration:
            BoxDecoration(
              color:
              Colors.transparent,
              shape:
              BoxShape.circle,
              border:
              Border.all(
                color:
                Colors.amberAccent,
                width: 1.5,
              ),
            ),

            todayTextStyle:
            TextStyle(
              color:
              Colors.amberAccent,
              fontFamily:
              'kopub',
              fontWeight:
              FontWeight.bold,
              fontSize:
              fontSize,
            ),
          ),

          // ===================================================
          // CUSTOM DAY CELL
          // ===================================================

          calendarBuilders:
          CalendarBuilders(
            disabledBuilder:
                (
                context,
                day,
                focusedDay,
                ) {
              return Center(
                child: Container(
                  width:
                  screenWidth * 0.085,
                  height:
                  screenWidth * 0.085,
                  alignment:
                  Alignment.center,
                  decoration:
                  BoxDecoration(
                    color: Colors.white
                        .withOpacity(0.025),
                    shape:
                    BoxShape.circle,
                  ),
                  child: Text(
                    '${day.day}',
                    style:
                    TextStyle(
                      color:
                      Colors.white24,
                      fontFamily:
                      'kopub',
                      fontSize:
                      fontSize,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        SizedBox(
          height: screenWidth * 0.025,
        ),

        Divider(
          color: Colors.white.withOpacity(0.07),
          height: 1,
        ),

        SizedBox(
          height: screenWidth * 0.025,
        ),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    '선택한 날짜',
                    style: TextStyle(
                      color: Colors.white38,
                      fontFamily: 'kopub',
                      fontSize:
                      screenWidth * 0.025,
                    ),
                  ),

                  SizedBox(
                    height:
                    screenWidth * 0.006,
                  ),

                  Text(
                    _formatDate(
                      tempSelectedDate,
                    ),
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'kopub',
                      fontSize:
                      screenWidth * 0.034,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                '취소',
                style: TextStyle(
                  color: Colors.white54,
                  fontFamily: 'kopub',
                  fontSize:
                  screenWidth * 0.03,
                ),
              ),
            ),

            SizedBox(
              width:
              screenWidth * 0.01,
            ),

            ElevatedButton(
              onPressed: () {
                final selected =
                    tempSelectedDate;

                Navigator.pop(context);

                widget.onDatePicked(
                  selected,
                );
              },
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                Colors.amberAccent,
                foregroundColor:
                const Color(0xFF013328),
                elevation: 0,
                padding:
                EdgeInsets.symmetric(
                  horizontal:
                  screenWidth * 0.04,
                  vertical:
                  screenWidth * 0.026,
                ),
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(12),
                ),
              ),
              child: Text(
                '확인',
                style: TextStyle(
                  fontFamily: 'kopub',
                  fontSize:
                  screenWidth * 0.03,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChevron(
      IconData icon,
      double screenWidth,
      ) {
    return Container(
      width:
      screenWidth * 0.075,
      height:
      screenWidth * 0.075,
      decoration:
      BoxDecoration(
        color: Colors.white
            .withOpacity(0.045),
        borderRadius:
        BorderRadius.circular(9),
      ),
      child: Icon(
        icon,
        color:
        Colors.white60,
        size:
        screenWidth * 0.045,
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
        .padLeft(2, '0');

    final day =
    date.day
        .toString()
        .padLeft(2, '0');

    return '$year.$month.$day';
  }

}

/// 공용 달력 다이얼로그
Future<void> showCalendarDialog({
  required BuildContext context,
  required DateTime selectedDate,
  required DateTime minDate,
  required DateTime maxDate,
  required Function(DateTime) onDatePicked,
  required bool isStartDate,
  List<DateTime> disabledDates =
  const [],
}) {
  final screenWidth =
      MediaQuery.of(context).size.width;

  final dialogWidth =
      screenWidth * 0.90;

  final padding =
      screenWidth * 0.04;

  return showDialog(
    context:
    context,

    barrierColor:
    Colors.black.withOpacity(0.60),

    builder:
        (context) {
      return Dialog(
        backgroundColor:
        Colors.transparent,
        insetPadding:
        EdgeInsets.symmetric(
          horizontal:
          screenWidth * 0.05,
        ),
        child: Container(
          width:
          dialogWidth,
          padding:
          EdgeInsets.all(
            padding,
          ),
          decoration:
          BoxDecoration(
            color:
            const Color(
              0xFF16483F,
            ),
            borderRadius:
            BorderRadius.circular(
              20,
            ),
            border:
            Border.all(
              color: Colors.white
                  .withOpacity(
                0.08,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withOpacity(0.30),
                blurRadius:
                24,
                offset:
                const Offset(
                  0,
                  10,
                ),
              ),
            ],
          ),
          child:
          CalendarWidget(
            selectedDate:
            selectedDate,
            minDate:
            minDate,
            maxDate:
            maxDate,
            onDatePicked:
            onDatePicked,
            isStartDate:
            isStartDate,
            disabledDates:
            disabledDates,
          ),
        ),
      );
    },
  );
}