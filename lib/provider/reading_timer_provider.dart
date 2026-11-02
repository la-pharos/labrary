import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dayverse_book/model/book_model.dart';

class ReadingTimerSnapshot {
  final BookModel book;
  final DateTime startTime;
  final DateTime endTime;
  final int elapsedSeconds;
  final int durationMinutes;

  const ReadingTimerSnapshot({
    required this.book,
    required this.startTime,
    required this.endTime,
    required this.elapsedSeconds,
    required this.durationMinutes,
  });
}

/// 앱이 종료되기 전에 저장해 둔 타이머 세션 정보
class SavedReadingTimerSession {
  final String bookId;
  final DateTime startTime;
  final Duration pausedTotal;
  final DateTime? pausedAt;
  final bool isPaused;
  final int elapsedSeconds;

  const SavedReadingTimerSession({
    required this.bookId,
    required this.startTime,
    required this.pausedTotal,
    required this.pausedAt,
    required this.isPaused,
    required this.elapsedSeconds,
  });

  /// 실제 독서 경과 시간이 3시간 이상인지
  bool get requiresConfirmation {
    return elapsedSeconds >= const Duration(hours: 3).inSeconds;
  }
}

class ReadingTimerProvider extends ChangeNotifier {
  static const String _bookIdKey = 'reading_timer_book_id';
  static const String _startTimeKey = 'reading_timer_start_time';
  static const String _pausedTotalKey = 'reading_timer_paused_total';
  static const String _pausedAtKey = 'reading_timer_paused_at';
  static const String _isPausedKey = 'reading_timer_is_paused';

  Timer? _ticker;

  BookModel? _currentBook;
  DateTime? _startTime;
  Duration _pausedTotal = Duration.zero;
  DateTime? _pausedAt;

  int _elapsedSeconds = 0;
  bool _isPaused = false;

  BookModel? get currentBook => _currentBook;
  DateTime? get startTime => _startTime;
  int get elapsedSeconds => _elapsedSeconds;
  bool get isPaused => _isPaused;

  bool get isRunning => _currentBook != null && _startTime != null;
  bool get hasActiveSession => isRunning;

  bool isCurrentBook(String bookId) {
    return _currentBook?.id == bookId;
  }

  void startSession(BookModel book) {
    if (isRunning) return;

    _currentBook = book;
    _startTime = DateTime.now();
    _pausedTotal = Duration.zero;
    _pausedAt = null;
    _elapsedSeconds = 0;
    _isPaused = false;

    _startTicker();

    // 타이머 시작 상태를 기기에 저장
    unawaited(_saveSession());

    notifyListeners();
  }

  void attachIfNeeded() {
    if (!isRunning) return;

    if (!_isPaused && _ticker == null) {
      _startTicker();
    }

    _recomputeSeconds();
    notifyListeners();
  }

