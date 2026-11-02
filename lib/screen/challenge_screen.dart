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
import 'package:dayverse_book/widget/card_box.dart';
import 'package:dayverse_book/core/theme/labrary_colors.dart';
import 'dart:io';
import 'package:dayverse_book/widget/recurring_challenge_cover.dart';

enum StageChipDisplayMode {
  ongoing,
  joinable,
  completed,
}

class ChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final VoidCallback? onTap;
  final bool showAttemptsBadge;
  final StageChipDisplayMode? stageChipDisplayMode;

  const ChallengeCard({
    super.key,
    required this.challenge,
    this.onTap,
    this.showAttemptsBadge = false,
    this.stageChipDisplayMode,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final latestChallenge = context.watch<ChallengeProvider>().findChallengeById(challenge.id) ?? challenge;
    final completedCount = latestChallenge.attempts
        .where((a) => a.completed && a.isSuccessful)
        .length;
    final totalStages = latestChallenge.stageDurations.length;
    final isStageBased = latestChallenge.stageType == ChallengeStageType.staged;
    final showRepeatBadge = showAttemptsBadge && latestChallenge.isRepeatable && completedCount > 0;

    final int? displayStageIndex = isStageBased
        ? _getDisplayStageIndex(latestChallenge, stageChipDisplayMode)
        : null;

    return Stack(
      children: [
          /// 📦 메인 카드
          CardBox(
            onTap: onTap,
            padding: EdgeInsets.all(screenWidth * 0.025),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(screenWidth * 0.02),
                  child: _buildChallengeImage(
                    latestChallenge,
                    screenWidth,
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
          if (isStageBased && displayStageIndex != null)
            Positioned(
              top: screenHeight * 0.005,
              right: screenWidth * 0.02,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.02,
                  vertical: screenHeight * 0.005,
                ),
                decoration: BoxDecoration(
                  color: Colors.amberAccent,
                  borderRadius: BorderRadius.circular(
                    screenWidth * 0.03,
                  ),
                ),
                child: Text(
                  '${displayStageIndex + 1} / $totalStages 스테이지',
                  style: TextStyle(
                    color: const Color(0xFF013328),
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
                  color: Colors.amberAccent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(
                    screenWidth * 0.03,
                  ),
                  border: Border.all(
                    color: Colors.amberAccent.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  '$completedCount회 달성',
                  style: TextStyle(
                    color: Colors.amberAccent,
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
    );
  }

  int? _getDisplayStageIndex(
      Challenge challenge,
      StageChipDisplayMode? mode,
      ) {
    if (challenge.stageType != ChallengeStageType.staged ||
        challenge.stageDurations.isEmpty ||
        challenge.attempts.isEmpty) {
      return null;
    }

    switch (mode) {
      case StageChipDisplayMode.ongoing:
        return _getOngoingStageIndex(challenge);

      case StageChipDisplayMode.joinable:
        return _getLastCompletedStageIndex(challenge);

      case StageChipDisplayMode.completed:
        return challenge.stageDurations.length - 1;

      default:
        if (challenge.isCompleted) {
          return challenge.stageDurations.length - 1;
        }
        if (challenge.isJoined) {
          return _getOngoingStageIndex(challenge);
        }
        return _getLastCompletedStageIndex(challenge);
    }
  }

  int _getOngoingStageIndex(Challenge challenge) {
    for (int i = challenge.attempts.length - 1; i >= 0; i--) {
      final attempt = challenge.attempts[i];
      if (!attempt.completed) {
        return (attempt.stageIndex ?? 0).clamp(0, challenge.stageDurations.length - 1);
      }
    }

    return _getLastCompletedStageIndex(challenge);
  }

  int _getLastCompletedStageIndex(Challenge challenge) {
    for (int i = challenge.attempts.length - 1; i >= 0; i--) {
      final attempt = challenge.attempts[i];
      if (attempt.completed && attempt.isSuccessful) {
        return (attempt.stageIndex ?? 0).clamp(0, challenge.stageDurations.length - 1);
      }
    }

    return 0;
  }


  Widget _buildChallengeImage(
      Challenge challenge,
      double screenWidth,
      ) {
    final size = screenWidth * 0.14;
    final url = challenge.imageUrl;

    // ✅ 정기 챌린지: Flutter 커버 자동 렌더링
    if (RecurringChallengeCover.supports(challenge)) {
      return SizedBox(
        width: size,
        height: size,
        child: RecurringChallengeCover(
          challenge: challenge,
        ),
      );
    }

    // ✅ 이미지 경로 없음
    if (url.isEmpty) {
      return _errorImage(screenWidth);
    }

    // ✅ 네트워크 이미지
    if (url.startsWith('http')) {
      return Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _errorImage(screenWidth),
      );
    }

    // ✅ 에셋 이미지
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _errorImage(screenWidth),
      );
    }

    // ✅ 로컬 파일 이미지
    return Image.file(
      File(url),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          _errorImage(screenWidth),
    );
  }

  Widget _errorImage(double screenWidth) {
    return Container(
      width: screenWidth * 0.14,
      height: screenWidth * 0.14,
      color: Colors.grey,
      child: const Icon(Icons.flag, color: Colors.white),
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

    Future.microtask(
          () async {
        final savedBooks =
            context
                .read<
                SavedBooksProvider
            >()
                .savedBooks;

        final userId =
            FirebaseAuth
                .instance
                .currentUser
                ?.uid ??
                '';

        final provider =
        context.read<
            ChallengeProvider
        >();

        await provider
            .refreshAllStatuses(
          savedBooks:
          savedBooks,
          userId:
          userId,
        );

        if (!mounted) {
          return;
        }

        final failure =
        provider
            .consumePendingStageFailure();

        if (failure != null) {
          await _showStageFailedDialog(
            failure,
          );
        }
      },
    );
  }

  Future<void> _showStageFailedDialog(
      Map<String, dynamic> failure,
      ) async {
    if (!mounted) {
      return;
    }

    final stageIndex =
        failure['stageIndex']
        as int? ??
            0;

    final stageNumber =
        stageIndex + 1;

    final challengeTitle =
        failure['challengeTitle']
        as String? ??
            '챌린지';

    await showDialog<void>(
      context: context,
      barrierDismissible:
      false,
      builder: (ctx) {
        final screenWidth =
            MediaQuery.of(ctx)
                .size
                .width;

        return AlertDialog(
          backgroundColor:
          const Color(
            0xFF1B2C2E,
          ),
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              16,
            ),
          ),
          title: Text(
            '$stageNumber단계 도전에 실패했어요',
            style: TextStyle(
              color:
              Colors.white,
              fontFamily:
              'kopub',
              fontSize:
              screenWidth *
                  0.043,
              fontWeight:
              FontWeight.bold,
            ),
          ),
          content: Text(
            '$challengeTitle\n\n'
                '지난 도전일 중 하루의 독서시간이\n10분을 채우지 못했어요.\n\n'
                '${stageNumber == 1 ? '다시 1단계부터 도전할 수 있어요.' : '이전 스테이지의 성공 기록은 유지돼요.\n$stageNumber단계부터 다시 도전할 수 있어요.'}',
            style: TextStyle(
              color:
              Colors.white70,
              fontFamily:
              'kopub',
              fontSize:
              screenWidth *
                  0.034,
              height:
              1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx)
                    .pop();
              },
              child:
              const Text(
                '확인',
                style:
                TextStyle(
                  color:
                  Colors.amberAccent,
                  fontFamily:
                  'kopub',
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth  = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final challengeProvider = context.watch<ChallengeProvider>();


// 진행/미참여/완료 목록
    final joined = challengeProvider.joinedChallenges;


    final notJoined = [
      ...challengeProvider.notJoinedChallenges,
    ]..sort((a, b) {
      int priority(Challenge c) {
        // 1. 습관 만들기 챌린지
        if (c.id == 'daily_10min_habit') {
          return 0;
        }

        // 2. 한 권 완독 챌린지
        if (c.id == 'reading_sprint') {
          return 1;
        }

        // 3. 주간 정기 챌린지
        if (c.imageUrl == 'recurring://weekly') {
          return 2;
        }

        // 4. 월간 정기 챌린지 (2권)
        if (c.imageUrl == 'recurring://monthly' &&
            c.totalBooks == 2) {
          return 3;
        }

        // 5. 월간 정기 챌린지 (5권)
        if (c.imageUrl == 'recurring://monthly' &&
            c.totalBooks == 5) {
          return 4;
        }

        // 6. 나머지 일반 챌린지
        return 5;
      }

      return priority(a).compareTo(priority(b));
    });

    final completed = challengeProvider.completedChallenges;

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
      backgroundColor: Color(0xFF013328),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
        
                    SizedBox(height: screenHeight * 0.02),
        
                    _buildSectionTitle(
                      screenWidth,
                      '진행 중인 챌린지',
                    ),
        
                    SizedBox(height: screenHeight * 0.015),
                    if (joined.isEmpty)
                      _buildPlaceholderBox("진행 중인 챌린지가 없습니다.", screenWidth)
                    else
                      Column(
                        children: joined.map((c) {
                          return ChallengeCard(
                            challenge: c,
                            showAttemptsBadge: true,
                            stageChipDisplayMode: StageChipDisplayMode.ongoing,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ChallengeOngoingScreen(challenge: c),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
        
                    SizedBox(height: screenHeight * 0.02),
        
                    _buildSectionTitle(
                      screenWidth,
                      '챌린지 생성하기',
                    ),
        
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
        
                    SizedBox(height: screenHeight * 0.02),
        
                    _buildSectionTitle(
                      screenWidth,
                      '챌린지 참여하기',
                    ),
        
                    SizedBox(height: screenHeight * 0.015),
        
                    // ⬇️ 테마 칩들
                    _buildThemeChips(screenWidth, availableThemes),
        
                    SizedBox(height: screenHeight * 0.015),
        
                    // ⬇️ 필터링된 리스트
                    if (filteredNotJoined.isEmpty)
                      _buildPlaceholderBox("해당 테마의 챌린지가 없습니다.", screenWidth)
                    else
                      Column(
                        children: filteredNotJoined.map((c) {
                          return ChallengeCard(
                            challenge: c,
                            showAttemptsBadge: true,
                            stageChipDisplayMode: StageChipDisplayMode.joinable,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ChallengeDetailScreen(challenge: c),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    SizedBox(height: screenHeight * 0.15),
                  ],
                ),
              ),
            ),
          ],
        ),
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

  Widget _buildPlaceholderBox(
      String text,
      double screenWidth,
      ) {
    return CardBox(
      padding: EdgeInsets.all(screenWidth * 0.025),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: screenWidth * 0.14,
            height: screenWidth * 0.14,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(
                screenWidth * 0.02,
              ),
            ),
            child: const Icon(
              Icons.hourglass_empty,
              color: Colors.white70,
            ),
          ),
          SizedBox(width: screenWidth * 0.03),
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

  Widget _buildSectionTitle(
      double screenWidth,
      String title,
      ) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white.withOpacity(0.72),
        fontFamily: 'kopub',
        fontSize: screenWidth * 0.032,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
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
      case ChallengeTheme.science_tech:  return '과학기술';
      case ChallengeTheme.literature:  return '문학';
      case ChallengeTheme.mind:  return '마인드';
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
      case ChallengeTheme.science_tech:  return Icons.science;        // 🤔
      case ChallengeTheme.literature:  return Icons.collections_bookmark_outlined;        // 🤔
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

  const CreateChallengeCard({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return CardBox(
      onTap: onTap,
      padding: EdgeInsets.all(screenWidth * 0.025),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: screenWidth * 0.14,
            height: screenWidth * 0.14,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.add_rounded,
              color: Colors.amberAccent,
              size: screenWidth * 0.07,
            ),
          ),

          SizedBox(width: screenWidth * 0.035),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '커스텀 챌린지 생성하기',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'kopub',
                    fontSize: screenWidth * 0.04,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: screenHeight * 0.005),

                Text(
                  '원하는 챌린지를 직접 만들어보세요.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white60,
                    fontFamily: 'kopub',
                    fontSize: screenWidth * 0.033,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: screenWidth * 0.02),

          Icon(
            Icons.chevron_right_rounded,
            color: Colors.white.withOpacity(0.4),
            size: screenWidth * 0.055,
          ),
        ],
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
        "Premium",
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
