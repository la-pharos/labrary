import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dayverse_book/main.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/widget/challenge/progress_card.dart';
import 'package:dayverse_book/widget/challenge/stage_info_card.dart';
import 'package:dayverse_book/widget/challenge/routine_calendar.dart';
import 'package:dayverse_book/widget/challenge/reading_book_section.dart';
import 'package:dayverse_book/widget/challenge/read_done_section.dart';
import 'package:dayverse_book/widget/challenge/summary_card.dart';
import 'package:dayverse_book/widget/challenge/action_button.dart';
import 'package:dayverse_book/widget/challenge/completion_dialog.dart';
import 'package:dayverse_book/utils/challenge_check_utils.dart';
import 'package:dayverse_book/utils/challenge_progress_utils.dart';
import 'challenge_done_screen.dart';


class ChallengeOngoingScreen extends StatefulWidget {
  final Challenge challenge;

  const ChallengeOngoingScreen({super.key, required this.challenge});

  @override
  State<ChallengeOngoingScreen> createState() => _ChallengeOngoingScreenState();
}

class _ChallengeOngoingScreenState extends State<ChallengeOngoingScreen> {
  late Challenge _currentChallenge;
  Map<String, dynamic> _recordWithBooks = {};
  bool _hasCheckedCompletion = false;

