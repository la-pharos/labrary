
class WeeklyReadingSummary {
  /// 현재 연속 독서 일수
  final int streakDays;

  /// 이번 주 총 독서 시간
  final int thisWeekMinutes;

  /// 지난주 총 독서 시간
  final int lastWeekMinutes;

  /// 월요일부터 일요일까지의 독서 시간
  final List<int> dailyMinutes;

  /// 오늘 독서 여부
  final bool hasReadToday;

  const WeeklyReadingSummary({
    required this.streakDays,
    required this.thisWeekMinutes,
    required this.lastWeekMinutes,
    required this.dailyMinutes,
    required this.hasReadToday,
  }) : assert(dailyMinutes.length == 7);

  /// 지난주 대비 독서 시간 차이
  int get differenceFromLastWeek {
    return thisWeekMinutes - lastWeekMinutes;
  }

  /// 이번 주 독서한 날짜 수
  int get readingDayCount {
    return dailyMinutes.where((minutes) => minutes > 0).length;
  }

  /// 월요일부터 일요일까지 독서 여부
  List<bool> get readingDays {
    return dailyMinutes
        .map((minutes) => minutes > 0)
        .toList(growable: false);
  }

  /// 아직 기록이 전혀 없는 상태
  bool get isEmpty {
    return streakDays == 0 &&
        thisWeekMinutes == 0 &&
        lastWeekMinutes == 0;
  }

  factory WeeklyReadingSummary.empty() {
    return  WeeklyReadingSummary(
      streakDays: 0,
      thisWeekMinutes: 0,
      lastWeekMinutes: 0,
      dailyMinutes: [0, 0, 0, 0, 0, 0, 0],
      hasReadToday: false,
    );
  }

  WeeklyReadingSummary copyWith({
    int? streakDays,
    int? thisWeekMinutes,
    int? lastWeekMinutes,
    List<int>? dailyMinutes,
    bool? hasReadToday,
  }) {
    return WeeklyReadingSummary(
      streakDays: streakDays ?? this.streakDays,
      thisWeekMinutes: thisWeekMinutes ?? this.thisWeekMinutes,
      lastWeekMinutes: lastWeekMinutes ?? this.lastWeekMinutes,
      dailyMinutes: dailyMinutes ?? this.dailyMinutes,
      hasReadToday: hasReadToday ?? this.hasReadToday,
    );
  }
}