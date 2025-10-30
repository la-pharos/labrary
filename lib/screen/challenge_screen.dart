import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/main.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/provider/user_data_provider.dart';
import 'package:dayverse_book/screen/challenge_detail_screen.dart';
import 'package:dayverse_book/screen/challenge_ongoing_screen.dart';
import 'package:dayverse_book/screen/challenge_create_screen.dart';
import 'package:dayverse_book/widget/ad_banner_placeholder.dart';

class ChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final VoidCallback? onTap;
  final bool showAttemptsBadge;

  const ChallengeCard({
    super.key,
    required this.challenge,
    this.onTap,
    this.showAttemptsBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final latestChallenge = context.watch<ChallengeProvider>().findChallengeById(challenge.id) ?? challenge;
    final completedCount = latestChallenge.attempts.where((a) => a.completed).length;
    final completedStages = completedCount;
    final totalStages = latestChallenge.stageDurations.length; // 기본 0이면 1로 보이고 싶으면 max(1, ...) 처리
    final isStageBased = latestChallenge.stageType == ChallengeStageType.staged;
    final showRepeatBadge = showAttemptsBadge && latestChallenge.isRepeatable && completedCount > 0;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          /// 📦 메인 카드
          Container(
            margin: EdgeInsets.only(bottom: screenHeight * 0.015),
            padding: EdgeInsets.all(screenWidth * 0.025),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(screenWidth * 0.03),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(screenWidth * 0.02),
                  child: Image.asset(
                    latestChallenge.imageUrl,
                    width: screenWidth * 0.14,
                    height: screenWidth * 0.14,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: screenWidth * 0.15,
                      height: screenWidth * 0.15,
                      color: Colors.grey,
                      child: const Icon(Icons.flag, color: Colors.white),
                    ),
                  ),
                ),
                SizedBox(width: screenWidth * 0.03),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latestChallenge.title,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'kopub',
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.005),
                      Text(
                        latestChallenge.shortDescription,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style: TextStyle(
                          fontFamily: 'kopub',
                          color: Colors.white70,
                          fontSize: screenWidth * 0.033,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          /// 🎖️ 뱃지: 스테이지 / 반복 / 프리미엄
          if (isStageBased && completedStages > 0)
            Positioned(
              top: screenHeight * 0.005,
              right: screenWidth * 0.02,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.02,
                  vertical: screenHeight * 0.005,
                ),
                decoration: BoxDecoration(
                  color: Colors.greenAccent,
                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                ),
                child: Text(
                  "🚀 $completedStages / $totalStages 스테이지",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: screenWidth * 0.025,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'kopub',
                  ),
                ),
              ),
            )
          else if (showRepeatBadge)
            Positioned(
              top: screenHeight * 0.005,
              right: screenWidth * 0.02,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.02,
                  vertical: screenHeight * 0.005,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepOrangeAccent,
                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                ),
                child: Text(
                  "🏅 $completedCount회 달성",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: screenWidth * 0.025,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'kopub',
                  ),
                ),
              ),
            )
          else if (latestChallenge.isPremium)
              Positioned(
                top: screenHeight * 0.005,
                right: screenWidth * 0.02,
                child: _PremiumBadge(screenWidth: screenWidth, screenHeight: screenHeight),
              ),
        ],
      ),
    );
  }
}

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {

  ChallengeTheme? _selectedTheme;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final savedBooks = context.read<SavedBooksProvider>().savedBooks;
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      await context.read<ChallengeProvider>().refreshAllStatuses(
        savedBooks: savedBooks,
        userId: userId,
      );
    });
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth  = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final challengeProvider = context.watch<ChallengeProvider>();

    // 진행/미참여/완료 목록
    final joined      = challengeProvider.joinedChallenges;
    final notJoined   = challengeProvider.notJoinedChallenges;
    final completed   = challengeProvider.completedChallenges; // 없으면 Provider에 추가 or []로 대체

    // ✅ 칩 후보는 "전체 챌린지"에서 theme가 있는 것만 모음
    final List<Challenge> all = [
      ...joined,
      ...notJoined,
      ...completed,
    ];

    // ✅ 칩 목록
    final availableThemes = [
      ...joined, ...notJoined, ...completed,
    ].map((c) => c.theme)
        .whereType<ChallengeTheme>()   // null 제거
        .toSet()
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    // ✅ 실제 리스트는 "참여 가능(notJoined)" + 선택 테마 필터
    final filteredNotJoined = _selectedTheme == null
        ? notJoined
        : notJoined.where((c) => c.theme == _selectedTheme).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF013328),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: screenHeight * 0.065),
          _buildTopBar(screenWidth),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: screenHeight * 0.01,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  //뭐 있으면 좋을 듯.
                  SizedBox(height: screenHeight * 0.02),
                  Text("🔥 진행 중인 챌린지 🔥",
                      style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontFamily: 'kopub',
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  SizedBox(height: screenHeight * 0.015),
                  if (joined.isEmpty)
                    _buildPlaceholderBox("진행 중인 챌린지가 없습니다.", screenWidth)
                  else
                    Column(
                      children: joined.map((c) => GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                              builder: (_) => ChallengeOngoingScreen(challenge: c)));
                        },
                        child: ChallengeCard(challenge: c, showAttemptsBadge: true),
                      )).toList(),
                    ),
                  const Divider(color: Colors.white24, thickness: 1),
                  SizedBox(height: screenHeight * 0.01),
                  Text("챌린지 생성하기",
                      style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontFamily: 'kopub',
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  SizedBox(height: screenHeight * 0.015),

                  CreateChallengeCard(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChallengeCreateScreen()),
                      );

                      if (result is Challenge) {
                        final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
                        await context.read<ChallengeProvider>().addCustomChallenge(
                          userId: userId,
                          custom: result,
                        );
                        // 진행중인 챌린지 화면으로 이동할지, 그냥 목록에 표시만 할지 결정
                      }
                    },
                  ),

                  const Divider(color: Colors.white24, thickness: 1),
                  SizedBox(height: screenHeight * 0.01),
                  Text("챌린지 참여하기",
                      style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontFamily: 'kopub',
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  SizedBox(height: screenHeight * 0.012),

                  // ⬇️ 테마 칩들
                  _buildThemeChips(screenWidth, availableThemes),

                  SizedBox(height: screenHeight * 0.015),

                  // ⬇️ 필터링된 리스트
                  if (filteredNotJoined.isEmpty)
                    _buildPlaceholderBox("해당 테마의 챌린지가 없습니다.", screenWidth)
                  else
                    Column(
                      children: filteredNotJoined.map((c) => GestureDetector(
                        onTap: () {
                          Navigator.push(context,
                              MaterialPageRoute(builder: (_) => ChallengeDetailScreen(challenge: c)));
                        },
                        child: ChallengeCard(challenge: c, showAttemptsBadge: true),
                      )).toList(),
                    ),
                  SizedBox(height: screenHeight * 0.05),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.05,
        vertical: screenWidth * 0.0055,
      ),
      child: Text(
        "CHALLENGE",
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'kopub',
          fontSize: screenWidth * 0.045,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildPlaceholderBox(String text, double screenWidth) {
    return Container(
      margin: EdgeInsets.only(bottom: screenWidth * 0.03),
      padding: EdgeInsets.all(screenWidth * 0.025),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: screenWidth * 0.14,
            height: screenWidth * 0.14,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(screenWidth * 0.02),
            ),
            child: const Icon(Icons.hourglass_empty, color: Colors.white70),
          ),
          SizedBox(width: screenWidth * 0.04),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: screenWidth * 0.035,
                fontFamily: 'kopub',
                fontWeight: FontWeight.w300,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ChallengeTheme t) {
    switch (t) {
      case ChallengeTheme.habit:       return '습관';
      case ChallengeTheme.selfGrowth:  return '자기개발';
      case ChallengeTheme.study:       return '학습';
      case ChallengeTheme.language:    return '언어';
      case ChallengeTheme.career:      return '커리어';
      case ChallengeTheme.society:     return '사회';
      case ChallengeTheme.hobby:       return '취미';
      case ChallengeTheme.philosophy:  return '철학';
      case ChallengeTheme.mind:  return '정신';
      case ChallengeTheme.etc:         return '기타';
    }
  }

  IconData _themeIcon(ChallengeTheme t) {
    switch (t) {
      case ChallengeTheme.habit:       return Icons.local_fire_department; // 🔥
      case ChallengeTheme.selfGrowth:  return Icons.trending_up;           // 🌱
      case ChallengeTheme.study:       return Icons.menu_book;             // 📚
      case ChallengeTheme.language:    return Icons.record_voice_over;     // 🗣️
      case ChallengeTheme.career:      return Icons.work;                  // 💼
      case ChallengeTheme.society:     return Icons.account_balance;       // 🏛️
      case ChallengeTheme.hobby:       return Icons.palette;               // 🎨
      case ChallengeTheme.philosophy:  return Icons.psychology_alt;        // 🤔
      case ChallengeTheme.mind:  return Icons.psychology_sharp;        // 🤔
      case ChallengeTheme.etc:         return Icons.add_rounded;              // 📌
    }
  }

  Widget _buildThemeChips(double screenWidth, List<ChallengeTheme> availableThemes) {
    final unselectedBg = Color(0xFF013328).withOpacity(0.7);
    final unselectedBorder = Color(0xFF013328).withOpacity(0.4);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // 전체 칩
          Padding(
            padding: EdgeInsets.only(right: screenWidth * 0.02),
            child: ChoiceChip(
              selected: _selectedTheme == null,
              showCheckmark: false,
              label: const Text('전체'),
              avatar: const Icon(Icons.apps_rounded, size: 20, color: Colors.black),
              onSelected: (_) => setState(() => _selectedTheme = null),

              // ✅ 스타일
              selectedColor: Colors.amberAccent,          // 선택된 칩 배경
              backgroundColor: unselectedBg,               // 비선택 배경
              side: BorderSide(color: unselectedBorder),   // 얇은 보더 유지
              labelStyle: const TextStyle(
                color: Colors.black,                       // 항상 검정 텍스트
                fontFamily: 'kopub',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
              shape: const StadiumBorder(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),

          // 사용 가능한 테마 칩들
          ...availableThemes.map((t) {
            final selected = _selectedTheme == t;
            return Padding(
              padding: EdgeInsets.only(right: screenWidth * 0.02),
              child: ChoiceChip(
                selected: selected,
                showCheckmark: false,
                label: Text(_themeLabel(t)),
                avatar: Icon(_themeIcon(t), size: 20, color: Colors.black),
                onSelected: (_) => setState(() => _selectedTheme = t),

                // ✅ 스타일
                selectedColor: Colors.amberAccent,
                backgroundColor: unselectedBg,
                side: BorderSide(color: unselectedBorder),
                labelStyle: const TextStyle(
                  color: Colors.black,                     // 항상 검정 텍스트
                  fontFamily: 'kopub',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.2,
                ),
                shape: const StadiumBorder(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            );
          }),
        ],
      ),
    );
  }

}

class CreateChallengeCard extends StatelessWidget {
  final VoidCallback onTap;
  const CreateChallengeCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        // ✅ ChallengeCard와 동일한 여백/패딩/배경/라운드
        margin: EdgeInsets.only(bottom: screenHeight * 0.015),
        padding: EdgeInsets.all(screenWidth * 0.025),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(screenWidth * 0.03),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ ChallengeCard와 동일한 썸네일 영역 (이미지 대신 + 아이콘)
            ClipRRect(
              borderRadius: BorderRadius.circular(screenWidth * 0.02),
              child: Container(
                width: screenWidth * 0.14,
                height: screenWidth * 0.14,
                color: Colors.white24,
                child: const Icon(Icons.add, color: Colors.amberAccent, size: 28),
              ),
            ),
            SizedBox(width: screenWidth * 0.03),

            // ✅ 텍스트 영역도 동일한 타이포/라인수
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "커스텀 챌린지 생성하기",
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'kopub',
                      fontSize: screenWidth * 0.04,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.005),
                  Text(
                    "원하는 챌린지를 직접 만들어 보세요!",
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: TextStyle(
                      fontFamily: 'kopub',
                      color: Colors.white70,
                      fontSize: screenWidth * 0.033,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  final double screenWidth;
  final double screenHeight;

  const _PremiumBadge({super.key, required this.screenWidth, required this.screenHeight});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.02,
        vertical: screenHeight * 0.005,
      ),
      decoration: BoxDecoration(
        color: Colors.amberAccent,
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
      ),
      child: Text(
        "💎 Premium",
        style: TextStyle(
          color: Colors.black,
          fontSize: screenWidth * 0.025,
          fontWeight: FontWeight.bold,
          fontFamily: 'kopub',
        ),
      ),
    );
  }
}
