import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

/// 📆 1. Calendar 자체 위젯
class CalendarWidget extends StatefulWidget {
  final DateTime selectedDate;
  final DateTime minDate;
  final DateTime maxDate;
  final bool isStartDate;
  final void Function(DateTime) onDatePicked;

  /// ✅ 선택 불가 날짜 리스트 (스테이지 챌린지에서만 전달됨)
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
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  late DateTime focusedDay;

  @override
  void initState() {
    super.initState();
    focusedDay = widget.selectedDate;
  }

  bool isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth * 0.035;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(top: screenWidth * 0.03),
          child: Text(
            widget.isStartDate ? "시작일을 선택하세요." : "종료일을 선택하세요.",
            style: TextStyle(
              fontSize: fontSize,
              fontFamily: 'kopub',
              color: Colors.black87,
            ),
          ),
        ),
        TableCalendar(
          firstDay: DateTime(2000),
          lastDay: DateTime(2100),
          focusedDay: focusedDay,
          selectedDayPredicate: (day) => isSameDate(day, widget.selectedDate),
          enabledDayPredicate: (day) {
            final d = DateTime(day.year, day.month, day.day);
            final isInRange = !d.isBefore(widget.minDate) && !d.isAfter(widget.maxDate);
            final isDisabled = widget.disabledDates.any((dd) => isSameDate(d, dd));
            return isInRange && !isDisabled;
          },
          onDaySelected: (selected, focused) {
            final d = DateTime(selected.year, selected.month, selected.day);
            final isInRange = !d.isBefore(widget.minDate) && !d.isAfter(widget.maxDate);
            final isDisabled = widget.disabledDates.any((dd) => isSameDate(d, dd));
            if (isInRange && !isDisabled) {
              Navigator.pop(context);
              widget.onDatePicked(d);
            }
          },
          onPageChanged: (focused) => setState(() => focusedDay = focused),
          calendarStyle: CalendarStyle(
            disabledTextStyle: TextStyle(color: Colors.grey, fontSize: fontSize * 0.9),
            todayTextStyle: TextStyle(
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
            ),
            defaultTextStyle: TextStyle(fontSize: fontSize),
            weekendTextStyle: TextStyle(fontSize: fontSize),
            selectedDecoration: const BoxDecoration(
              color: Colors.amberAccent,
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(
              fontFamily: 'kopub',
              fontWeight: FontWeight.bold,
              fontSize: fontSize + 2,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

/// 📅 2. showDialog 함수 — 반응형으로 래핑
Future<void> showCalendarDialog({
  required BuildContext context,
  required DateTime selectedDate,
  required DateTime minDate,
  required DateTime maxDate,
  required Function(DateTime) onDatePicked,
  required bool isStartDate,
  List<DateTime> disabledDates = const [],
}) {
  final screenWidth = MediaQuery.of(context).size.width;
  final dialogWidth = screenWidth * 0.85;
  final padding = screenWidth * 0.04;

  return showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: dialogWidth,
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding * 0.75),
          child: CalendarWidget(
            selectedDate: selectedDate,
            minDate: minDate,
            maxDate: maxDate,
            onDatePicked: onDatePicked,
            isStartDate: isStartDate,
            disabledDates: disabledDates,
          ),
        ),
      );
    },
  );
}
