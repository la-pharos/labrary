import 'package:dayverse_book/model/challenge_model.dart';

/// 11월부터 사용하도록 만든 생성기. 아직 Provider에 연결하지 않는다.
/// 주간 소속 월 = 월~일 7일 중 4일 이상이 포함된 달(목요일의 달).
class RecurringChallengeFactory {
  static DateTime mondayOf(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static DateTime weekMajorityMonthDate(DateTime monday) =>
      DateTime(monday.year, monday.month, monday.day + 3); // 목요일

  static String _two(int value) => value.toString().padLeft(2, '0');
  static String _ymd(DateTime date) =>
      '${date.year}.${_two(date.month)}.${_two(date.day)}';

  static Challenge weekly(DateTime referenceDate) {
    final monday = mondayOf(referenceDate);
    final sunday = DateTime(monday.year, monday.month, monday.day + 6, 23, 59, 59);
    final majority = weekMajorityMonthDate(monday);
    final month = majority.month;
    return Challenge(
      id: 'weekly_${monday.year}_${_two(monday.month)}_${_two(monday.day)}_60',
      title: '$month월 주간 챌린지',
      shortDescription: '이번 주, 60분만 책과 함께해요.',
      longDescription: '일주일 동안 책과 함께하는 60분을 만들어보세요. 하루에 몰아서 읽거나 여러 날에 나누어 읽어도 괜찮아요.',
      goalDescription: '해당 주 누적 독서시간 60분',
      recommendedFor: '- 주간 독서 목표가 필요한 분\n- 독서를 가볍게 시작하고 싶은 분',
      guideText: '월요일부터 일요일까지의 독서 타이머 기록을 합산합니다. 참여 전 이번 주 기록도 인정됩니다.',
      stageType: ChallengeStageType.single,
      category: ChallengeCategory.growth,
      method: ChallengeMethod.timeBased,
      period: ChallengePeriod.periodBased,
      checkMode: ChallengeCheckMode.auto,
      theme: ChallengeTheme.habit,
      startDate: monday,
      endDate: sunday,
      requiredMinutes: 60,
      imageUrl: 'recurring://weekly',
      goalDisplayText: '이번 주 누적 60분 독서',
      periodDisplayText: '${_ymd(monday)} ~ ${_ymd(sunday)}',
    );
  }

  static List<Challenge> monthly(DateTime referenceDate) {
    final first = DateTime(referenceDate.year, referenceDate.month, 1);
    final last = DateTime(referenceDate.year, referenceDate.month + 1, 0, 23, 59, 59);
    return [2, 5].map((n) => Challenge(
      id: 'monthly_${first.year}_${_two(first.month)}_$n',
      title: '${first.month}월 월간 챌린지',
      shortDescription: '${first.month}월 한 달, 책 $n권을 완독해보세요.',
      longDescription: '좋아하는 책을 골라 이번 달에 $n권 완독해보세요. 하나씩 쌓이는 완독의 기쁨을 느껴보세요.',
      goalDescription: '한 달 동안 책 $n권 완독',
      recommendedFor: '- 월간 독서 목표가 필요한 분\n- 완독 습관을 만들고 싶은 분',
      guideText: '해당 월 1일부터 말일까지의 완독 기록을 집계합니다. 참여 이전의 해당 월 완독도 인정됩니다.',
      stageType: ChallengeStageType.single,
      category: ChallengeCategory.growth,
      method: ChallengeMethod.quantityBased,
      period: ChallengePeriod.periodBased,
      checkMode: ChallengeCheckMode.auto,
      theme: ChallengeTheme.habit,
      startDate: first,
      endDate: last,
      totalBooks: n,
      imageUrl: 'recurring://monthly',
      goalDisplayText: '${first.month}월 동안 $n권 완독',
      periodDisplayText: '${_ymd(first)} ~ ${_ymd(last)}',
    )).toList();
  }

  /// 현재 날짜의 주간 1개, 월간 2개. 과거 참여 기록은 Provider 병합으로 유지해야 한다.
  static List<Challenge> current(DateTime now) => [weekly(now), ...monthly(now)];
}
