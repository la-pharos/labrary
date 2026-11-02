import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dayverse_book/main.dart';
import 'package:dayverse_book/utils/reading_navigation_helper.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/screen/reading_intro_screen.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/screen/challenge_ongoing_screen.dart';
import 'package:dayverse_book/provider/reading_stats_provider.dart';
import 'package:dayverse_book/widget/home_summary_card.dart';
import 'package:dayverse_book/utils/level_utils.dart';
import 'package:dayverse_book/screen/level_screen.dart';

import 'chart_activity_screen.dart';
import 'package:dayverse_book/screen/notifications_screen.dart';
import 'package:dayverse_book/service/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> _images = [];
  int _currentIndex = 0;
  Timer? _timer;
  final PageController _readingBooksPageController =
  PageController(viewportFraction: 1.0);

  int _readingBookPageIndex = 0;

  final PageController _challengePageController = PageController();
  int _challengeIndex = 0;


  final List<String> _challengeImages = const [
    ///'assets/image/habit_10min.jpeg',
    ///'assets/image/founders_desk.png',
    'assets/image/essay_lover.jpg',
    ///'assets/image/han_kang_challenge.jpg',
    ///'assets/image/a_study_of_love.JPEG',
    ///"assets/image/own_this.png",
    ///"assets/image/golden_year_2026.png",
  ];

  String _userNickname = '';

  @override
  void initState() {
    super.initState();
    _loadImageList();
    _loadUserNickname();
  }

  Future<void> _loadUserNickname() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      if (!mounted) return;

      setState(() {
        _userNickname = '';
      });
      return;
    }

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    // 캐시 우선 조회
    try {
      final cachedSnap = await userRef.get(
        const GetOptions(source: Source.cache),
      );

      if (cachedSnap.exists && mounted) {
        setState(() {
          _userNickname =
              (cachedSnap.data()?['nickname'] ?? '')
                  .toString()
                  .trim();
        });
      }
    } catch (e) {
      debugPrint('⚠️ 홈 닉네임 캐시 조회 실패: $e');
    }

    // 최신 서버 데이터 조회
    try {
      final serverSnap = await userRef.get(
        const GetOptions(source: Source.server),
      );

      if (!mounted) return;

      if (serverSnap.exists) {
        setState(() {
          _userNickname =
              (serverSnap.data()?['nickname'] ?? '')
                  .toString()
                  .trim();
        });
      }
    } catch (e) {
      debugPrint('⚠️ 홈 닉네임 서버 조회 실패: $e');
    }
  }

  Future<void> _loadImageList() async {
    final jsonString =
    await rootBundle.loadString('assets/background_images/image_list.json');
    final List<dynamic> jsonList = json.decode(jsonString);

    if (!mounted) return;

    setState(() {
      _images = jsonList.cast<String>()..shuffle();
    });

    _startAutoSlide();
  }

  void _startAutoSlide() {
    if (_images.isEmpty) return;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _images.isEmpty) return;

      setState(() {
        _currentIndex = (_currentIndex + 1) % _images.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _challengePageController.dispose();
    _readingBooksPageController.dispose();
    super.dispose();
  }

  void _goToReadingStats() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const MainScreen(
          initialTabIndex: 3,
        ),
      ),
          (route) => false,
    );
  }

  void _goToLevelScreen({
    required int totalRead,
    required LevelInfo currentLevel,
    required int booksToNext,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LevelScreen(
          totalRead: totalRead,
          currentLevel: currentLevel,
          booksToNext: booksToNext,
        ),
      ),
    );
  }

  void _goToChallengeTab() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const MainScreen(initialTabIndex: 2),
      ),
          (route) => false,
    );
  }

  void _goToChallengeOngoingScreen(Challenge challenge) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChallengeOngoingScreen(
          challenge: challenge,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;
    final padding = MediaQuery.of(context).padding;
    final savedBooks = context.watch<SavedBooksProvider>().savedBooks;
    final readingBooks = _getReadingBooks(savedBooks);
    final totalRead =
        savedBooks.where((book) => book.category == 'done').length;

    final currentLevel =
    LevelUtils.getCurrentLevel(totalRead);

    final booksToNext =
    LevelUtils.getBooksUntilNextLevel(totalRead);
    final joinedChallenges = context.watch<ChallengeProvider>().joinedChallenges;
    final readingStatsProvider =
    context.watch<ReadingStatsProvider>();

    final weeklySummary =
        readingStatsProvider.weeklySummary;

    // ✅ 오늘 날짜
    final now = DateTime.now();

    final todayKey =
        '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    // ✅ 오늘 누적 독서시간
    final todayReadingMinutes =
        readingStatsProvider.dailyReadingMinutes[todayKey] ?? 0;

    // ✅ Firebase Auth 사용자 이름
    final userName = _userNickname;

    final totalReadingDays =
        readingStatsProvider.dailyReadingMinutes.entries
            .where((entry) => entry.value > 0)
            .map((entry) => DateTime.tryParse(entry.key))
            .whereType<DateTime>()
            .map(
              (date) => DateTime(
            date.year,
            date.month,
            date.day,
          ),
        )
            .toSet()
            .length;

    return Scaffold(
      backgroundColor: const Color(0xFF013328),
      body: Stack(
        children: [
          _buildBackgroundImage(),

          // 전체 어두운 오버레이
          Container(
            color: Colors.black.withOpacity(0.3),
          ),

          // 위/아래 그라데이션
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.18),
                  Colors.transparent,
                  Colors.black.withOpacity(0.72),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                w * 0.06,
                h * 0.04,
                w * 0.06,
                padding.bottom + h * 0.035,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: h - padding.top - padding.bottom - h * 0.08,
                ),
                child: Column(
                  children: [
                    Text(
                      'Read. Challenge. Grow.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Kopub',
                        fontSize: w * 0.052,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),

                    SizedBox(height: h * 0.01),

                    Text(
                      'with Labrary.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontFamily: 'Kopub',
                        fontSize: w * 0.038,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.8,
                      ),
                    ),

                    SizedBox(height: h * 0.21),

                    Text(
                      'READING SESSION',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontFamily: 'Kopub',
                        fontSize: w * 0.032,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.2,
                      ),
                    ),

                    SizedBox(height: h * 0.018),

                    _buildPlayButton(
                      w: w,
                      onTap: () {
                        ReadingNavigationHelper.goToReadingEntry(context);
                      },
                    ),

                    SizedBox(height: h * 0.12),

                    ReadingSummaryCard(
                      userName: userName,
                      todayReadingMinutes: todayReadingMinutes,
                      summary: weeklySummary,
                      totalRead: totalRead,
                      currentLevel: currentLevel,
                      booksToNext: booksToNext,
                      totalReadingMinutes:
                      readingStatsProvider.totalReadingMinutes,
                      totalReadingDays:
                      totalReadingDays,
                      longestStreakDays:
                      readingStatsProvider.longestStreakDays,
                      isLoading:
                      readingStatsProvider.isLoading &&
                          !readingStatsProvider.isLoaded,
                      onReadingActivityTap:
                      _goToReadingActivity,
                      onReadingStatsTap:
                      _goToReadingStats,
                      onLevelTap: () {
                        _goToLevelScreen(
                          totalRead: totalRead,
                          currentLevel: currentLevel,
                          booksToNext: booksToNext,
                        );
                      },
                    ),

                    SizedBox(height: h * 0.018),

                    _buildReadingBooksSection(w, h, readingBooks),

                    SizedBox(height: h * 0.02),

                    _buildChallengeCard(
                      w,
                      h,
                      joinedChallenges,
                      savedBooks,
                    ),

                    SizedBox(height: h * 0.04),
                  ],
                ),
              ),
            ),
          ),

          // ✅ 여기 추가
          Positioned(
            top: padding.top + w * 0.001,
            right: w * 0.045,
            child: StreamBuilder<int>(
              stream: NotificationService
                  .instance
                  .watchUnreadCount(),
              initialData: 0,
              builder: (context, snapshot) {
                final unreadCount =
                    snapshot.data ?? 0;

                return _buildNotificationButton(
                  w: w,
                  unreadCount: unreadCount,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<BookModel> _getReadingBooks(List<BookModel> books) {
    final readingBooks = books
        .where((book) => book.category == 'reading')
        .toList();

    readingBooks.sort((a, b) {
      final aDate = a.startDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.startDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return readingBooks;
  }

  Widget _buildBackgroundImage() {
    if (_images.isEmpty) {
      return Container(
        color: const Color(0xFF013328),
      );
    }

    return Positioned.fill(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 900),
        child: Image.asset(
          _images[_currentIndex],
          key: ValueKey(_images[_currentIndex]),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }

  Widget _buildNotificationButton({
    required double w,
    required int unreadCount,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
            const NotificationsScreen(),
          ),
        );
      },
      child: SizedBox(
        width: w * 0.11,
        height: w * 0.11,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Container(
                width: w * 0.095,
                height: w * 0.095,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.22),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                    Colors.white.withOpacity(0.18),
                  ),
                ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                  size: w * 0.055,
                ),
              ),
            ),

            if (unreadCount > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  constraints: BoxConstraints(
                    minWidth: w * 0.045,
                    minHeight: w * 0.045,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: w * 0.012,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent,
                    borderRadius:
                    BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFF013328),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unreadCount > 9
                        ? '9+'
                        : '$unreadCount',
                    style: TextStyle(
                      color:
                      const Color(0xFF013328),
                      fontFamily: 'kopub',
                      fontSize: w * 0.023,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayButton({
    required double w,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: w * 0.18,
        height: w * 0.18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.85),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: w * 0.105,
        ),
      ),
    );
  }

  Widget _buildReadingBooksSection(
      double w,
      double h,
      List<BookModel> readingBooks,
      ) {
    final int itemCount =
    readingBooks.isEmpty ? 1 : readingBooks.length;

    final int safePageIndex = readingBooks.isEmpty
        ? 0
        : _readingBookPageIndex.clamp(
      0,
      readingBooks.length - 1,
    );

    if (_readingBookPageIndex != safePageIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        if (_readingBooksPageController.hasClients) {
          _readingBooksPageController.jumpToPage(safePageIndex);
        }

        if (_readingBookPageIndex != safePageIndex) {
          setState(() {
            _readingBookPageIndex = safePageIndex;
          });
        }
      });
    }

    return Column(
      children: [
        SizedBox(
          height: h * 0.185,
          width: double.infinity,
          child: PageView.builder(
            controller: _readingBooksPageController,
            itemCount: itemCount,
            onPageChanged: (index) {
              if (_readingBookPageIndex == index) return;

              setState(() {
                _readingBookPageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              if (readingBooks.isEmpty) {
                return _buildCurrentBookCard(
                  w,
                  h,
                  null,
                );
              }

              return _buildCurrentBookCard(
                w,
                h,
                readingBooks[index],
              );
            },
          ),
        ),

        SizedBox(height: h * 0.012),

        _buildReadingBookDots(
          w,
          readingBooks.length,
        ),
      ],
    );
  }

  Widget _buildCurrentBookCard(
      double w,
      double h,
      BookModel? book,
      ) {
    final hasBook = book != null;

    final double progress = hasBook && book.pageCount > 0
        ? (book.pageRead / book.pageCount).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () {
        if (hasBook) {
          _openReadingIntroWithBook(book);
        } else {
          ReadingNavigationHelper.goToReadingEntry(context);
        }
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          w * 0.05,
          h * 0.018,
          w * 0.04,
          h * 0.016,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.58),
          borderRadius: BorderRadius.circular(w * 0.055),
          border: Border.all(
            color: Colors.white.withOpacity(0.16),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.24),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NOW READING',
              style: TextStyle(
                color: Colors.white.withOpacity(0.62),
                fontFamily: 'Kopub',
                fontSize: w * 0.027,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.8,
              ),
            ),

            SizedBox(height: h * 0.008),

            Expanded(
              child: hasBook
                  ? Row(
                children: [
                  ClipRRect(
                    borderRadius:
                    BorderRadius.circular(w * 0.025),
                    child:
                    (book.imageUrl?.isNotEmpty ?? false)
                        ? Image.network(
                      book.imageUrl!,
                      width: w * 0.16,
                      height: w * 0.22,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) =>
                          _buildBookCoverFallback(
                            w,
                          ),
                    )
                        : _buildBookCoverFallback(w),
                  ),

                  SizedBox(width: w * 0.04),

                  Expanded(
                    child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Kopub',
                            fontSize: w * 0.043,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(height: h * 0.004),

                        Text(
                          book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                            Colors.white.withOpacity(0.68),
                            fontFamily: 'Kopub',
                            fontSize: w * 0.032,
                          ),
                        ),

                        SizedBox(height: h * 0.013),

                        ClipRRect(
                          borderRadius:
                          BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor:
                            Colors.white.withOpacity(0.16),
                            valueColor:
                            const AlwaysStoppedAnimation<
                                Color>(
                              Colors.amberAccent,
                            ),
                          ),
                        ),

                        SizedBox(height: h * 0.006),

                        Text(
                          book.pageCount > 0
                              ? '${book.pageRead} / ${book.pageCount}p'
                              : '계속 읽기',
                          style: TextStyle(
                            color:
                            Colors.white.withOpacity(0.64),
                            fontFamily: 'Kopub',
                            fontSize: w * 0.029,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(width: w * 0.025),

                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withOpacity(0.8),
                    size: w * 0.04,
                  ),
                ],
              )
                  : Row(
                children: [
                  Container(
                    width: w * 0.13,
                    height: w * 0.13,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white,
                      size: w * 0.06,
                    ),
                  ),

                  SizedBox(width: w * 0.04),

                  Expanded(
                    child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          '현재 읽고 있는 책이 없어요',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Kopub',
                            fontSize: w * 0.04,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(height: h * 0.004),

                        Text(
                          '책을 선택하고 독서를 시작해보세요.',
                          style: TextStyle(
                            color:
                            Colors.white.withOpacity(0.65),
                            fontFamily: 'Kopub',
                            fontSize: w * 0.031,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withOpacity(0.8),
                    size: w * 0.04,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookCoverFallback(double w) {
    return Container(
      width: w * 0.16,
      height: w * 0.22,
      color: Colors.white.withOpacity(0.12),
      alignment: Alignment.center,
      child: Icon(
        Icons.menu_book_rounded,
        color: Colors.white70,
        size: w * 0.065,
      ),
    );
  }

  Widget _buildReadingBookDots(double w, int count) {
    if (count <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == _readingBookPageIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: EdgeInsets.symmetric(horizontal: w * 0.006),
          width: isActive ? w * 0.055 : w * 0.018,
          height: w * 0.018,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(isActive ? 0.9 : 0.45),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  void _openReadingIntroWithBook(BookModel book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingIntroScreen(
          initialBook: book,
        ),
      ),
    );
  }

  Widget _buildChallengeCard(
      double w,
      double h,
      List<Challenge> joinedChallenges,
      List<BookModel> savedBooks,
      ) {
    final totalCount = 1 + joinedChallenges.length;

    return Column(
      children: [
        SizedBox(
          height: h * 0.185,
          width: double.infinity,
          child: PageView.builder(
            controller: _challengePageController,
            itemCount: totalCount,
            onPageChanged: (index) {
              setState(() => _challengeIndex = index);
            },
            itemBuilder: (context, index) {
              final bool isStartCard = index == 0;
              final Challenge? challenge =
              isStartCard ? null : joinedChallenges[index - 1];

              final String imagePath = isStartCard
                  ? _challengeImages.first
                  : challenge!.imageUrl;

              final String title =
              isStartCard ? '챌린지 참여하기' : challenge!.title;

              final String subtitle = isStartCard
                  ? '새로운 도전을 시작해보세요.'
                  : _buildChallengeSubtitle(challenge!);

              final double progress =
              isStartCard
                  ? 0.0
                  : _calculateChallengeProgress(
                challenge!,
                savedBooks,
              );

              final String progressText =
              isStartCard
                  ? ''
                  : _buildChallengeProgressText(
                challenge!,
                savedBooks,
              );

              final String remainingText =
              isStartCard
                  ? ''
                  : _buildChallengeRemainingText(
                challenge!,
              );

              return GestureDetector(
                onTap: () {
                  if (isStartCard) {
                    _goToChallengeTab();
                  } else {
                    _goToChallengeOngoingScreen(challenge!);
                  }
                },
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(w * 0.055),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(w * 0.055),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildChallengeImage(imagePath),

                        Container(
                          color: Colors.black.withOpacity(0.16),
                        ),

                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.black.withOpacity(0.74),
                                Colors.black.withOpacity(0.28),
                              ],
                            ),
                          ),
                        ),

                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            w * 0.055,
                            h * 0.018,
                            w * 0.05,
                            h * 0.018,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CHALLENGE',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.62),
                                  fontFamily: 'Kopub',
                                  fontSize: w * 0.027,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.8,
                                ),
                              ),

                              SizedBox(height: h * 0.008),

                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      width: w * 0.13,
                                      height: w * 0.13,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.17),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.7),
                                          width: 1.1,
                                        ),
                                      ),
                                      child: Icon(
                                        isStartCard
                                            ? Icons.local_fire_department_rounded
                                            : Icons.emoji_events_rounded,
                                        color: Colors.white,
                                        size: w * 0.055,
                                      ),
                                    ),

                                    SizedBox(width: w * 0.04),

                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'Kopub',
                                              fontSize: w * 0.043,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),

                                          SizedBox(height: h * 0.006),

                                          Text(
                                            subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.68),
                                              fontFamily: 'Kopub',
                                              fontSize: w * 0.031,
                                            ),
                                          ),

                                          if (!isStartCard) ...[
                                            SizedBox(height: h * 0.01),

                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(999),
                                              child: LinearProgressIndicator(
                                                value: progress,
                                                minHeight: 5,
                                                backgroundColor:
                                                Colors.white.withOpacity(0.16),
                                                valueColor:
                                                const AlwaysStoppedAnimation<Color>(
                                                  Colors.amberAccent,
                                                ),
                                              ),
                                            ),

                                            SizedBox(height: h * 0.005),

                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    progressText,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: Colors.white.withOpacity(0.64),
                                                      fontFamily: 'Kopub',
                                                      fontSize: w * 0.028,
                                                    ),
                                                  ),
                                                ),

                                                if (remainingText.isNotEmpty) ...[
                                                  SizedBox(width: w * 0.02),

                                                  Text(
                                                    remainingText,
                                                    style: TextStyle(
                                                      color: Colors.amberAccent.withOpacity(0.9),
                                                      fontFamily: 'Kopub',
                                                      fontSize: w * 0.028,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),

                                    SizedBox(width: w * 0.025),

                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: Colors.white.withOpacity(0.82),
                                      size: w * 0.04,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        SizedBox(height: h * 0.012),

        _buildChallengeDots(w, totalCount),
      ],
    );
  }

  Widget _buildChallengeImage(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildChallengeImageFallback(),
      );
    }

    return Image.asset(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildChallengeImageFallback(),
    );
  }

  Widget _buildChallengeImageFallback() {
    return Container(
      color: Colors.white12,
      alignment: Alignment.center,
      child: const Icon(
        Icons.flag,
        color: Colors.white70,
        size: 36,
      ),
    );
  }

  Widget _buildChallengeDots(double w, int count) {
    if (count <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == _challengeIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: EdgeInsets.symmetric(horizontal: w * 0.006),
          width: isActive ? w * 0.055 : w * 0.018,
          height: w * 0.018,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(isActive ? 0.9 : 0.45),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  String _buildChallengeSubtitle(Challenge challenge) {
    final duration = _getChallengeDuration(challenge);

    if (duration > 0) {
      return '$duration일 도전';
    }

    // 무기한 / 기간 없는 챌린지
    return '기간 제한 없음';
  }

  int _getValidCompletedBookCount(
      Challenge challenge,
      List<BookModel> savedBooks,
      ) {
    final attempt =
        challenge.currentAttempt;

    if (attempt == null) {
      return 0;
    }

    final completedIds =
    attempt.completedBookIds.toSet();

    return savedBooks.where((book) {
      // 챌린지에서 완독 처리된 책이어야 함
      if (!completedIds.contains(book.id)) {
        return false;
      }

      // 현재도 실제 완독 상태여야 함
      if (book.category != 'done') {
        return false;
      }

      return true;
    }).length;
  }

  double _calculateChallengeProgress(
      Challenge challenge,
      List<BookModel> savedBooks,
      ) {
    final attempt =
        challenge.currentAttempt;

    if (attempt == null) {
      return 0.0;
    }

    final targetBooks =
    _getChallengeTargetBookCount(
      challenge,
    );

    if (targetBooks > 0) {
      final completed =
      _getValidCompletedBookCount(
        challenge,
        savedBooks,
      );

      return (completed / targetBooks)
          .clamp(0.0, 1.0)
          .toDouble();
    }

    final duration =
    _getChallengeDuration(
      challenge,
    );

    if (duration > 0) {
      final passedDays =
          DateTime.now()
              .difference(
            attempt.startDate,
          )
              .inDays +
              1;

      return (passedDays / duration)
          .clamp(0.0, 1.0)
          .toDouble();
    }

    return 0.0;
  }

  String _buildChallengeProgressText(
      Challenge challenge,
      List<BookModel> savedBooks,
      ) {
    final attempt =
        challenge.currentAttempt;

    if (attempt == null) {
      return '진행 정보를 불러오는 중';
    }

    final targetBooks =
    _getChallengeTargetBookCount(
      challenge,
    );

    if (targetBooks > 0) {
      final completed =
      _getValidCompletedBookCount(
        challenge,
        savedBooks,
      ).clamp(
        0,
        targetBooks,
      );

      return '$completed / $targetBooks권 완료';
    }

    final duration =
    _getChallengeDuration(
      challenge,
    );

    if (duration > 0) {
      final passedDays =
          DateTime.now()
              .difference(
            attempt.startDate,
          )
              .inDays +
              1;

      final safePassedDays =
      passedDays.clamp(
        1,
        duration,
      );

      return '$safePassedDays / $duration일 진행';
    }

    return challenge.goalDisplayText ??
        '진행 중';
  }

  int _getChallengeTargetBookCount(Challenge challenge) {
    if (challenge.method == ChallengeMethod.quantityBased) {
      return challenge.totalBooks ?? 0;
    }

    if (challenge.method == ChallengeMethod.specificBooks) {
      final attempt = challenge.currentAttempt;

      if (challenge.specificBookMode == SpecificBookMode.userDefined) {
        return attempt?.participatedBooks?.length ??
            challenge.participatingBooks?.length ??
            challenge.requiredBooks?.length ??
            0;
      }

      return challenge.requiredBooks?.length ?? 0;
    }

    return 0;
  }

  int _getChallengeDuration(Challenge challenge) {
    final attempt = challenge.currentAttempt;

    if (attempt?.selectedDuration != null && attempt!.selectedDuration! > 0) {
      return attempt.selectedDuration!;
    }

    if (challenge.stageType == ChallengeStageType.staged &&
        challenge.stageDurations.isNotEmpty) {
      final index = challenge.currentStageIndex;
      if (index >= 0 && index < challenge.stageDurations.length) {
        return challenge.stageDurations[index];
      }
    }

    if (challenge.durationOptions != null &&
        challenge.durationOptions!.isNotEmpty) {
      return challenge.durationOptions!.first;
    }

    if (challenge.startDate != null && challenge.endDate != null) {
      return challenge.endDate!
          .difference(DateTime(
        challenge.startDate!.year,
        challenge.startDate!.month,
        challenge.startDate!.day,
      ))
          .inDays +
          1;
    }

    return 0;
  }

  String _buildChallengeRemainingText(
      Challenge challenge,
      ) {
    final attempt = challenge.currentAttempt;

    if (attempt == null) {
      return '';
    }

    final now = DateTime.now();
    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    DateTime? endDate;

    // 고정 종료일이 있는 챌린지
    if (challenge.endDate != null) {
      endDate = DateTime(
        challenge.endDate!.year,
        challenge.endDate!.month,
        challenge.endDate!.day,
      );
    }

    // 참여일 + 도전기간으로 종료일 계산
    if (endDate == null) {
      final duration =
      _getChallengeDuration(challenge);

      if (duration > 0) {
        final startDate = DateTime(
          attempt.startDate.year,
          attempt.startDate.month,
          attempt.startDate.day,
        );

        endDate = startDate.add(
          Duration(days: duration - 1),
        );
      }
    }

    // 기간 제한 없는 챌린지
    if (endDate == null) {
      return '기한 없음';
    }

    final remainingDays =
        endDate.difference(today).inDays;

    if (remainingDays < 0) {
      return '기간 종료';
    }

    if (remainingDays == 0) {
      return '오늘 종료';
    }

    return '$remainingDays일 남음';
  }

  BookModel? _getCurrentReadingBook(List<BookModel> books) {
    final readingBooks = books.where((book) => book.category == 'reading').toList();

    if (readingBooks.isEmpty) return null;

    readingBooks.sort((a, b) {
      final aDate = a.startDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.startDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return readingBooks.first;
  }


  void _goToReadingActivity() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const ChartActivityScreen(),
      ),
    );
  }

}
