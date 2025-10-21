import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/widget/search_box_with_results.dart';
import 'package:dayverse_book/constants/dummy_book_list.dart';
import 'package:dayverse_book/screen/challenge_ongoing_screen.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/utils/book_utils.dart';




class ChallengeDetailScreen extends StatelessWidget {
  final Challenge challenge;
  const ChallengeDetailScreen({super.key, required this.challenge});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF013328),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          challenge.title,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'kopub',
            fontSize: 20,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImage(challenge.imageUrl),
                const SizedBox(height: 20),
                const Divider(color: Colors.white24),
                const SizedBox(height: 10),
                Text(
                  challenge.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'kopub',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSummaryCard(challenge),
                const SizedBox(height: 10),
                const Divider(color: Colors.white24),
                const SizedBox(height: 16),
                if (challenge.longDescription != null && challenge.longDescription!.isNotEmpty) ...[
                  _buildDescriptionSection("📖 챌린지 소개", challenge.longDescription ?? ""),
                ],
                if (challenge.goalDescription != null && challenge.goalDescription!.isNotEmpty) ...[
                  _buildDescriptionSection("🎯 도전 목표", challenge.goalDescription ?? ""),
                ],
                if (challenge.recommendedFor != null && challenge.recommendedFor!.isNotEmpty) ...[
                  _buildDescriptionSection("🙋 이런 분께 추천", challenge.recommendedFor ?? "")
                ],
                if (challenge.guideText != null && challenge.guideText!.isNotEmpty) ...[
                  _buildDescriptionSection("📌 진행 방법", challenge.guideText ?? ""),
                ],
                if (challenge.type == ChallengeType.specificBooks)
                  _buildSpecificBookSection(challenge, Provider.of<SavedBooksProvider>(context).savedBooks),
                const SizedBox(height: 100),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: ElevatedButton(
                  onPressed: () async {
                    showDialog(
                      context: context,
                      builder: (ctx) => ChallengeParticipationDialog(challenge: challenge),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("챌린지 참여하기",
                      style: TextStyle(
                          fontSize: 18, fontFamily: 'kopub', fontWeight: FontWeight.bold, color: Colors.black)),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildImage(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        imageUrl,
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: double.infinity,
          height: 200,
          color: Colors.grey,
          child: const Icon(Icons.flag, color: Colors.white, size: 50),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Challenge challenge) {
    final typeText = _getChallengeTypeText(challenge.kind);
    final durationText = (challenge.availableDurations?.isNotEmpty ?? false)
        ? challenge.availableDurations!.map((d) => "$d일").join(" / ")
        : "기간 미정";

    return Column(
      children: [
        _buildInfoCard("💡 한줄 소개", challenge.shortDescription ?? "-"),
        _buildInfoCard("📂 챌린지 유형", typeText),
        _buildInfoCard("🗓 도전 기간", durationText),
        _buildInfoCard("🏅 리워드", challenge.rewardTitle),
      ],
    );
  }

  String _getChallengeTypeText(ChallengeKind kind) {
    switch (kind) {
      case ChallengeKind.routine:
        return "루틴 챌린지";
      case ChallengeKind.goal:
        return "목표 달성 챌린지";
      case ChallengeKind.exploration:
        return "테마 탐험 챌린지";
      case ChallengeKind.cooperation:
        return "협력 챌린지";
    }
  }

  Widget _buildDescriptionSection(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'kopub')),
                const SizedBox(height: 6),
                Text(content,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.4,
                        fontFamily: 'kopub')),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildInfoCard(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white70, fontFamily: 'kopub', fontSize: 16, fontWeight: FontWeight.bold)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white, fontFamily: 'kopub', fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSectionWithWidget({
    required String title,
    required Widget contentWidget,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'kopub')),
          const SizedBox(height: 12),
          contentWidget,
        ],
      ),
    );
  }

  Widget _buildSpecificBookSection(Challenge challenge, List<Map<String, dynamic>> savedBooks) {
    final requiredBooks = challenge.requiredBooks ?? [];

    final readBookIds = savedBooks
        .where((book) => book["category"] == "done")
        .map((book) => book["id"])
        .toSet();

    return _buildDescriptionSectionWithWidget(
      title: "📖 읽을 책 목록",
      contentWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: requiredBooks.map((book) {
          final id = book["id"];
          final title = book["title"] ?? "제목 없음";
          final author = book["author"] ?? "저자 없음";
          final isRead = readBookIds.contains(id);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: isRead ? Colors.green.withOpacity(0.2) : Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isRead ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isRead ? Colors.greenAccent : Colors.white38,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "$title ($author)",
                    style: const TextStyle(
                        color: Colors.white, fontFamily: 'kopub', fontSize: 15),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}




class ChallengeParticipationDialog extends StatefulWidget {
  final Challenge challenge;
  const ChallengeParticipationDialog({super.key, required this.challenge});

  @override
  State<ChallengeParticipationDialog> createState() => _ChallengeParticipationDialogState();
}

class _ChallengeParticipationDialogState extends State<ChallengeParticipationDialog> {
  int? selectedDuration;
  bool showBookSelection = false;
  final TextEditingController searchController = TextEditingController();
  List<Map<String, String>> searchResults = [];
  List<Map<String, String>> selectedBooks = [];

  @override
  void initState() {
    super.initState();
    final durations = widget.challenge.availableDurations;
    if (durations != null && durations.length == 1) {
      selectedDuration = durations.first;
    }
  }

  void onSearchChanged(String keyword) {
    setState(() {
      searchResults = dummyBooks.where((book) {
        final title = book['title']?.toLowerCase() ?? '';
        final author = book['author']?.toLowerCase() ?? '';
        return title.contains(keyword.toLowerCase()) || author.contains(keyword.toLowerCase());
      }).toList();
    });
  }

  void onBookSelected(Map<String, String> book) {
    setState(() {
      if (!selectedBooks.any((b) => b['title'] == book['title'] && b['author'] == book['author'])) {
        selectedBooks.add(book);
      }
      searchResults = [];
      searchController.clear();
    });
  }

  void onBookRemoved(Map<String, String> book) {
    setState(() {
      selectedBooks.remove(book);
    });
  }

  @override
  Widget build(BuildContext context) {
    final challengeProvider = Provider.of<ChallengeProvider>(context, listen: false);
    final savedBooksProvider = Provider.of<SavedBooksProvider>(context, listen: false);
    final availableDurations = widget.challenge.availableDurations ??
        (widget.challenge.defaultDurationDays != null ? [widget.challenge.defaultDurationDays!] : []);

    return Dialog(
      backgroundColor: const Color(0xFF0A1D27),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 80),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("챌린지 참여 설정",
                style: TextStyle(fontFamily: 'kopub', fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
            const SizedBox(height: 20),

            if (availableDurations.length > 1) ...[
              const Text("도전 기간 선택", style: TextStyle(fontFamily: 'kopub', color: Colors.white, fontSize: 18)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: availableDurations.map((days) {
                  final isSelected = selectedDuration == days;
                  return GestureDetector(
                    onTap: () => setState(() => selectedDuration = days),
                    child: Container(
                      width: 80,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.amberAccent : Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          "$days일",
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ] else if (availableDurations.length == 1) ...[
              Text("도전 기간: ${availableDurations.first}일",
                  style: const TextStyle(fontFamily: 'kopub', color: Colors.white70, fontWeight: FontWeight.bold,fontSize: 15)),
              const SizedBox(height: 24),
            ],

            if (widget.challenge.type != ChallengeType.specificBooks && widget.challenge.kind != ChallengeKind.exploration)
              ...[
              const Text(
                "어떤 책으로 도전할지 미리 정해볼까요?",
                style: TextStyle(
                  fontFamily: 'kopub',
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "선택하지 않아도 도전 가능해요! \n"
                    "하지만 미리 책을 정하면 성공 확률이 높아져요.\n"
                    "선택한 책은 '읽는 중인 책'으로 서재에 자동 등록됩니다.",
                style: TextStyle(
                  fontFamily: 'kopub',
                  color: Colors.amberAccent,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 15),
                Container(
                  constraints: const BoxConstraints(maxHeight: 250),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SingleChildScrollView(
                    child: SearchBoxWithResults(
                      searchController: searchController,
                      searchResults: searchResults,
                      selectedBooks: selectedBooks,
                      onSearchChanged: onSearchChanged,
                      onBookSelected: onBookSelected,
                      onBookRemoved: onBookRemoved,
                    ),
                  ),
                ),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (widget.challenge.kind == ChallengeKind.routine && selectedDuration == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("도전 기간을 선택해주세요.")),
                    );
                    return;
                  }

                  final now = DateTime.now();
                  final endDate = widget.challenge.kind == ChallengeKind.routine && selectedDuration != null
                      ? now.add(Duration(days: selectedDuration! - 1))
                      : null;

                  final joinedChallenge = widget.challenge.copyWith(
                    startDate: now,
                    endDate: endDate,
                    participatingBooks: selectedBooks,
                  );

                  await challengeProvider.joinChallenge(
                    joinedChallenge,
                    startDate: now,
                    duration: selectedDuration,
                    participatingBooks: selectedBooks,
                  );

                  for (final book in selectedBooks) {
                    final bookId = generateBookId(book['isbn'], book['title'] ?? '', book['author'] ?? '');
                    final exists = savedBooksProvider.savedBooks.any((b) => b['id'] == bookId);
                    if (!exists) {
                      savedBooksProvider.addBook({
                        ...book,
                        "id": bookId,
                        "category": "reading",
                        "startDate": now.toString(),
                        "endDate": null,
                      });
                    }
                  }

                  if (!context.mounted) return;
                  Navigator.of(context).pop();

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) {
                      Future.delayed(const Duration(seconds: 2), () {
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChallengeOngoingScreen(challenge: joinedChallenge),
                            ),
                                (route) => false,
                          );
                        }
                      });

                      return AlertDialog(
                        backgroundColor: Colors.greenAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        content: Row(
                          children: [
                            const Icon(Icons.emoji_events, color: Colors.deepPurple, size: 36),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "'${widget.challenge.title}'\n도전을 시작했습니다!\n응원합니다 💪",
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontFamily: 'kopub',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  "도전하기",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
