import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/provider/user_data_provider.dart';
import 'package:dayverse_book/screen/challenge_ongoing_screen.dart';
import 'package:dayverse_book/utils/challenge_check_utils.dart';
import 'package:dayverse_book/utils/challenge_stage_utils.dart';
import 'package:dayverse_book/service/book_api_service.dart';
import 'package:dayverse_book/service/challenge_record_service.dart';
import 'package:dayverse_book/widget/login_please_dialog.dart';
import 'package:dayverse_book/widget/calendar_widget.dart';
import 'package:dayverse_book/widget/challenge/book_search_selection_box.dart';
import 'package:dayverse_book/widget/challenge/summary_card.dart';
import 'package:dayverse_book/widget/challenge/description_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dayverse_book/utils/book_pool_loader.dart'; // ✅ 추가



class ChallengeDetailScreen extends StatefulWidget {
  final Challenge challenge;

  const ChallengeDetailScreen({super.key, required this.challenge});

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  List<BookModel> detailedRequiredBooks = [];

  @override
  void initState() {
    super.initState();
    _loadRequiredBookDetails();
  }

  Future<void> _loadRequiredBookDetails() async {
    try {
      List<String> isbns = [];

      // 1️⃣ 풀 참조가 있으면 ISBN 목록 로드
      if (widget.challenge.requiredBooksPoolId != null) {
        isbns = await loadIsbnsFromPool(widget.challenge.requiredBooksPoolId!);
      }

      // 2️⃣ 없거나 비어있다면 (구버전 호환) 기존 requiredBooks에서 ISBN 추출
      if (isbns.isEmpty && widget.challenge.requiredBooks != null) {
        isbns = widget.challenge.requiredBooks!
            .map((b) => (b.isbn ?? '').trim())
            .where((x) => x.isNotEmpty)
            .toList();
      }

      // 3️⃣ ISBN이 있으면 ISBN 기반 API로 상세 조회
      if (isbns.isNotEmpty) {
        final result = await BookApiService.fetchBooksByIsbnList(isbns);
        if (!mounted) return;
        setState(() => detailedRequiredBooks = result);
        return;
      }

      // 4️⃣ ISBN도 없으면(드물지만) 구-로직 fallback (제목/저자 기반)
      final baseBooks = widget.challenge.requiredBooks ?? [];
      if (baseBooks.isNotEmpty) {
        final result = await BookApiService.fetchRequiredBooksFromApi(baseBooks);
        if (!mounted) return;
        setState(() => detailedRequiredBooks = result);
      }
    } catch (e) {
      debugPrint('⚠️ _loadRequiredBookDetails error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final horizontalPadding = screenWidth * 0.05;
    final verticalPadding = screenHeight * 0.02;
    final titleFontSize = screenWidth * 0.05; // 약 20~24
    final sectionTitleFontSize = screenWidth * 0.045; // 약 16~18
    final normalFontSize = screenWidth * 0.035; // 약 14~15

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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text(
            widget.challenge.title,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize: titleFontSize,
            ),
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.all(horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImage(widget.challenge.imageUrl),
                  SizedBox(height: verticalPadding),
                  const Divider(color: Colors.white24),
                  SizedBox(height: verticalPadding / 2),
                  Text(
                    widget.challenge.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'kopub',
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: verticalPadding),
                  SummaryCard(challenge: widget.challenge),
                  SizedBox(height: verticalPadding / 2),
                  if (widget.challenge.method == ChallengeMethod.specificBooks &&
                      detailedRequiredBooks.isNotEmpty)
                    _buildSpecificBookSection(widget.challenge, screenWidth, normalFontSize),
                  SizedBox(height: verticalPadding / 2),
                  const Divider(color: Colors.white24),
                  SizedBox(height: verticalPadding / 2),
                  if (widget.challenge.longDescription != null)
                    DescriptionCard(
                      title: "📖 챌린지 소개",
                      content: widget.challenge.longDescription!,
                    ),
                  if (widget.challenge.goalDescription != null)
                    DescriptionCard(
                      title: "🎯 챌린지 목표",
                      content: widget.challenge.goalDisplayText!,
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
                  SizedBox(height: screenHeight * 0.15),
                ],
              ),
            ),
            _buildJoinButton(context, screenWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String imageUrl) {
    final screenWidth = MediaQuery.of(context).size.width;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        imageUrl,
        width: screenWidth,
        height: screenWidth * 1, // 여기 비율 조절 가능 (0.5 ~ 0.6 추천)
        fit: BoxFit.cover,
        alignment: Alignment.bottomCenter,
        errorBuilder: (_, __, ___) => Container(
          width: screenWidth,
          height: screenWidth * 0.3,
          color: Colors.grey,
          child: const Icon(Icons.flag, color: Colors.white, size: 50),
        ),
      ),
    );
  }

