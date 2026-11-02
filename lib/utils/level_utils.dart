import 'package:flutter/material.dart';

class LevelInfo {
  final String name;
  final String icon;
  final String description;
  final Color color;
  final int start;
  final int? end;

  const LevelInfo({
    required this.name,
    required this.icon,
    required this.description,
    required this.color,
    required this.start,
    this.end,
  });

  bool contains(int readCount) {
    return readCount >= start && (end == null || readCount <= end!);
  }

  String get rangeText {
    if (end == null) {
      return '$start권 이상';
    }

    if (start == end) {
      return '$start권';
    }

    return '$start~$end권';
  }
}

class LevelUtils {
  static const List<LevelInfo> _levels = [
    LevelInfo(
      name: '독서 새싹',
      icon: '🌱',
      description: '아직 펼쳐보지 않은 수많은 이야기가 기다리고 있습니다.',
      color: Color(0xFF81C784),
      start: 0,
      end: 0,
    ),
    LevelInfo(
      name: '첫 완독',
      icon: '📖',
      description: '한 권의 책을 끝까지 읽으며 첫 번째 기록을 남겼습니다.',
      color: Color(0xFF66BB6A),
      start: 1,
      end: 1,
    ),
    LevelInfo(
      name: '책갈피',
      icon: '🔖',
      description: '한 권씩 책장을 넘기며 독서의 즐거움을 알아가고 있습니다.',
      color: Color(0xFF26A69A),
      start: 2,
      end: 4,
    ),
    LevelInfo(
      name: '독서 입문자',
      icon: '🌿',
      description: '독서가 조금씩 일상 속에 자리 잡기 시작했습니다.',
      color: Color(0xFF009688),
      start: 5,
      end: 9,
    ),
    LevelInfo(
      name: '독서가',
      icon: '📚',
      description: '꾸준히 책을 읽으며 자신만의 독서 습관을 만들어가고 있습니다.',
      color: Color(0xFF00897B),
      start: 10,
      end: 19,
    ),
    LevelInfo(
      name: '탐독가',
      icon: '🧭',
      description: '다양한 책을 탐색하며 관심과 시야를 넓혀가고 있습니다.',
      color: Color(0xFF0288D1),
      start: 20,
      end: 34,
    ),
    LevelInfo(
      name: '애서가',
      icon: '💙',
      description: '책을 가까이하며 독서가 삶의 중요한 부분이 되었습니다.',
      color: Color(0xFF3F51B5),
      start: 35,
      end: 49,
    ),
    LevelInfo(
      name: '장서가',
      icon: '🗄️',
      description: '쌓여가는 책과 기록이 하나의 깊이 있는 서재를 이루고 있습니다.',
      color: Color(0xFF5C6BC0),
      start: 50,
      end: 74,
    ),
    LevelInfo(
      name: '지식 수집가',
      icon: '✨',
      description: '책 속의 지식과 경험을 모아 자신만의 세계를 넓혀가고 있습니다.',
      color: Color(0xFF7E57C2),
      start: 75,
      end: 99,
    ),
    LevelInfo(
      name: '서재지기',
      icon: '🦉',
      description: '백 권의 이야기가 쌓여 단단하고 깊은 독서 세계를 이루었습니다.',
      color: Color(0xFF673AB7),
      start: 100,
      end: 149,
    ),
    LevelInfo(
      name: '기록자',
      icon: '📜',
      description: '오랜 독서의 흔적을 기록하며 생각과 경험을 축적하고 있습니다.',
      color: Color(0xFF8E24AA),
      start: 150,
      end: 249,
    ),
    LevelInfo(
      name: '사색가',
      icon: '🌌',
      description: '수많은 책을 바탕으로 세상과 삶을 깊이 사유합니다.',
      color: Color(0xFF3949AB),
      start: 250,
      end: 399,
    ),
    LevelInfo(
      name: '현자',
      icon: '🔮',
      description: '축적된 지식과 통찰로 자신만의 관점과 철학을 세웠습니다.',
      color: Color(0xFF283593),
      start: 400,
      end: 599,
    ),
    LevelInfo(
      name: '대현자',
      icon: '👑',
      description: '오랜 독서를 통해 지식과 경험을 자유롭게 연결합니다.',
      color: Color(0xFF4527A0),
      start: 600,
      end: 999,
    ),
    LevelInfo(
      name: '살아있는 도서관',
      icon: '🏛️',
      description: '수많은 책의 지식과 이야기가 하나의 거대한 세계를 이루었습니다.',
      color: Color(0xFF212121),
      start: 1000,
    ),
  ];

  static List<LevelInfo> getAllLevels([int? readCount]) {
    return List.unmodifiable(_levels);
  }

  static LevelInfo getCurrentLevel(int readCount) {
    final safeReadCount = readCount < 0 ? 0 : readCount;

    return _levels.firstWhere(
          (level) => level.contains(safeReadCount),
      orElse: () => _levels.last,
    );
  }

  static LevelInfo? getNextLevel(int readCount) {
    final currentLevel = getCurrentLevel(readCount);
    final currentIndex = _levels.indexOf(currentLevel);

    if (currentIndex >= _levels.length - 1) {
      return null;
    }

    return _levels[currentIndex + 1];
  }

  static int getBooksUntilNextLevel(int readCount) {
    final safeReadCount = readCount < 0 ? 0 : readCount;
    final nextLevel = getNextLevel(safeReadCount);

    if (nextLevel == null) {
      return 0;
    }

    return nextLevel.start - safeReadCount;
  }

  static double getLevelProgress(int readCount) {
    final safeReadCount = readCount < 0 ? 0 : readCount;
    final currentLevel = getCurrentLevel(safeReadCount);
    final nextLevel = getNextLevel(safeReadCount);

    if (nextLevel == null) {
      return 1.0;
    }

    final levelRange = nextLevel.start - currentLevel.start;
    final currentProgress = safeReadCount - currentLevel.start;

    if (levelRange <= 0) {
      return 1.0;
    }

    return (currentProgress / levelRange).clamp(0.0, 1.0);
  }

  static Widget buildLevelIcon(
      LevelInfo level, {
        double size = 36,
      }) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          level.icon,
          style: TextStyle(
            fontSize: size * 0.75,
            height: 1,
          ),
        ),
      ),
    );
  }
}
