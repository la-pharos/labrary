import 'package:flutter/material.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/challenge_attempt_model.dart';
import 'package:dayverse_book/utils/challenge_check_utils.dart';
import 'package:dayverse_book/utils/challenge_progress_utils.dart';

class RoutineCalendar extends StatefulWidget {
  final Challenge challenge;
  final dynamic recordDataOrBooks;
  final bool isDoneMode;

  const RoutineCalendar({
    super.key,
    required this.challenge,
    required this.recordDataOrBooks,
    this.isDoneMode = false,
  });

  @override
  State<RoutineCalendar> createState() => _RoutineCalendarState();
}

class _RoutineCalendarState extends State<RoutineCalendar> {
  late DateTime currentMonth;

  @override
  void initState() {
    super.initState();
    currentMonth = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final startOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
    final checkType = getChallengeCheckActionType(widget.challenge);
    final requiredMinutes = widget.challenge.requiredMinutes ?? 0;

    final titleFontSize = screenWidth * 0.035; // ≈16
    final subtitleFontSize = screenWidth * 0.03; // ≈12
    final calendarCellSize = screenWidth * 0.10; // ≈44
    final calendarMargin = screenWidth * 0.008; // ≈4
    final iconSize = screenWidth * 0.05;

    final stageData = widget.challenge.attempts
        .where((a) => a.stageIndex != null)
        .map((a) {
      final start = DateTime(a.startDate.year, a.startDate.month, a.startDate.day);
      final duration = a.selectedDuration ?? 0;
      final end = start.add(Duration(days: duration - 1));
      return {
        'start': start,
        'end': end,
        'color': _stageColor(a.stageIndex ?? 0),
        'attempt': a,
      };
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: screenWidth * 0.03),
        Text("🔸 전체 진행 체크",
            style: TextStyle(color: Colors.white, fontSize: titleFontSize, fontFamily: 'Kopub')),
        SizedBox(height: screenWidth * 0.03),
        Center(
          child: Text(
            "완료된 날은 자동으로 체크돼요!",
            style: TextStyle(
              color: Colors.white70,
              fontSize: subtitleFontSize,
              fontFamily: 'Kopub',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left, color: Colors.white, size: iconSize),
              onPressed: () => setState(() {
                currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
              }),
            ),
            Text("${currentMonth.year}년 ${currentMonth.month}월",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleFontSize,
                  fontFamily: 'kopub',
                  fontWeight: FontWeight.bold,
                )),
            IconButton(
              icon: Icon(Icons.chevron_right, color: Colors.white, size: iconSize),
              onPressed: () => setState(() {
                currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
              }),
            ),
          ],
        ),
        SizedBox(height: screenWidth * 0.03),
        ..._buildCalendarGrid(startOfMonth, stageData, checkType, requiredMinutes, calendarCellSize, calendarMargin),
        SizedBox(height: screenWidth * 0.02),
        _buildLegend(stageData.length, subtitleFontSize),
      ],
    );
  }

  Color _stageColor(int stageIndex) {
    const colors = [
      Color(0xFF00FF88),
      Color(0xFF66CCFF),
      Color(0xFFFFCC66),
      Color(0xFFFF6699),
    ];
    return colors[stageIndex % colors.length].withOpacity(0.7);
  }

  List<Widget> _buildCalendarGrid(
      DateTime startOfMonth,
      List<Map<String, dynamic>> stageData,
      ChallengeCheckActionType checkType,
      int requiredMinutes,
      double cellSize,
      double margin,
      ) {
    final List<Widget> rows = [];
    final firstWeekday = startOfMonth.weekday % 7;
    int dayCounter = 1 - firstWeekday;

    for (int week = 0; week < 6; week++) {
      List<Widget> days = [];
      for (int weekday = 0; weekday < 7; weekday++) {
        final date = DateTime(currentMonth.year, currentMonth.month, 1)
            .add(Duration(days: dayCounter - 1));
        days.add(_buildCalendarDayCell(date, stageData, checkType, requiredMinutes, cellSize, margin));
        dayCounter++;
      }
      rows.add(Row(mainAxisAlignment: MainAxisAlignment.center, children: days));
    }
    return rows;
  }

  Widget _buildCalendarDayCell(
      DateTime date,
      List<Map<String, dynamic>> stageData,
      ChallengeCheckActionType checkType,
      int requiredMinutes,
      double cellSize,
      double margin,
      ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final today = DateTime.now().toLocal();
    final dateOnly = DateTime(date.year, date.month, date.day);
    final todayOnly = DateTime(today.year, today.month, today.day);
    final isToday = dateOnly == todayOnly;
    final isInMonth = date.month == currentMonth.month;

    Color? backgroundColor;
    for (var stage in stageData) {
      final DateTime start = stage['start'];
      final DateTime end = stage['end'];
      if (!dateOnly.isBefore(start) && !dateOnly.isAfter(end)) {
        final ChallengeAttempt attempt = stage['attempt'];
        bool isChecked = false;

        if (widget.isDoneMode) {
          isChecked = true;
        } else {
          try {
            isChecked = checkRoutineDateChecked(
              challenge: widget.challenge,
              date: dateOnly,
              recordDataOrSavedBooks: widget.recordDataOrBooks,
            );
          } catch (e) {
            debugPrint("❗️체크 오류: $e");
          }
        }

        if (isChecked) {
          backgroundColor = stage['color'];
        }
        break;
      }
    }

    final border = isToday ? Border.all(color: Colors.amberAccent, width: 2) : null;

    final isInChallengePeriod = stageData.any((stage) {
      final start = stage['start'];
      final end = stage['end'];
      return !dateOnly.isBefore(start) && !dateOnly.isAfter(end);
    });

    final textColor = backgroundColor != null
        ? Colors.black
        : isInChallengePeriod
        ? Colors.white
        : Colors.white30;

    return Container(
      margin: EdgeInsets.all(margin),
      width: cellSize,
      height: cellSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white10,
        border: border,
        borderRadius: BorderRadius.circular(6),
      ),
      child: isInMonth
          ? (backgroundColor != null
          ? Icon(Icons.check, color: Colors.black, size: screenWidth * 0.045)
          : Text("${date.day}",
          style: TextStyle(
            color: textColor,
            fontFamily: 'kopub',
            fontSize: screenWidth * 0.035,
          )))
          : const SizedBox.shrink(),
    );
  }

  Widget _buildLegend(int stageCount, double fontSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(stageCount, (index) {
        return Row(
          children: [
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: _stageColor(index),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Text("스테이지 ${index + 1}",
                style: TextStyle(color: Colors.white70, fontSize: fontSize, fontFamily: 'kopub')),
            const SizedBox(width: 8),
          ],
        );
      }),
    );
  }
}