  Widget _buildSpecificBookSection(Challenge challenge, double screenWidth, double baseFontSize) {
    final savedBooks = context.read<SavedBooksProvider>().savedBooks;
    final readBookIds = savedBooks
        .where((book) => book.category == 'done')
        .map((book) => book.id)
        .toSet();

    final imageWidth = screenWidth * 0.15; // 예: 60~80px
    final imageHeight = imageWidth * 1.35; // 비율 유지
    final iconSize = screenWidth * 0.06;
    final horizontalGap = screenWidth * 0.03;

    return _buildDescriptionSectionWithWidget(
      title: "📖 읽을 책 목록",
      screenWidth: screenWidth,
      contentWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "※ 이전에 읽은 책도 챌린지 참여 시 처음부터 다시 읽기 상태로 전환됩니다.",
            style: TextStyle(
              color: Colors.white70,
              fontSize: baseFontSize * 0.75, // 약 11~13
              fontFamily: 'kopub',
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: screenWidth * 0.025),
          ...detailedRequiredBooks.map((book) {
            final isRead = readBookIds.contains(book.id);

            return Container(
              margin: EdgeInsets.only(bottom: screenWidth * 0.03),
              padding: EdgeInsets.all(screenWidth * 0.03),
              decoration: BoxDecoration(
                color: isRead ? Colors.green.withOpacity(0.2) : Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: (book.imageUrl?.isNotEmpty == true)
                        ? Image.network(
                      book.imageUrl!,
                      width: imageWidth,
                      height: imageHeight,
                      fit: BoxFit.cover,
                      // 로딩 중 표시
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          width: imageWidth,
                          height: imageHeight,
                          color: Colors.white12,
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      // 에러 시 대체 표시
                      errorBuilder: (_, __, ___) => Container(
                        width: imageWidth,
                        height: imageHeight,
                        color: Colors.grey,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image, color: Colors.white70, size: 28),
                      ),
                    )
                        : Container(
                      width: imageWidth,
                      height: imageHeight,
                      color: Colors.grey,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image, color: Colors.white70, size: 28),
                    ),
                  ),
                  SizedBox(width: horizontalGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: baseFontSize * 0.9, // 약 15~17
                            fontWeight: FontWeight.bold,
                            fontFamily: 'kopub',
                          ),
                        ),
                        SizedBox(height: screenWidth * 0.01),
                        Text(
                          book.author,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: baseFontSize * 0.79, // 약 13~14
                            fontFamily: 'kopub',
                          ),
                        ),
                        SizedBox(height: screenWidth * 0.015),
                        if (book.pageCount > 0)
                          Text(
                            "${book.pageCount} 페이지",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: baseFontSize * 0.9,
                              fontFamily: 'kopub',
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: horizontalGap * 0.7),
                  SizedBox(
                    height: imageHeight,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Icon(
                        isRead ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isRead ? Colors.greenAccent : Colors.white38,
                        size: iconSize,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDescriptionSectionWithWidget({
    required String title,
    required Widget contentWidget,
    required double screenWidth,
  }) {
    final titleFontSize = screenWidth * 0.04; // 대략 16~18pt 수준

    return Container(
      margin: EdgeInsets.only(top: screenWidth * 0.03),
      padding: EdgeInsets.all(screenWidth * 0.03),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: 'kopub',
              fontSize: titleFontSize,
            ),
          ),
          SizedBox(height: screenWidth * 0.02),
          contentWidget,
        ],
      ),
    );
  }

  Widget _buildJoinButton(BuildContext context, double screenWidth) {
    return Positioned(
      bottom: 30,
      left: screenWidth * 0.05,
      right: screenWidth * 0.05,
      child: ElevatedButton(
        onPressed: () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null || user.isAnonymous) {
            await showLoginRequiredDialog(context);
            return;
          }

          final result = await showDialog<Challenge>(
            context: context,
            barrierDismissible: true,
            builder: (_) => ChallengeParticipationDialog(challenge: widget.challenge),
          );

          if (result != null && mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ChallengeOngoingScreen(challenge: result),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amberAccent,
          padding: EdgeInsets.symmetric(vertical: screenWidth * 0.045),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          "챌린지 참여하기",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontFamily: 'kopub',
            fontSize: screenWidth * 0.045,
          ),
        ),
      ),
    );
  }

}

