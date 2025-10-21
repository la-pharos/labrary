import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:collection/collection.dart';
import 'package:dayverse_book/main.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/utils/challenge_progress_utils.dart';
import 'package:dayverse_book/utils/challenge_check_utils.dart';
import 'package:dayverse_book/service/challenge_record_service.dart';
import 'package:dayverse_book/widget/challenge/summary_card.dart';
import 'package:dayverse_book/widget/challenge/description_card.dart';
import 'package:dayverse_book/widget/challenge/reading_book_section.dart';
import 'package:dayverse_book/widget/challenge/read_done_section.dart';
import 'package:dayverse_book/widget/challenge/routine_calendar.dart';

class ChallengeDoneScreen extends StatefulWidget {
  final Challenge challenge;

  const ChallengeDoneScreen({super.key, required this.challenge});

  @override
  State<ChallengeDoneScreen> createState() => _ChallengeDoneScreenState();
}

class _ChallengeDoneScreenState extends State<ChallengeDoneScreen> {
  bool showDetails = false;
  Map<String, dynamic>? recordData;

  @override
  void initState() {
    super.initState();
    _loadChallengeRecord();

    // ✅ 스테이지 챌린지이고 다음 스테이지가 남았으면 다이얼로그 표시
    final challenge = widget.challenge;
    if (challenge.stageDurations != null && challenge.stageDurations!.isNotEmpty) {
      final totalStages = challenge.stageDurations!.length;
      final completedStages = challenge.attempts.where((a) => a.completed).length;

      // 마지막 스테이지가 아닌 경우에만 안내 다이얼로그
      if (completedStages < totalStages) {
        // Flutter는 initState에서 showDialog 직접 호출 시 오류 날 수 있으므로 다음 프레임으로 넘김
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showNextStageDialog(challenge);
        });
      }
    }
  }

  Future<void> _loadChallengeRecord() async {
    final data = await ChallengeRecordService.fetchChallengeRecord(widget.challenge.id);
    setState(() => recordData = data);
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final savedBooks = context.watch<SavedBooksProvider>().savedBooks;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final padding = screenWidth * 0.05;
    final titleFontSize = screenWidth * 0.05;
    final sectionSpacing = screenHeight * 0.015;

    if (recordData == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF013328),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final record = recordData!;
    final completed = ChallengeProgressUtils.getCompletedCount(challenge, record);
    final total = ChallengeProgressUtils.getTargetCount(challenge, savedBooks);

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 20) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF013328),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          title: Text(
            challenge.title,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.05,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const MainScreen(initialTabIndex: 2)),
                );
              }
            },
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'reset') {
                  _showResetDialog(context, widget.challenge);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'reset',
                  child: Center(child: Text('챌린지 리셋하기')),
                ),
              ],
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCelebrationCard(screenWidth),
              SizedBox(height: sectionSpacing * 0.8),
              _buildImage(challenge.imageUrl, screenHeight),
              SizedBox(height: sectionSpacing),
              const Divider(color: Colors.white24),
              SizedBox(height: sectionSpacing * 0.6),
              Text(
                challenge.title,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'kopub',
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: sectionSpacing),
              _buildCompletionCard(screenWidth),
              SizedBox(height: sectionSpacing),
              _buildChallengeResultSection(challenge, record, savedBooks),
              SizedBox(height: sectionSpacing),
              const Divider(color: Colors.white24),
              SizedBox(height: sectionSpacing),
              SummaryCard(challenge: challenge),
              _buildDetailSection(),
              SizedBox(height: screenHeight * 0.1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCelebrationCard(double screenWidth) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        color: Colors.amberAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amberAccent, width: 2),
      ),
      child: Center(
        child: Icon(Icons.emoji_events, color: Colors.amberAccent, size: screenWidth * 0.15),
      ),
    );
  }

  Widget _buildImage(String url, double screenHeight) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(url,
          width: double.infinity,
          height: screenHeight * 0.4,
          fit: BoxFit.cover),
    );
  }

  Widget _buildCompletionCard(double screenWidth) {
    final fontSize = screenWidth * 0.035;

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text("🎉 축하합니다, 해내셨군요! 🎉",
                style: TextStyle(color: Colors.amberAccent, fontSize: fontSize, fontWeight: FontWeight.bold, fontFamily: 'Kopub')),
          ),
          Center(
            child: Text("더욱 성장하시길 응원합니다 ☀️",
                style: TextStyle(color: Colors.white70, fontSize: fontSize, fontWeight: FontWeight.bold, fontFamily: 'Kopub')),
          ),
          SizedBox(height: screenWidth * 0.02),
          LinearProgressIndicator(
            value: 1.0,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
            minHeight: screenWidth * 0.02,
          ),
          SizedBox(height: screenWidth * 0.03),
          Text("100% 완료",
              style: TextStyle(color: Colors.white, fontFamily: 'kopub', fontSize: fontSize*0.9)),
        ],
      ),
    );
  }

  Widget _buildChallengeResultSection(
      Challenge challenge,
      Map<String, dynamic> record,
      List<BookModel> savedBooks,
      ) {
    final checkAction = getChallengeCheckActionType(challenge);
    final attempt = challenge.attempts.isNotEmpty ? challenge.attempts.last : null;
    final completedBookIds = attempt?.completedBookIds ?? [];

    // 1. 사용자지정/운영자지정 도서 기반 챌린지
    if (challenge.method == ChallengeMethod.specificBooks) {
      return ReadingBookSection(
        challenge: challenge,
        savedBooks: savedBooks,
        completedBookIds: completedBookIds,
        isDoneMode: true,
      );
    }

    // 2. 지정권수 도전 (서재 연동형)
    if (challenge.method == ChallengeMethod.quantityBased) {
      return ReadDoneSection(
        challenge: challenge,
        completedBookIds: completedBookIds,
        isDoneMode: true,
      );
    }

    // 3. 루틴형 챌린지 (타이머/페이지 기반)
    if (challenge.category == ChallengeCategory.routine &&
        checkAction != ChallengeCheckActionType.libraryAuto) {
      return RoutineCalendar(
        challenge: challenge,
        recordDataOrBooks: record,
        isDoneMode: true,
      );
    }

    return const SizedBox();
  }

  Widget _buildDetailSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => setState(() => showDetails = !showDetails),
            icon: Text(
              showDetails ? "챌린지 상세내용 접기" : "📂 챌린지 정보 상세보기",
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'kopub',
                fontWeight: FontWeight.bold,
              ),
            ),
            label: Icon(
              showDetails ? Icons.expand_less : Icons.expand_more,
              color: Colors.white,
            ),
          ),
        ),
        if (showDetails)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.challenge.longDescription != null)
                DescriptionCard(
                  title: "📖 챌린지 소개",
                  content: widget.challenge.longDescription!,
                ),
              if (widget.challenge.goalDescription != null)
                DescriptionCard(
                  title: "🎯 챌린지 목표",
                  content: widget.challenge.goalDescription!,
                ),
              if (widget.challenge.recommendedFor != null)
                DescriptionCard(
                  title: "🙋 이런 분께 추천",
                  content: widget.challenge.recommendedFor!,
                ),
              if (widget.challenge.guideText != null)
                DescriptionCard(
                  title: "📌 진행 방법",
                  content: widget.challenge.guideText!,
                ),
            ],
          ),
      ],
    );
  }

  void _showNextStageDialog(Challenge challenge) {
    final totalStages = challenge.stageDurations?.length ?? 0;
    final completedStages = challenge.attempts.where((a) => a.completed).length;

    if (completedStages >= totalStages) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final titleFontSize = screenWidth * 0.045; // ≈18
        final contentFontSize = screenWidth * 0.035; // ≈15

        return AlertDialog(
          backgroundColor: const Color(0xFF1B2C2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "🚀 다음 단계가 준비되어 있어요!",
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontWeight: FontWeight.bold,
              fontSize: titleFontSize,
            ),
          ),
          content: Text(
            "이 챌린지는 단계적으로 성장해요.\n\n"
                "지금은 ${completedStages}단계 / 총 ${totalStages}단계까지 도전했어요.\n"
                "남은 단계에도 도전해보세요!",
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'kopub',
              fontSize: contentFontSize,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("확인", style: TextStyle(color: Colors.amberAccent, fontSize: contentFontSize)),
            ),
          ],
        );
      },
    );
  }

  void _showResetDialog(BuildContext context, Challenge challenge) {
    showDialog(
      context: context,
      builder: (ctx) {
        final screenWidth = MediaQuery.of(ctx).size.width;
        final titleFontSize = screenWidth * 0.045; // ≈18
        final contentFontSize = screenWidth * 0.035; // ≈15

        return AlertDialog(
          backgroundColor: const Color(0xFF1B2C2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "챌린지를 초기화할까요?",
            style: TextStyle(
              fontFamily: 'kopub',
              fontWeight: FontWeight.bold,
              fontSize: titleFontSize,
              color: Colors.white,
            ),
          ),
          content: Text(
            "이 챌린지의 모든 기록이 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.",
            style: TextStyle(
              fontFamily: 'kopub',
              fontSize: contentFontSize,
              height: 1.4,
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              child: Text("초기화", style: TextStyle(color: Colors.red, fontSize: contentFontSize)),
              onPressed: () async {
                Navigator.pop(ctx);
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await context.read<ChallengeProvider>().resetChallengeForUser(challenge.id, user.uid);
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainScreen(initialTabIndex: 2)),
                        (route) => false,
                  );
                }
              },
            ),
            TextButton(
              child: Text("취소", style: TextStyle(color: Colors.amberAccent, fontSize: contentFontSize)),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        );
      },
    );
  }

}

//📎
