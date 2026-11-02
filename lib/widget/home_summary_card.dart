import 'package:flutter/material.dart';

import 'package:dayverse_book/model/weekly_reading_summary.dart';
import 'package:dayverse_book/utils/level_utils.dart';
import 'package:dayverse_book/screen/chart_activity_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReadingSummaryCard extends StatefulWidget {
  final WeeklyReadingSummary summary;

  /// ✅ 사용자 이름
  final String? userName;

  /// ✅ 오늘 누적 독서시간(분)
  final int todayReadingMinutes;

  /// 완독한 총 책 수
  final int totalRead;

  /// 현재 레벨
  final LevelInfo currentLevel;

  /// 다음 레벨까지 남은 책 수
  final int booksToNext;

  final bool isLoading;

  /// 지금까지 누적된 전체 독서 시간
  final int totalReadingMinutes;

  /// 지금까지 독서한 전체 날짜 수
  final int totalReadingDays;

  /// 역대 최장 연속 독서일
  final int longestStreakDays;

  /// 첫 번째 페이지 클릭
  /// ChartActivityScreen으로 이동
  final VoidCallback onReadingActivityTap;

  /// 두 번째 페이지 클릭
  /// ChartScreen으로 이동
  final VoidCallback onReadingStatsTap;

  /// 세 번째 페이지 클릭
  /// LevelScreen으로 이동
  final VoidCallback onLevelTap;

  const ReadingSummaryCard({
    super.key,
    this.userName,
    this.todayReadingMinutes = 0,
    required this.summary,
    required this.totalRead,
    required this.currentLevel,
    required this.booksToNext,
    required this.totalReadingMinutes,
    required this.totalReadingDays,
    required this.longestStreakDays,
    required this.onReadingActivityTap,
    required this.onReadingStatsTap,
    required this.onLevelTap,
    this.isLoading = false,
  });

  @override
  State<ReadingSummaryCard> createState() =>
      _ReadingSummaryCardState();
}