/// 참여 다이얼로그

class ChallengeParticipationDialog extends StatefulWidget {
  final Challenge challenge;

  const ChallengeParticipationDialog({super.key, required this.challenge});

  @override
  State<ChallengeParticipationDialog> createState() => _ChallengeParticipationDialogState();
}

class _ChallengeParticipationDialogState extends State<ChallengeParticipationDialog> {
  int? selectedDuration;
  DateTime? selectedStartDate;
  List<BookModel> searchResults = [];
  List<BookModel> selectedBooks = [];
  final TextEditingController searchController = TextEditingController();
  bool _isJoining = false;
  List<BookModel> detailedRequiredBooks = [];



  @override
  void initState() {
    super.initState();

    final c = widget.challenge;
    if (c.stageDurations != null && c.stageDurations!.isNotEmpty) {
      selectedDuration = c.stageDurations!.first;
    } else if (c.durationOptions?.isNotEmpty == true) {
      selectedDuration = c.durationOptions!.first;
    } else if (c.checkCountOptions?.isNotEmpty == true) {
      selectedDuration = c.checkCountOptions!.first;
    }

    // ✅ 시스템 지정 도서가 있으면 불러오기
    if (c.method == ChallengeMethod.specificBooks &&
        c.specificBookMode == SpecificBookMode.systemDefined) {
      _loadBooksFromPoolAndApi();
    }
  }

  Future<void> _loadBooksFromPoolAndApi() async {
    try {
      List<String> isbns = [];

      // 1️⃣ 풀 JSON에서 ISBN 리스트 불러오기
      if (widget.challenge.requiredBooksPoolId != null) {
        isbns = await loadIsbnsFromPool(widget.challenge.requiredBooksPoolId!);
      }

      // 2️⃣ ISBN 기반으로 알라딘 API 조회
      if (isbns.isNotEmpty) {
        final result = await BookApiService.fetchBooksByIsbnList(isbns);
        if (!mounted) return;
        setState(() => detailedRequiredBooks = result);
      }
    } catch (e) {
      debugPrint('⚠️ _loadBooksFromPoolAndApi error: $e');
    }
  }

  bool get needsStartDate =>
      widget.challenge.category == ChallengeCategory.routine &&
          widget.challenge.period == ChallengePeriod.daysBased;

  bool get allowsUserBookSelection =>
      widget.challenge.method == ChallengeMethod.specificBooks &&
          widget.challenge.specificBookMode == SpecificBookMode.userDefined;