  @override
  void initState() {
    super.initState();
    _currentChallenge = widget.challenge;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshChallengeState();

      if (!_hasCheckedCompletion) {
        _hasCheckedCompletion = true;
        await _checkIfCompletedAndNavigate();
      }
    });
  }

  Future<void> _refreshChallengeState() async {
    final provider = Provider.of<ChallengeProvider>(context, listen: false);
    final savedBooks = Provider.of<SavedBooksProvider>(context, listen: false).savedBooks;
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    await provider.refreshChallengeStatus(
      _currentChallenge.id,
      savedBooks: savedBooks,
      userId: userId,
    );
    final refreshed = provider.findChallengeById(_currentChallenge.id);
    if (refreshed != null) {
      final checkType = getChallengeCheckActionType(refreshed);
      final record = (checkType == ChallengeCheckActionType.libraryAuto)
          ? savedBooks
          : (refreshed.attempts.isNotEmpty ? refreshed.attempts.last.recordData ?? {} : {});

      setState(() {
        _currentChallenge = refreshed;
        _recordWithBooks = <String, dynamic>{
          ...(record is Map ? Map<String, dynamic>.from(record) : {}),
          'savedBooks': savedBooks,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final horizontalPadding = screenWidth * 0.05;
    final verticalPadding = screenHeight * 0.02;
    final titleFontSize = screenWidth * 0.05;
    final contentFontSize = screenWidth * 0.04;
    final spacing = screenHeight * 0.02;

    final challengeProvider = context.watch<ChallengeProvider>();
    final savedBooks = context.watch<SavedBooksProvider>().savedBooks;

    final latestChallenge = challengeProvider.findChallengeById(_currentChallenge.id);

    if (latestChallenge != null && latestChallenge != _currentChallenge) {
      _currentChallenge = latestChallenge;

      final latestAttempt = _currentChallenge.attempts.isNotEmpty
          ? _currentChallenge.attempts.last
          : null;

      _recordWithBooks = {
        ...(latestAttempt?.recordData ?? {}),
        'savedBooks': savedBooks,
      };
    }

    final checkType = getChallengeCheckActionType(_currentChallenge);

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 20) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainScreen(initialTabIndex: 2)),
                (route) => false,
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF013328),
        appBar: _buildAppBar(screenWidth),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImage(_currentChallenge.imageUrl),
                  SizedBox(height: spacing),
                  const Divider(color: Colors.white24),
                  SizedBox(height: spacing / 2),
                  Text(
                    _currentChallenge.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'kopub',
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: spacing),
                  if (_currentChallenge.stageType == ChallengeStageType.staged) ...[
                    StageInfoCard(challenge: _currentChallenge),
                    SizedBox(height: spacing),
                  ],
                  ProgressCard(
                    challenge: _currentChallenge,
                    savedBooks: savedBooks,
                    record: _recordWithBooks,
                  ),
                  SizedBox(height: spacing),
                  if (_currentChallenge.category == ChallengeCategory.routine &&
                      checkType != ChallengeCheckActionType.libraryAuto)
                    RoutineCalendar(
                      challenge: _currentChallenge,
                      recordDataOrBooks: _recordWithBooks,
                    ),
                  SizedBox(height: spacing),
                  Consumer<SavedBooksProvider>(
                    builder: (context, savedBooksProvider, _) {
                      return ReadingBookSection(
                        challenge: _currentChallenge,
                        savedBooks: savedBooksProvider.savedBooks,
                      );
                    },
                  ),
                  ReadDoneSection(challenge: _currentChallenge),
                  SizedBox(height: spacing),
                  const Divider(color: Colors.white24),
                  SizedBox(height: spacing),
                  SummaryCard(challenge: _currentChallenge),
                  SizedBox(height: screenHeight * 0.1),
                ],
              ),
            ),
            ActionButton(
              challenge: _currentChallenge,
              record: _recordWithBooks,
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(double screenWidth) {
    final fontSize = screenWidth * 0.05;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainScreen(initialTabIndex: 2)),
                (route) => false,
          );
        },
      ),
      centerTitle: true,
      title: Text(
        _currentChallenge.title,
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'kopub',
          fontSize: fontSize,
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            if (value == 'give_up') {
              _showGiveUpDialog();
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'give_up',
              child: Center(child: Text('챌린지 포기하기', style: TextStyle(color: Colors.black))),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImage(String imageUrl) {
    final screenWidth = MediaQuery.of(context).size.width;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        imageUrl,
        width: screenWidth,
        height: screenWidth * 1,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: screenWidth,
          height: screenWidth * 0.3,
          color: Colors.grey,
          child: const Icon(Icons.flag, color: Colors.white, size: 50),
        ),
      ),
    );
  }

  Future<void> _checkIfCompletedAndNavigate() async {
    final provider = Provider.of<ChallengeProvider>(context, listen: false);
    final savedBooks = Provider.of<SavedBooksProvider>(context, listen: false).savedBooks;
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    await provider.refreshChallengeStatus(_currentChallenge.id, savedBooks: savedBooks, userId: userId);
    final refreshed = provider.findChallengeById(_currentChallenge.id);
    if (refreshed == null) return;

    final checkType = getChallengeCheckActionType(refreshed);
    final record = (checkType == ChallengeCheckActionType.libraryAuto)
        ? savedBooks
        : (refreshed.attempts.isNotEmpty ? refreshed.attempts.last.recordData ?? {} : {});

    setState(() {
      _currentChallenge = refreshed;
      _recordWithBooks = <String, dynamic>{
        ...(record is Map ? Map<String, dynamic>.from(record) : {}),
        'savedBooks': savedBooks,
      };
    });

    final completed = ChallengeProgressUtils.isChallengeCompleted(refreshed, _recordWithBooks);
    final failed = ChallengeProgressUtils.isChallengeFailed(refreshed, _recordWithBooks);

    if (completed) {
      await provider.markChallengeAsCompleted(refreshed.id, userId);

      final finalRefreshed = provider.findChallengeById(refreshed.id);
      if (finalRefreshed != null) {
        setState(() => _currentChallenge = finalRefreshed);
      }

      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => ChallengeCompletionDialog(challenge: _currentChallenge),
        );

        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ChallengeDoneScreen(challenge: _currentChallenge),
            ),
          );
        }
      }
    } else if (failed) {
      await provider.unjoinChallenge(_currentChallenge, userId);

      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (ctx) {
            final screenWidth = MediaQuery.of(ctx).size.width;
            final titleFontSize = screenWidth * 0.045;
            final contentFontSize = screenWidth * 0.038;

            return AlertDialog(
              backgroundColor: const Color(0xFF1B2C2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                "챌린지를 실패했어요",
                style: TextStyle(
                  fontFamily: 'kopub',
                  fontWeight: FontWeight.bold,
                  fontSize: titleFontSize,
                  color: Colors.white,
                ),
              ),
              content: Text(
                "도전 기간 내에 목표를 달성하지 못했어요.\n다음에 다시 도전해보세요!",
                style: TextStyle(
                  fontFamily: 'kopub',
                  fontSize: contentFontSize,
                  height: 1.4,
                  color: Colors.white70,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const MainScreen(initialTabIndex: 2)),
                          (route) => false,
                    );
                  },
                  child: const Text("확인", style: TextStyle(color: Colors.amberAccent)),
                ),
              ],
            );
          },
        );
      }
    }
  }

  /// 챌린지 포기하기
  Future<void> _showGiveUpDialog() async {
    final isCustom = _currentChallenge.isCustom == true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final screenWidth = MediaQuery.of(ctx).size.width;
        final titleFontSize = screenWidth * 0.045;
        final contentFontSize = screenWidth * 0.035;

        return AlertDialog(
          backgroundColor: const Color(0xFF1B2C2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "정말 포기하시겠어요?",
            style: TextStyle(
              fontFamily: 'kopub',
              fontWeight: FontWeight.bold,
              fontSize: titleFontSize,
              color: Colors.white,
            ),
          ),
          content: Text(
            isCustom
                ? "이 사용자 챌린지는 포기하면 리스트에서 완전히 삭제돼요.\n그래도 포기하시겠어요?"
                : "지금까지의 챌린지 기록이 모두 삭제됩니다.\n그래도 포기하시겠어요?",
            style: TextStyle(
              fontFamily: 'kopub',
              fontSize: contentFontSize,
              height: 1.4,
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("계속 도전할래요", style: TextStyle(color: Colors.amberAccent)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("네, 포기할게요", style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      final provider = context.read<ChallengeProvider>();
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

      // ✅ 타입별 분기는 Provider가 내부에서 처리 (커스텀이면 삭제)
      await provider.giveUpChallenge(_currentChallenge, userId);

      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen(initialTabIndex: 2)),
            (route) => false,
      );
    }
  }
}

