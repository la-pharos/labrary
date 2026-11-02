import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:dayverse_book/model/weekly_reading_summary.dart';
import 'package:dayverse_book/service/reading_log_service.dart';

class ReadingStatsProvider extends ChangeNotifier {
  WeeklyReadingSummary _weeklySummary =
  WeeklyReadingSummary.empty();

  Map<String, int> _dailyReadingMinutes = {};

  int _totalReadingMinutes = 0;
  int _totalReadingSessions = 0;
  int _longestStreakDays = 0;

  bool _isLoading = false;
  bool _isLoaded = false;
  String? _errorMessage;

  WeeklyReadingSummary get weeklySummary =>
      _weeklySummary;

  Map<String, int> get dailyReadingMinutes =>
      Map.unmodifiable(_dailyReadingMinutes);

  int get totalReadingMinutes =>
      _totalReadingMinutes;

  int get totalReadingSessions =>
      _totalReadingSessions;

  int get longestStreakDays =>
      _longestStreakDays;

  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  /// 독서 통계를 Firestore에서 다시 불러와 계산한다.
  Future<void> refresh() async {
    final user = FirebaseAuth.instance.currentUser;

    // 로그아웃 상태라면 기존 데이터 제거
    if (user == null) {
      clear();
      return;
    }

    if (_isLoading) return;

    final String requestedUid = user.uid;

    // 새 계정 데이터를 불러오기 전에
    // 기존 계정 통계를 먼저 제거한다.
    _weeklySummary =
        WeeklyReadingSummary.empty();
    _dailyReadingMinutes = {};
    _totalReadingMinutes = 0;
    _totalReadingSessions = 0;
    _longestStreakDays = 0;
    _isLoading = false;
    _isLoaded = false;
    _errorMessage = null;

    notifyListeners();

    try {
      final results = await Future.wait([
        ReadingLogService
            .getTotalReadingMinutesByDate(),
        ReadingLogService
            .getTotalReadingMinutes(),
        ReadingLogService
            .getTotalReadingSessions(),
      ]);

      final dailyMinutes =
      results[0] as Map<String, int>;

      final totalReadingMinutes =
      results[1] as int;

      final totalReadingSessions =
      results[2] as int;

      // 데이터를 불러오는 도중 로그아웃하거나
      // 다른 계정으로 변경됐다면 결과를 반영하지 않는다.
      if (FirebaseAuth.instance.currentUser?.uid !=
          requestedUid) {
        return;
      }

      _dailyReadingMinutes = dailyMinutes;
      _totalReadingMinutes =
          totalReadingMinutes;
      _totalReadingSessions =
          totalReadingSessions;

      _longestStreakDays =
          _calculateLongestStreakDays(
            dailyMinutes: dailyMinutes,
          );

      _weeklySummary = _createWeeklySummary(
        dailyMinutes: dailyMinutes,
        now: DateTime.now(),
      );

      _isLoaded = true;
    } catch (e, stackTrace) {
      debugPrint(
        '[ReadingStatsProvider] 독서 통계 로드 실패: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      // 여전히 같은 계정일 때만 오류 상태 반영
      if (FirebaseAuth.instance.currentUser?.uid ==
          requestedUid) {
        _weeklySummary =
            WeeklyReadingSummary.empty();
        _dailyReadingMinutes = {};
        _totalReadingMinutes = 0;
        _totalReadingSessions = 0;
        _isLoaded = false;
        _errorMessage =
        '독서 통계를 불러오지 못했습니다.';
      }
    } finally {
      // 요청을 시작한 계정과 현재 계정이 같을 때만
      // 로딩 상태를 종료한다.
      if (FirebaseAuth.instance.currentUser?.uid ==
          requestedUid) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  WeeklyReadingSummary _createWeeklySummary({
    required Map<String, int> dailyMinutes,
    required DateTime now,
  }) {
    final today = _dateOnly(now);

    // 이번 주 월요일
    final thisWeekStart = today.subtract(
      Duration(
        days: today.weekday - DateTime.monday,
      ),
    );

    // 지난주 월요일
    final lastWeekStart = thisWeekStart.subtract(
      const Duration(days: 7),
    );

    final thisWeekDailyMinutes =
    List<int>.generate(
      7,
          (index) {
        final date = thisWeekStart.add(
          Duration(days: index),
        );

        return dailyMinutes[
        _formatDateKey(date)] ??
            0;
      },
      growable: false,
    );

    final lastWeekDailyMinutes =
    List<int>.generate(
      7,
          (index) {
        final date = lastWeekStart.add(
          Duration(days: index),
        );

        return dailyMinutes[
        _formatDateKey(date)] ??
            0;
      },
      growable: false,
    );

    final thisWeekMinutes =
    thisWeekDailyMinutes.fold<int>(
      0,
          (sum, minutes) => sum + minutes,
    );

    final lastWeekMinutes =
    lastWeekDailyMinutes.fold<int>(
      0,
          (sum, minutes) => sum + minutes,
    );

    final todayMinutes =
        dailyMinutes[_formatDateKey(today)] ?? 0;

    return WeeklyReadingSummary(
      streakDays: _calculateStreakDays(
        dailyMinutes: dailyMinutes,
        today: today,
      ),
      thisWeekMinutes: thisWeekMinutes,
      lastWeekMinutes: lastWeekMinutes,
      dailyMinutes: thisWeekDailyMinutes,
      hasReadToday: todayMinutes > 0,
    );
  }

  /// 현재 유지 중인 연속 독서 일수를 계산한다.
  int _calculateStreakDays({
    required Map<String, int> dailyMinutes,
    required DateTime today,
  }) {
    final hasReadToday =
        (dailyMinutes[
        _formatDateKey(today)] ??
            0) >
            0;

    DateTime cursor = hasReadToday
        ? today
        : today.subtract(
      const Duration(days: 1),
    );

    int streakDays = 0;

    while (true) {
      final minutes =
          dailyMinutes[
          _formatDateKey(cursor)] ??
              0;

      if (minutes <= 0) {
        break;
      }

      streakDays++;

      cursor = cursor.subtract(
        const Duration(days: 1),
      );
    }

    return streakDays;
  }

  /// 지금까지의 최장 연속 독서 일수를 계산한다.
  int _calculateLongestStreakDays({
    required Map<String, int> dailyMinutes,
  }) {
    final readingDates = dailyMinutes.entries
        .where((entry) => entry.value > 0)
        .map((entry) => DateTime.parse(entry.key))
        .toList()
      ..sort();

    if (readingDates.isEmpty) {
      return 0;
    }

    int longestStreak = 1;
    int currentStreak = 1;

    for (int i = 1; i < readingDates.length; i++) {
      final previousDate =
      _dateOnly(readingDates[i - 1]);

      final currentDate =
      _dateOnly(readingDates[i]);

      final difference =
          currentDate.difference(previousDate).inDays;

      if (difference == 1) {
        currentStreak++;

        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
        }
      } else if (difference > 1) {
        currentStreak = 1;
      }
    }

    return longestStreak;
  }

  /// 지정한 날짜의 총 독서 시간
  int getMinutesForDate(DateTime date) {
    return _dailyReadingMinutes[
    _formatDateKey(date)] ??
        0;
  }

  /// 지정한 날짜에 독서 기록이 있는지
  bool hasReadOnDate(DateTime date) {
    return getMinutesForDate(date) > 0;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// 로그아웃이나 계정 변경 시 기존 통계 초기화
  void clear() {
    _weeklySummary =
        WeeklyReadingSummary.empty();
    _dailyReadingMinutes = {};
    _totalReadingMinutes = 0;
    _totalReadingSessions = 0;
    _longestStreakDays = 0;
    _isLoading = false;
    _isLoaded = false;
    _errorMessage = null;

    notifyListeners();
  }


}