  Future<void> _handleJoin() async {
    setState(() => _isJoining = true); // ✅ 로딩 시작

    try {
      final isSubscribed = context.read<UserDataProvider>().isSubscribed;
      final challenge = widget.challenge;

      if (challenge.isPremium && !isSubscribed) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1B2C2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("프리미엄 전용",
                style: TextStyle(fontFamily: 'kopub', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            content: const Text(
              "이 챌린지는 프리미엄 회원만 참여할 수 있어요.\n프리미엄으로 업그레이드해보세요!",
              style: TextStyle(color: Colors.white70, fontFamily: 'kopub', fontSize: 15, height: 1.4),
            ),
            actions: [
              TextButton(
                child: const Text("확인", style: TextStyle(color: Colors.amberAccent)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
        return;
      }

      final savedBooksProvider = context.read<SavedBooksProvider>();
      final challengeProvider = context.read<ChallengeProvider>();
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      Challenge challengeToJoin = challenge;

      if (needsStartDate && selectedStartDate == null) {
        _showSnackBar("도전 시작일을 선택해주세요.");
        return;
      }

      if (allowsUserBookSelection && selectedBooks.isEmpty) {
        _showSnackBar("도전에 사용할 책을 선택해주세요.");
        return;
      }

      final startDate = selectedStartDate ?? DateTime.now();
      List<BookModel> booksToJoin = [];

      if (allowsUserBookSelection) {
        for (final book in selectedBooks) {
          BookModel updatedBook = book;

          if (book.pageCount == 0 && (book.itemId?.isNotEmpty ?? false)) {
            final fetched = await BookApiService.fetchBookDetail(book.itemId!);
            if (fetched != null) {
              updatedBook = book.copyWith(pageCount: fetched.pageCount);
            }
          }

          booksToJoin.add(updatedBook);

          await savedBooksProvider.addOrUpdateBook(
            updatedBook.copyWith(
              category: 'reading',
              startDate: startDate,
              pageRead: (updatedBook.pageRead > 0 && updatedBook.pageRead < (updatedBook.pageCount))
                  ? updatedBook.pageRead
                  : 1,
            ),
          );
        }
      } else if (challenge.method == ChallengeMethod.specificBooks &&
          challenge.specificBookMode == SpecificBookMode.systemDefined) {
        final fetchedBooks = await BookApiService.fetchRequiredBooksFromApi(challenge.requiredBooks ?? []);
        for (final book in fetchedBooks) {
          booksToJoin.add(book);
          await savedBooksProvider.addOrUpdateBook(
            book.copyWith(
              category: 'reading',
              startDate: startDate,
              pageRead: (book.pageRead > 0 && book.pageRead < (book.pageCount))
                  ? book.pageRead
                  : 1,
            ),
          );
        }
      }

      // ✅ 스테이지 챌린지 처리
      if (challenge.stageType == ChallengeStageType.staged &&
          challenge.attempts.isNotEmpty) {
        final updatedAttempts = [
          for (int i = 0; i < challenge.attempts.length - 1; i++)
            challenge.attempts[i],
          challenge.attempts.last.copyWith(startDate: startDate),
        ];
        challengeToJoin = challenge.copyWith(attempts: updatedAttempts);
      }

      // 챌린지 참여
      await challengeProvider.joinChallenge(
        challenge: challengeToJoin,
        startDate: startDate,
        duration: selectedDuration,
        participatingBooks: allowsUserBookSelection ? booksToJoin : null,
        userId: userId,
      );

      final updated = challengeProvider.findChallengeById(challenge.id);
      if (updated != null) {
        _showCheerUpDialogAndPop(updated);
      } else {
        _showSnackBar("참여한 챌린지를 찾을 수 없습니다.");
      }
    } catch (e) {
      debugPrint("❌ 챌린지 참여 오류: $e");
      _showSnackBar("도전 중 문제가 발생했습니다.");
    } finally {
      if (mounted) {
        setState(() => _isJoining = false); // ✅ 로딩 종료
      }
    }
  }

  void _showCheerUpDialogAndPop(Challenge updated) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth * 0.035; // 약 15~17

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop(); // 다이얼로그 닫기
            Navigator.of(context).pop(updated); // 결과 전달
          }
        });
        return AlertDialog(
          backgroundColor: Colors.greenAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.deepPurple, size: screenWidth * 0.08),
              SizedBox(width: screenWidth * 0.03),
              Expanded(
                child: Text(
                  "'${updated.title}'\n도전을 시작했습니다!\n응원합니다 💪",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize,
                    fontFamily: 'Kopub',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void onSearchChanged(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() => searchResults = []);
      return;
    }

    try {
      final results = await BookApiService.searchBooks(keyword);
      setState(() => searchResults = results);
    } catch (_) {
      _showSnackBar("도서 검색 중 문제가 발생했습니다.");
    }
  }

  void onBookSelected(BookModel book) {
    setState(() {
      if (!selectedBooks.any((b) => b.id == book.id)) {
        selectedBooks.add(book);
      }
    });
  }

  void onBookRemoved(BookModel book) {
    setState(() => selectedBooks.removeWhere((b) => b.id == book.id));
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final screenWidth = MediaQuery.of(context).size.width;

    final titleFontSize = screenWidth * 0.05;   // 약 20~22
    final sectionSpacing = screenWidth * 0.045;   // 약 20
    final contentPadding = screenWidth * 0.04;  // 약 16~18

    return WillPopScope(
      onWillPop: () async => !_isJoining, // 로딩 중이면 뒤로가기 막기
      child: Dialog(
        backgroundColor: const Color(0xFF0A1D27),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(contentPadding),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "챌린지 참여 설정",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'kopub',
                  ),
                ),
                SizedBox(height: sectionSpacing),
                _buildChallengeOptions(challenge, screenWidth),
                if (allowsUserBookSelection || challenge.specificBookMode == SpecificBookMode.systemDefined)
                  _buildBookSection(screenWidth),
                SizedBox(height: sectionSpacing),
                _buildJoinButton(screenWidth),
                SizedBox(height: sectionSpacing/2),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildChallengeOptions(Challenge challenge, double screenWidth) {
    final hasStageDurations = challenge.stageDurations != null && challenge.stageDurations!.isNotEmpty;
    final hasDurationOptions = (challenge.durationOptions?.isNotEmpty ?? false);
    final hasCheckCountOptions = (challenge.checkCountOptions?.isNotEmpty ?? false);

    final currentStageIndex = (challenge.attempts.isEmpty)
        ? 0
        : (challenge.attempts.last.stageIndex ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (challenge.period == ChallengePeriod.periodBased &&
            challenge.startDate != null &&
            challenge.endDate != null)
          _buildDurationText(
            "${_formatDate(challenge.startDate!)} ~ ${_formatDate(challenge.endDate!)}",
            screenWidth,
          ),

        if (hasStageDurations)
          _buildDurationText("${challenge.stageDurations![currentStageIndex]}일", screenWidth),

        if (!hasStageDurations && hasDurationOptions && challenge.durationOptions!.length > 1)
          _buildDurationSelection(challenge.durationOptions!, screenWidth)
        else if (!hasStageDurations && hasDurationOptions)
          _buildDurationText("${challenge.durationOptions!.first}일", screenWidth)

        else if (!hasStageDurations && hasCheckCountOptions && challenge.checkCountOptions!.length > 1)
            _buildDurationSelection(challenge.checkCountOptions!, screenWidth)
          else if (!hasStageDurations && hasCheckCountOptions)
              _buildDurationText("${challenge.checkCountOptions!.first}회", screenWidth),

        if (challenge.period == ChallengePeriod.infinite)
          _buildDurationText("책을 모두 읽을 때까지 자유롭게 진행하세요.", screenWidth),

        if (needsStartDate) _buildStartDateSelection(screenWidth),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return "${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}";
  }

  Widget _buildDurationText(String text, double screenWidth) {
    final titleFontSize = screenWidth * 0.04;  // 약 16~18
    final contentFontSize = screenWidth * 0.035; // 약 14~16
    final outerPadding = screenWidth * 0.03;
    final innerPadding = screenWidth * 0.03;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: screenWidth * 0.01),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(outerPadding),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "🔸도전 기간",
              style: TextStyle(
                fontFamily: 'kopub',
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: titleFontSize,
              ),
            ),
            SizedBox(height: screenWidth * 0.03),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(innerPadding),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: contentFontSize,
                  fontFamily: 'kopub',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationSelection(List<int> options, double screenWidth) {
    final titleFontSize = screenWidth * 0.04;
    final buttonWidth = screenWidth * 0.18; // 예: 약 80~90px
    final buttonPadding = screenWidth * 0.03;
    final spacing = screenWidth * 0.02;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(buttonPadding),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "🔸도전 기간 선택",
              style: TextStyle(
                color: Colors.white,
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
                fontFamily: 'kopub',
              ),
            ),
            SizedBox(height: spacing * 1.5),
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: options.map((d) {
                final isSelected = selectedDuration == d;
                return GestureDetector(
                  onTap: () => setState(() => selectedDuration = d),
                  child: Container(
                    width: buttonWidth,
                    padding: EdgeInsets.symmetric(vertical: screenWidth * 0.03),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.amberAccent : Colors.white12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        "$d일",
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth * 0.03,
                          fontFamily: 'kopub',
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartDateSelection(double screenWidth) {
    final titleFontSize = screenWidth * 0.04;
    final contentFontSize = screenWidth * 0.035;
    final boxPadding = screenWidth * 0.03;
    final innerPadding = screenWidth * 0.035;
    final iconSize = screenWidth * 0.04;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: screenWidth * 0.02),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(boxPadding),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "🔸도전 시작일 선택",
              style: TextStyle(
                color: Colors.white,
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
                fontFamily: 'kopub',
              ),
            ),
            SizedBox(height: screenWidth * 0.025),
            GestureDetector(
              onTap: () async {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                DateTime effectiveMinDate = today;
                DateTime? disabledDate;

                if (widget.challenge.stageType == ChallengeStageType.staged &&
                    widget.challenge.attempts.length >= 2) {
                  final prev = widget.challenge.attempts[widget.challenge.attempts.length - 2];
                  final prevEndDate = prev.endDate?.toLocal();

                  if (prevEndDate != null) {
                    final localPrev = DateTime(prevEndDate.year, prevEndDate.month, prevEndDate.day);
                    disabledDate = localPrev;
                    effectiveMinDate = localPrev.add(const Duration(days: 1));
                  }
                }

                final initialSelected = selectedStartDate != null &&
                    !selectedStartDate!.isBefore(effectiveMinDate)
                    ? selectedStartDate!
                    : effectiveMinDate;

                await showCalendarDialog(
                  context: context,
                  selectedDate: selectedStartDate != null &&
                      selectedStartDate!.isAfter(effectiveMinDate.subtract(const Duration(days: 1)))
                      ? selectedStartDate!
                      : effectiveMinDate,
                  minDate: effectiveMinDate,
                  maxDate: today.add(const Duration(days: 365)),
                  onDatePicked: (picked) {
                    setState(() => selectedStartDate = picked);
                  },
                  isStartDate: true,
                  disabledDates: disabledDate != null ? [disabledDate] : [],
                );
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: screenWidth * 0.025,
                  horizontal: screenWidth * 0.04,
                ),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.white70, size: iconSize),
                    SizedBox(width: screenWidth * 0.03),
                    Text(
                      selectedStartDate != null
                          ? "${selectedStartDate!.year}-${selectedStartDate!.month.toString().padLeft(2, '0')}-${selectedStartDate!.day.toString().padLeft(2, '0')}"
                          : "시작일을 선택해주세요",
                      style: TextStyle(color: Colors.white, fontSize: contentFontSize),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookSection(double screenWidth) {
    final titleFontSize = screenWidth * 0.04;
    final bookFontSize = screenWidth * 0.03;
    final infoFontSize = screenWidth * 0.03;
    final boxPadding = screenWidth * 0.03;
    final imageWidth = screenWidth * 0.14;
    final imageHeight = imageWidth * 1.4;

    final challenge = widget.challenge;

    // ✅ 사용자 지정 도서 선택형
    if (allowsUserBookSelection) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.01),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(boxPadding),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("🔸도서 선택",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'kopub',
                ),
              ),
              SizedBox(height: screenWidth * 0.025),
              BookSearchSelectionBox(
                initialSelectedBook: selectedBooks.isNotEmpty ? selectedBooks.first : null,
                onBookChanged: (book) {
                  setState(() {
                    selectedBooks = book != null ? [book] : [];
                  });
                },
              ),
            ],
          ),
        ),
      );
    }