  void togglePause() {
    if (!isRunning) return;

    final now = DateTime.now();

    if (_isPaused) {
      // 일시정지 해제
      if (_pausedAt != null) {
        _pausedTotal += now.difference(_pausedAt!);
        _pausedAt = null;
      }

      _isPaused = false;
      _startTicker();
    } else {
      // 일시정지 시작
      _recomputeSeconds();

      _pausedAt = now;
      _isPaused = true;

      _ticker?.cancel();
      _ticker = null;
    }

    _recomputeSeconds();

    // 일시정지 상태도 기기에 저장
    unawaited(_saveSession());

    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused) {
        _recomputeSeconds();
        notifyListeners();
      }
    });
  }

  void _recomputeSeconds() {
    if (_startTime == null) {
      _elapsedSeconds = 0;
      return;
    }

    final now = DateTime.now();

    final pausedExtra = _pausedAt != null
        ? now.difference(_pausedAt!)
        : Duration.zero;

    final elapsed =
        now.difference(_startTime!) - _pausedTotal - pausedExtra;

    _elapsedSeconds = elapsed.isNegative ? 0 : elapsed.inSeconds;
  }

  ReadingTimerSnapshot? stopSession() {
    if (!isRunning || _currentBook == null || _startTime == null) {
      return null;
    }

    _ticker?.cancel();
    _ticker = null;

    _recomputeSeconds();

    final snapshot = ReadingTimerSnapshot(
      book: _currentBook!,
      startTime: _startTime!,
      endTime: DateTime.now(),
      elapsedSeconds: _elapsedSeconds,
      durationMinutes: (_elapsedSeconds / 60).round(),
    );

    _resetSession();

    // 정상 종료했으므로 저장된 세션도 삭제
    unawaited(clearSavedSession());

    notifyListeners();

    return snapshot;
  }

  void cancelSessionSilently() {
    _ticker?.cancel();
    _ticker = null;

    _resetSession();

    // 기록 없이 종료했으므로 저장된 세션 삭제
    unawaited(clearSavedSession());

    notifyListeners();
  }

  void _resetSession() {
    _currentBook = null;
    _startTime = null;
    _pausedTotal = Duration.zero;
    _pausedAt = null;
    _elapsedSeconds = 0;
    _isPaused = false;
  }

  /// 현재 타이머 상태를 기기에 저장
  Future<void> _saveSession() async {
    if (_currentBook == null || _startTime == null) return;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _bookIdKey,
      _currentBook!.id,
    );

    await prefs.setString(
      _startTimeKey,
      _startTime!.toIso8601String(),
    );

    await prefs.setInt(
      _pausedTotalKey,
      _pausedTotal.inMilliseconds,
    );

    if (_pausedAt != null) {
      await prefs.setString(
        _pausedAtKey,
        _pausedAt!.toIso8601String(),
      );
    } else {
      await prefs.remove(_pausedAtKey);
    }

    await prefs.setBool(
      _isPausedKey,
      _isPaused,
    );
  }

  /// 앱 재실행 시 저장된 타이머 세션 읽기
  Future<SavedReadingTimerSession?> readSavedSession() async {
    final prefs = await SharedPreferences.getInstance();

    final bookId = prefs.getString(_bookIdKey);
    final startTimeString = prefs.getString(_startTimeKey);

    if (bookId == null || startTimeString == null) {
      return null;
    }

    final startTime = DateTime.tryParse(startTimeString);

    if (startTime == null) {
      await clearSavedSession();
      return null;
    }

    final pausedTotalMilliseconds =
        prefs.getInt(_pausedTotalKey) ?? 0;

    final pausedTotal = Duration(
      milliseconds: pausedTotalMilliseconds,
    );

    final pausedAtString = prefs.getString(_pausedAtKey);

    final pausedAt = pausedAtString == null
        ? null
        : DateTime.tryParse(pausedAtString);

    final isPaused = prefs.getBool(_isPausedKey) ?? false;

    final now = DateTime.now();

    final pausedExtra = isPaused && pausedAt != null
        ? now.difference(pausedAt)
        : Duration.zero;

    final elapsed =
        now.difference(startTime) - pausedTotal - pausedExtra;

    final elapsedSeconds =
    elapsed.isNegative ? 0 : elapsed.inSeconds;

    return SavedReadingTimerSession(
      bookId: bookId,
      startTime: startTime,
      pausedTotal: pausedTotal,
      pausedAt: pausedAt,
      isPaused: isPaused,
      elapsedSeconds: elapsedSeconds,
    );
  }

  /// 저장된 타이머를 현재 Provider에 복원
  void restoreSession({
    required BookModel book,
    required SavedReadingTimerSession savedSession,
  }) {
    if (isRunning) return;

    _currentBook = book;
    _startTime = savedSession.startTime;
    _pausedTotal = savedSession.pausedTotal;
    _pausedAt = savedSession.pausedAt;
    _elapsedSeconds = savedSession.elapsedSeconds;
    _isPaused = savedSession.isPaused;

    if (!_isPaused) {
      _startTicker();
    }

    notifyListeners();
  }

  /// 기기에 저장된 타이머 세션 삭제
  Future<void> clearSavedSession() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_bookIdKey);
    await prefs.remove(_startTimeKey);
    await prefs.remove(_pausedTotalKey);
    await prefs.remove(_pausedAtKey);
    await prefs.remove(_isPausedKey);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