class _ReadingSummaryCardState
    extends State<ReadingSummaryCard> {
  final PageController _pageController =
  PageController();

  int _currentPage = 0;

  static const int _pageCount = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: h * 0.185,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.58),
              borderRadius:
              BorderRadius.circular(w * 0.055),
              border: Border.all(
                color: Colors.white.withOpacity(0.16),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius:
              BorderRadius.circular(w * 0.055),
              child: widget.isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.amberAccent,
                  strokeWidth: 2.5,
                ),
              )
                  : PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildReadingPage(w, h),
                  _buildReadingRecordPage(w, h),
                  _buildLevelPage(w, h),
                ],
              ),
            ),
          ),
        ),

        SizedBox(height: h * 0.012),

        _buildPageDots(w),
      ],
    );
  }

  /// 첫 번째 페이지: 오늘의 독서 성과
  Widget _buildReadingPage(double w, double h) {
    final todayMinutes = widget.todayReadingMinutes;
    final streakDays = widget.summary.streakDays;
    final name = widget.userName?.trim() ?? '';
    final greeting = _buildGreeting(name);
    final timeValue = _formatTodayTime(todayMinutes);

    return InkWell(
      onTap: widget.onReadingActivityTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          w * 0.05,
          h * 0.012,
          w * 0.05,
          h * 0.012,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 상단 라벨 및 시간대 아이콘
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "TODAY'S READING",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.62),
                    fontFamily: 'Kopub',
                    fontSize: w * 0.027,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.8,
                  ),
                ),
                Icon(
                  _getGreetingIcon(),
                  color: Colors.amberAccent.withOpacity(0.9),
                  size: w * 0.043,
                ),
              ],
            ),

            // 개인화 인사: 보조 텍스트
            Text(
              greeting,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.84),
                fontFamily: 'Kopub',
                fontSize: w * 0.033,
                fontWeight: FontWeight.w500,
              ),
            ),

            // 오늘 독서시간을 크게 / 연속 독서를 오른쪽에
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            timeValue,
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Kopub',
                              fontSize: w * 0.073,
                              fontWeight: FontWeight.bold,
                              height: 1.05,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: w * 0.013),
                      Text(
                        todayMinutes < 60 ? '분 읽었어요' : '읽었어요',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontFamily: 'Kopub',
                          fontSize: w * 0.029,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: w * 0.025),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: w * 0.044,
                          color: streakDays > 0
                              ? Colors.amberAccent
                              : Colors.white38,
                        ),
                        SizedBox(width: w * 0.006),
                        Text(
                          '$streakDays일 연속',
                          style: TextStyle(
                            color: streakDays > 0
                                ? Colors.amberAccent
                                : Colors.white70,
                            fontFamily: 'Kopub',
                            fontSize: w * 0.03,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                  ],
                ),
              ],
            ),

            // 요일별 독서 현황: 기존 로직 유지
            _buildWeekDays(w),
          ],
        ),
      ),
    );
  }

  String _buildGreeting(String name) {
    final hour = DateTime.now().hour;
    late final String greeting;

    if (hour >= 5 && hour < 9) {
      greeting = '좋은 아침이에요';
    } else if (hour >= 9 && hour < 12) {
      greeting = '활기찬 오전이에요';
    } else if (hour >= 12 && hour < 14) {
      greeting = '점심은 맛있게 드셨나요?';
    } else if (hour >= 14 && hour < 18) {
      greeting = '나른한 오후예요';
    } else if (hour >= 18 && hour < 21) {
      greeting = '편안한 저녁이에요';
    } else if (hour >= 21) {
      greeting = '여유로운 밤이에요';
    } else {
      greeting = '고요한 새벽이에요';
    }

    return name.isEmpty ? '$greeting.' : '$greeting, $name님.';
  }

  String _formatTodayTime(int minutes) {
    if (minutes < 60) return '$minutes';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0 ? '$hours시간' : '$hours시간 $remainder분';
  }

  IconData _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 9) return Icons.wb_twilight_rounded;
    if (hour >= 9 && hour < 12) return Icons.wb_sunny_outlined;
    if (hour >= 12 && hour < 14) return Icons.wb_sunny_rounded;
    if (hour >= 14 && hour < 18) return Icons.light_mode_outlined;
    if (hour >= 18 && hour < 21) return Icons.nights_stay_outlined;
    return Icons.dark_mode_outlined;
  }

  /// 두 번째 페이지
  /// 전체 독서 핵심 기록
  Widget _buildReadingRecordPage(
      double w,
      double h,
      ) {
    return InkWell(
      onTap: widget.onReadingStatsTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          w * 0.045,
          h * 0.01,
          w * 0.04,
          h * 0.014,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'READING OVERVIEW',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.62),
                      fontFamily: 'Kopub',
                      fontSize: w * 0.027,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.8,
                    ),
                  ),

                  SizedBox(height: h * 0.016),

                  Row(
                    children: [
                      Expanded(
                        child: _buildRecordItem(
                          w: w,
                          icon: Icons.schedule_rounded,
                          iconColor: Colors.amberAccent,
                          value: _formatCompactMinutes(
                            widget.totalReadingMinutes,
                          ),
                          label: '독서 시간',
                        ),
                      ),

                      _buildRecordDivider(h),

                      Expanded(
                        child: _buildRecordItem(
                          w: w,
                          icon: Icons.menu_book_rounded,
                          iconColor: Colors.amberAccent,
                          value: '${widget.totalRead}권',
                          label: '총 완독',
                        ),
                      ),

                      _buildRecordDivider(h),

                      Expanded(
                        child: _buildRecordItem(
                          w: w,
                          icon: Icons.calendar_today_rounded,
                          iconColor: Colors.amberAccent,
                          value: '${widget.totalReadingDays}일',
                          label: '독서일',
                        ),
                      ),

                      _buildRecordDivider(h),

                      Expanded(
                        child: _buildRecordItem(
                          w: w,
                          icon: Icons.local_fire_department_rounded,
                          iconColor: Colors.amberAccent,
                          value: '${widget.longestStreakDays}일',
                          label: '최장 연속',
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: h * 0.016),


                ],
              ),
            ),

            SizedBox(width: w * 0.018),

            _buildArrow(w),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordDivider(double h) {
    return Container(
      width: 1,
      height: h * 0.052,
      color: Colors.white.withOpacity(0.16),
    );
  }

  Widget _buildRecordItem({
    required double w,
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: iconColor,
          size: w * 0.04,
        ),

        SizedBox(height: w * 0.008),

        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Kopub',
            fontSize: w * 0.032,
            fontWeight: FontWeight.bold,
          ),
        ),

        SizedBox(height: w * 0.006),

        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.62),
            fontFamily: 'Kopub',
            fontSize: w * 0.021,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatCompactMinutes(int totalMinutes) {
    if (totalMinutes <= 0) {
      return '0분';
    }

    if (totalMinutes < 60) {
      return '$totalMinutes분';
    }

    final hours = totalMinutes ~/ 60;

    return '$hours시간';
  }

  /// 세 번째 페이지
  /// 현재 레벨 및 레벨 진행률
  Widget _buildLevelPage(
      double w,
      double h,
      ) {
    final progress = LevelUtils.getLevelProgress(
      widget.totalRead,
    );

    final progressText = widget.currentLevel.end == null
        ? '최고 레벨 달성'
        : '다음 레벨까지 ${widget.booksToNext}권';

    return InkWell(
      onTap: widget.onLevelTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          w * 0.055,
          h * 0.01,
          w * 0.05,
          h * 0.014,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MY LEVEL',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.62),
                      fontFamily: 'Kopub',
                      fontSize: w * 0.027,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.8,
                    ),
                  ),

                  SizedBox(height: h * 0.006),

                  SizedBox(
                    width: double.infinity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LevelUtils.buildLevelIcon(
                          widget.currentLevel,
                          size: w * 0.06,
                        ),

                        SizedBox(width: w * 0.014),

                        Flexible(
                          child: Text(
                            widget.currentLevel.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: widget.currentLevel.color,
                              fontFamily: 'Kopub',
                              fontSize: w * 0.042,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        SizedBox(width: w * 0.012),

                        Text(
                          '(${widget.currentLevel.rangeText})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.currentLevel.color,
                            fontFamily: 'Kopub',
                            fontSize: w * 0.032,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: h * 0.017),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: h * 0.006,
                      backgroundColor:
                      Colors.white.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.currentLevel.color,
                      ),
                    ),
                  ),

                  SizedBox(height: h * 0.015),

                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      widget.currentLevel.end == null
                          ? '총 ${widget.totalRead}권 완독 • 최고 레벨 달성'
                          : '총 ${widget.totalRead}권 완독 • 다음 레벨까지 ${widget.booksToNext}권 남음',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontFamily: 'Kopub',
                        fontSize: w * 0.025,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(width: w * 0.025),

            _buildArrow(w),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekDays(double w) {
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
      children: List.generate(7, (index) {
        final hasRead =
            index < widget.summary.dailyMinutes.length &&
                widget.summary.dailyMinutes[index] > 0;

        final isToday =
            index == DateTime.now().weekday - 1;

        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration:
                const Duration(milliseconds: 220),
                width: w * 0.045,
                height: w * 0.045,
                decoration: BoxDecoration(
                  color: hasRead
                      ? Colors.amberAccent
                      : Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isToday
                        ? Colors.white.withOpacity(0.9)
                        : Colors.white.withOpacity(0.2),
                    width: isToday ? 1.5 : 1,
                  ),
                ),
                child: hasRead
                    ? Icon(
                  Icons.check_rounded,
                  color:
                  const Color(0xFF013328),
                  size: w * 0.029,
                )
                    : null,
              ),

              SizedBox(height: w * 0.009),

              Text(
                labels[index],
                style: TextStyle(
                  color: isToday
                      ? Colors.white
                      : Colors.white.withOpacity(0.52),
                  fontFamily: 'Kopub',
                  fontSize: w * 0.024,
                  fontWeight: isToday
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStreakText(double w) {
    final streakDays =
        widget.summary.streakDays;

    final hasReadToday =
        widget.summary.hasReadToday;

    return Row(
      mainAxisAlignment:
      MainAxisAlignment.center,
      children: [
        Icon(
          hasReadToday
              ? Icons.check_circle_rounded
              : streakDays > 0
              ? Icons
              .local_fire_department_rounded
              : Icons.auto_awesome_rounded,
          color: streakDays > 0 || hasReadToday
              ? Colors.amberAccent
              : Colors.white.withOpacity(0.55),
          size: w * 0.032,
        ),

        SizedBox(width: w * 0.013),

        Flexible(
          child: Text(
            _buildStreakMessage(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontFamily: 'Kopub',
              fontSize: w * 0.026,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  String _buildStreakMessage() {
    final streakDays =
        widget.summary.streakDays;

    final hasReadToday =
        widget.summary.hasReadToday;

    if (streakDays >= 2) {
      return '$streakDays일 연속 독서 중!';
    }

    if (hasReadToday) {
      return '오늘도 독서 완료!';
    }

    if (streakDays == 1) {
      return '오늘도 읽으면 연속 기록이 이어져요';
    }

    return '오늘부터 연속 독서를 시작해보세요';
  }

  Widget _buildArrow(double w) {
    return Icon(
      Icons.arrow_forward_ios_rounded,
      color: Colors.white.withOpacity(0.82),
      size: w * 0.04,
    );
  }

  Widget _buildPageDots(double w) {
    return Row(
      mainAxisAlignment:
      MainAxisAlignment.center,
      children: List.generate(
        _pageCount,
            (index) {
          final isActive =
              index == _currentPage;

          return AnimatedContainer(
            duration:
            const Duration(milliseconds: 250),
            margin: EdgeInsets.symmetric(
              horizontal: w * 0.006,
            ),
            width: isActive
                ? w * 0.055
                : w * 0.018,
            height: w * 0.018,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(
                isActive ? 0.9 : 0.45,
              ),
              borderRadius:
              BorderRadius.circular(999),
            ),
          );
        },
      ),
    );
  }


}