    // ✅ 시스템 지정 도서형 (book pool + ISBN 기반)
    else if (challenge.method == ChallengeMethod.specificBooks &&
        challenge.specificBookMode == SpecificBookMode.systemDefined) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.02),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(boxPadding),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("🔸읽을 책 목록",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'kopub')),
              SizedBox(height: screenWidth * 0.03),

              // ✅ 로딩 중
              if (_isJoining && detailedRequiredBooks.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(color: Colors.amberAccent),
                  ),
                )

              // ✅ 도서 목록 출력
              else if (detailedRequiredBooks.isNotEmpty)
                ...detailedRequiredBooks.map((book) => Container(
                  margin: EdgeInsets.only(bottom: screenWidth * 0.02),
                  padding: EdgeInsets.all(screenWidth * 0.02),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      if (book.imageUrl != null && book.imageUrl!.isNotEmpty)
                        Image.network(
                          book.imageUrl!,
                          width: imageWidth,
                          height: imageHeight,
                          fit: BoxFit.cover,
                        ),
                      SizedBox(width: screenWidth * 0.03),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(book.title,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: bookFontSize)),
                            Text(book.author,
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: infoFontSize)),
                          ],
                        ),
                      ),
                      if (book.pageCount > 0)
                        Text('${book.pageCount}페이지',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: infoFontSize)),
                    ],
                  ),
                ))

              // ✅ 아무 책도 없을 때
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    "도서 정보를 불러올 수 없습니다.",
                    style: TextStyle(color: Colors.white70, fontSize: infoFontSize),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // ✅ 기본값
    else {
      return const SizedBox();
    }
  }

  Widget _buildJoinButton(double screenWidth) {
    final fontSize = screenWidth * 0.04;
    final verticalPadding = screenWidth * 0.04;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isJoining ? null : _handleJoin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amberAccent,
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isJoining
            ? SizedBox(
          width: screenWidth * 0.05,
          height: screenWidth * 0.05,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.amberAccent),
          ),
        )
            : Text(
          "도전하기",
          style: TextStyle(
            color: Colors.black,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            fontFamily: 'kopub',
          ),
        ),
      ),
    );
  }

}
