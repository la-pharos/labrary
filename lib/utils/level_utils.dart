import 'package:flutter/material.dart';

class LevelInfo {
  final String name;
  final String description;
  final Color color;
  final int start;
  final int end;

  LevelInfo({
    required this.name,
    required this.description,
    required this.color,
    required this.start,
    required this.end,
  });
}

class LevelUtils {
  static List<LevelInfo> getAllLevels(int readCount) {
    final levels = [
      LevelInfo(
        name: "🥉 브론즈",
        description: "이제 독서의 첫 발걸음을 내딛었습니다.",
        color: Colors.brown.shade300,
        start: 0,
        end: 4,
      ),
      LevelInfo(
        name: "🥈 실버",
        description: "조금씩 독서 습관을 길들이며 나만의 페이스를 찾고 있습니다.",
        color: Colors.grey,
        start: 5,
        end: 9,
      ),
      LevelInfo(
        name: "🥇 골드",
        description: "독서가 어느덧 일상이 된 당신, 생각의 폭이 넓어집니다.",
        color: Colors.amber.shade600,
        start: 10,
        end: 19,
      ),
      LevelInfo(
        name: "🔷 플래티넘",
        description: "다양한 책을 넘나들며 세상을 새롭게 바라봅니다.",
        color: Colors.blue.shade200,
        start: 20,
        end: 29,
      ),
      LevelInfo(
        name: "💎 다이아몬드",
        description: "글과 삶을 연결하는 통찰력이 빛나기 시작합니다.",
        color: Colors.cyan.shade400,
        start: 30,
        end: 39,
      ),
      LevelInfo(
        name: "🛡 에이스",
        description: "독서가 취미를 넘어 하나의 무기가 된 시점입니다.",
        color: Colors.indigo.shade400,
        start: 40,
        end: 49,
      ),
      LevelInfo(
        name: "🎯 엘리트",
        description: "지식을 체계화하고 나만의 철학을 쌓아갑니다.",
        color: Colors.deepPurple.shade300,
        start: 50,
        end: 59,
      ),
      LevelInfo(
        name: "🚀 프로디지",
        description: "날카로운 통찰과 창의적 시선이 돋보입니다.",
        color: Colors.pink.shade300,
        start: 60,
        end: 69,
      ),
      LevelInfo(
        name: "🏆 챔피언",
        description: "자신의 생각을 풀어내며 주변에 영감을 줍니다.",
        color: Colors.deepOrange.shade300,
        start: 70,
        end: 79,
      ),
      LevelInfo(
        name: "🦉 마스터",
        description: "깊이 있는 독서를 통해 지식과 관점을 유연하게 통합할 수 있는 단계입니다.",
        color: const Color(0xFFBDBDBD),
        start: 80,
        end: 89,
      ),
      LevelInfo(
        name: "🌟 에픽",
        description: "당신의 통찰은 남다른 무게와 깊이를 갖습니다.",
        color: Colors.amber.shade800,
        start: 90,
        end: 99,
      ),
      LevelInfo(
        name: "🐉 레전드",
        description: "수많은 책을 통해 쌓아온 통찰은 이제 단단한 지혜가 되어, 누군가의 길을 밝히는 등불이 됩니다.",
        color: const Color(0xFF212121),
        start: 100,
        end: 109,
      ),
    ];

    // 🔁 전설 이후의 단계 (110부터 10권 단위로 증가)
    if (readCount >= 110) {
      int extra = ((readCount - 110) / 10).ceil();
      for (int i = 1; i <= extra; i++) {
        int start = 110 + (i - 1) * 10;
        int end = start + 9;
        levels.add(LevelInfo(
          name: "🐉 레전드 ${i + 1}그랄",
          description: "끝없는 여정을 걷는 자",
          color: Colors.red.shade700,
          start: start,
          end: end,
        ));
      }
    }

    return levels;
  }

  static Widget buildShieldIcon(LevelInfo level) {
    if (level.name.contains("레전드")) {
      return ShaderMask(
        shaderCallback: (bounds) {
          return const LinearGradient(
            colors: [Colors.black, Colors.red],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds);
        },
        child: const Icon(Icons.shield, size: 36, color: Colors.white),
      );
    } else {
      return Icon(Icons.shield, color: level.color, size: 36);
    }
  }

  static LevelInfo getCurrentLevel(int readCount) {
    final allLevels = getAllLevels(readCount);

    for (final level in allLevels) {
      if (readCount >= level.start && readCount <= level.end) return level;
    }

    return LevelInfo(
      name: "알 수 없음",
      description: "레벨 정보를 찾을 수 없습니다",
      color: Colors.grey,
      start: 0,
      end: 0,
    );
  }
}
