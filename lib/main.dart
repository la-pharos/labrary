import 'package:dayverse_book/screen/challenge_ongoing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:dayverse_book/model/book_model.dart';

import 'package:dayverse_book/screen/login_screen.dart';
import 'package:dayverse_book/screen/signup_screen.dart';
import 'package:dayverse_book/screen/home_screen.dart';
import 'package:dayverse_book/screen/library_screen.dart';
import 'package:dayverse_book/screen/chart_screen.dart';
import 'package:dayverse_book/screen/settings_screen.dart';
import 'package:dayverse_book/screen/challenge_screen.dart';
import 'package:dayverse_book/screen/find_account_screen.dart';
import 'package:dayverse_book/screen/verify_email_screen.dart';
import 'package:dayverse_book/screen/setting_screen/profile_edit_screen.dart';
import 'package:dayverse_book/screen/reading_running_screen.dart';

import 'package:dayverse_book/service/user_data_loader.dart';

import 'package:dayverse_book/provider/user_data_provider.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/provider/custom_library_provider.dart';
import 'package:dayverse_book/provider/reading_timer_provider.dart';

import 'package:dayverse_book/widget/user_data_gate.dart';
import 'package:dayverse_book/service/app_update_service.dart';
import 'package:dayverse_book/widget/update_dialog.dart';
import 'package:dayverse_book/core/theme/labrary_colors.dart';
import 'package:dayverse_book/provider/reading_stats_provider.dart';
import 'dart:async';
import 'package:intl/date_symbol_data_local.dart';
import 'package:app_links/app_links.dart';
import 'package:dayverse_book/screen/challenge_detail_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting(
    'ko_KR',
    null,
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );

  debugPrint(
    '🚀 [START] ${DateTime.now()}',
  );

  /// Firebase 자체 초기화는 유지
  await Firebase.initializeApp();

  /// App Check도 이번 단계에서는 그대로 유지
  await FirebaseAppCheck.instance.activate(
    androidProvider: kReleaseMode
        ? AndroidProvider.playIntegrity
        : AndroidProvider.debug,
    appleProvider: kReleaseMode
        ? AppleProvider.appAttest
        : AppleProvider.debug,
  );

  await FirebaseAppCheck.instance
      .setTokenAutoRefreshEnabled(true);

  /// 기존 인증 구조도 이번 단계에서는 그대로 유지
  final currentUser =
      FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    try {
      final result =
      await FirebaseAuth.instance
          .signInAnonymously();

      debugPrint(
        '✅ 익명 로그인 완료: '
            '${result.user?.uid}',
      );
    } catch (e) {
      debugPrint(
        '❌ 익명 로그인 실패: $e',
      );
    }
  } else {
    debugPrint(
      '✅ 이미 로그인된 유저: '
          '${currentUser.uid}',
    );
  }

  /// 여기까지 끝나면 앱 UI부터 실행
  runApp(const RootApp());

  /// Remote Config 네트워크 요청은
  /// 더 이상 첫 Flutter 화면을 막지 않는다.
  unawaited(
    AppUpdateService.initialize(),
  );
}

class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChallengeProvider()),
        ChangeNotifierProvider(create: (_) => SavedBooksProvider()),
        ChangeNotifierProvider(create: (_) => CustomLibraryProvider()),
        ChangeNotifierProvider(create: (_) => UserDataProvider()),
        ChangeNotifierProvider(create: (_) => ReadingTimerProvider()),
        ChangeNotifierProvider(
          create: (_) => ReadingStatsProvider(),
        ),
      ],
      child: const _AppWithUserLoader(),
    );
  }
}

class _AppWithUserLoader extends StatefulWidget {
  const _AppWithUserLoader({super.key});

  @override
  State<_AppWithUserLoader> createState() => _AppWithUserLoaderState();
}

class _AppWithUserLoaderState extends State<_AppWithUserLoader> {
  bool _initialized = false;

  StreamSubscription<User?>? _authSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;
    _initialized = true;

    // 로그인, 로그아웃, 계정 변경 감지
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen(
          _handleAuthStateChanged,
        );

    _loadUserDataIfNeeded();
  }

  Future<void> _handleAuthStateChanged(User? user) async {
    if (!mounted) return;

    final readingStatsProvider =
    context.read<ReadingStatsProvider>();

    // 기존 계정의 독서 통계를 먼저 제거
    readingStatsProvider.clear();

    // 로그아웃 상태라면 빈 통계 유지
    if (user == null) {
      return;
    }

    // 현재 로그인한 계정의 통계를 다시 불러옴
    await readingStatsProvider.refresh();
  }

  Future<void> _loadUserDataIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      context.read<UserDataProvider>().markAsLoaded();
      return;
    }

    final savedBooksProvider =
    context.read<SavedBooksProvider>();

    final customLibraryProvider =
    context.read<CustomLibraryProvider>();

    final challengeProvider =
    context.read<ChallengeProvider>();

    final userDataProvider =
    context.read<UserDataProvider>();

    await loadUserDataAfterLogin(
      savedBooksProvider: savedBooksProvider,
      customLibraryProvider: customLibraryProvider,
      challengeProvider: challengeProvider,
      userDataProvider: userDataProvider,
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const MyApp();
  }
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _linkSubscription;

  String? _pendingChallengeId;
  bool _userDataReady = false;
  bool _navigationScheduled = false;

  // 실제 공유 도메인을 설정할 때 변경
  static const String _shareHost = 'la-pharos.web.app';

  @override
  void initState() {
    super.initState();

    // 최초 실행 링크와 실행 중 수신 링크를 모두 처리
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleIncomingLink,
      onError: (Object error) {
        debugPrint('딥링크 수신 오류: $error');
      },
    );
  }

  void _handleIncomingLink(Uri uri) {
    debugPrint('딥링크 수신: $uri');

    // Labrary가 발급한 HTTPS 링크만 허용
    if (uri.scheme != 'https' ||
        uri.host != _shareHost) {
      return;
    }

    final segments = uri.pathSegments;

    if (segments.length != 2 ||
        segments.first != 'challenge') {
      return;
    }

    final challengeId = segments.last.trim();

    if (challengeId.isEmpty) return;

    _pendingChallengeId = challengeId;
    _scheduleDeepLinkNavigation();
  }

  void _scheduleDeepLinkNavigation() {
    if (!mounted ||
        !_userDataReady ||
        _pendingChallengeId == null ||
        _navigationScheduled) {
      return;
    }

    _navigationScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationScheduled = false;

      if (!mounted ||
          !_userDataReady ||
          _pendingChallengeId == null) {
        return;
      }

      final navigator = navigatorKey.currentState;
      if (navigator == null) return;

      final challengeId = _pendingChallengeId!;
      _pendingChallengeId = null;

      final provider = context.read<ChallengeProvider>();

      final challenge =
      provider.findChallengeById(challengeId);

      if (challenge == null ||
          challenge.isCustom ||
          challenge.isArchived) {
        ScaffoldMessenger.of(
          navigator.context,
        ).showSnackBar(
          const SnackBar(
            content: Text(
              '해당 챌린지를 찾을 수 없거나 '
                  '현재 이용할 수 없습니다.',
            ),
          ),
        );
        return;
      }


      final isOngoing =
          challenge.isJoined &&
              challenge.currentAttempt != null &&
              !challenge.currentAttempt!.completed;

      navigator.push(
        MaterialPageRoute(
          builder: (_) {
            if (isOngoing) {
              return ChallengeOngoingScreen(
                challenge: challenge,
              );
            }

            return ChallengeDetailScreen(
              challenge: challenge,
            );
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoaded =
        context.watch<UserDataProvider>().isLoaded;

    _userDataReady = isLoaded;

    if (_userDataReady &&
        _pendingChallengeId != null) {
      _scheduleDeepLinkNavigation();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      initialRoute: '/',
      routes: {
        '/': (context) => UserDataGate(
          child: MainScreen(initialTabIndex: 0),
        ),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/find_account': (context) =>
        const FindAccountScreen(),
        '/main': (context) => UserDataGate(
          child: MainScreen(initialTabIndex: 0),
        ),
        '/verify_email': (context) =>
        const VerifyEmailScreen(),
        '/profile_edit': (context) =>
        const ProfileEditScreen(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => UserDataGate(
          child: MainScreen(initialTabIndex: 0),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final int initialTabIndex;

  const MainScreen({
    Key? key,
    this.initialTabIndex = 0,
  }) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  final PageController _pageController = PageController();
  final GlobalKey<LibraryScreenState> _libraryKey = GlobalKey<LibraryScreenState>();

  bool _didShowWelcome = false;
  bool _didCheckUpdate = false;
  bool _didCheckSavedTimer = false;

  SavedBooksProvider? _savedBooksProvider;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _pageController.jumpToPage(_currentIndex);

      final prefs = await SharedPreferences.getInstance();
      final justSignedUp = prefs.getBool('justSignedUp') ?? false;

      if (justSignedUp && !_didShowWelcome && mounted) {
        _didShowWelcome = true;
        _showWelcomeDialog();
        await prefs.remove('justSignedUp');
      }

      await _checkUpdateIfNeeded();

    });
  }

  Future<void> _checkUpdateIfNeeded() async {
    if (_didCheckUpdate) return;
    _didCheckUpdate = true;

    final info = await AppUpdateService.checkForUpdate();

    if (!mounted) return;
    if (info.requirement == UpdateRequirement.none) return;

    final prefs = await SharedPreferences.getInstance();

    // ✅ 강제 업데이트: 항상 표시
    if (info.requirement == UpdateRequirement.force) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => UpdateDialog(info: info),
      );
      return;
    }

    // ✅ 선택 업데이트: 같은 latest_version에 대해 하루 1번만 표시
    final skippedVersion = prefs.getString('skipped_update_version');
    final skippedDate = prefs.getString('skipped_update_date');

    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final alreadySkippedToday =
        skippedVersion == info.latestVersion && skippedDate == todayKey;

    if (alreadySkippedToday) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => UpdateDialog(
        info: info,
        onLater: () async {
          await prefs.setString('skipped_update_version', info.latestVersion);
          await prefs.setString('skipped_update_date', todayKey);
        },
      ),
    );
  }

  Future<void> _checkSavedReadingTimer() async {
    if (_didCheckSavedTimer) return;

    final savedBooksProvider = context.read<SavedBooksProvider>();

    // 책 목록 로딩 전이면 아직 검사하지 않음
    if (!savedBooksProvider.isLoaded) return;

    _didCheckSavedTimer = true;

    final timerProvider = context.read<ReadingTimerProvider>();

    // 이미 현재 메모리에 타이머가 있으면 복구 불필요
    if (timerProvider.hasActiveSession) return;

    final savedSession = await timerProvider.readSavedSession();

    if (savedSession == null || !mounted) return;

    final savedBook =
    savedBooksProvider.getBookByIdOrNull(savedSession.bookId);

    // 저장된 책이 실제 서재에 없으면 잘못된 세션이므로 삭제
    if (savedBook == null) {
      await timerProvider.clearSavedSession();
      return;
    }

    // 3시간 미만이면 자동 복구
    if (!savedSession.requiresConfirmation) {
      timerProvider.restoreSession(
        book: savedBook,
        savedSession: savedSession,
      );
      return;
    }

    // 3시간 이상이면 확인창
    await _showSavedTimerConfirmationDialog(
      book: savedBook,
      savedSession: savedSession,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final provider = context.read<SavedBooksProvider>();

    if (_savedBooksProvider != provider) {
      _savedBooksProvider?.removeListener(_onSavedBooksChanged);
      _savedBooksProvider = provider;
      _savedBooksProvider!.addListener(_onSavedBooksChanged);
    }

    _onSavedBooksChanged();
  }

  void _onSavedBooksChanged() {
    if (!mounted || _didCheckSavedTimer) return;

    final savedBooksProvider = _savedBooksProvider;

    if (savedBooksProvider?.isLoaded == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkSavedReadingTimer();
        }
      });
    }
  }

  @override
  void dispose() {
    _savedBooksProvider?.removeListener(_onSavedBooksChanged);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _showSavedTimerConfirmationDialog({
    required BookModel book,
    required SavedReadingTimerSession savedSession,
  }) async {
    final duration = Duration(
      seconds: savedSession.elapsedSeconds,
    );

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '독서 타이머 확인',
            style: TextStyle(
              fontFamily: 'kopub',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '「${book.title}」의 독서 타이머가\n'
                '$hours시간 $minutes분 동안 진행되었습니다.\n\n'
                '계속 진행하시겠어요?',
            style: const TextStyle(
              fontFamily: 'kopub',
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop('discard');
              },
              child: const Text(
                '기록 없이 종료',
                style: TextStyle(
                  fontFamily: 'kopub',
                  color: Colors.redAccent,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop('continue');
              },
              child: const Text(
                '계속 진행',
                style: TextStyle(
                  fontFamily: 'kopub',
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF013328),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    final timerProvider = context.read<ReadingTimerProvider>();

    if (result == 'continue') {
      timerProvider.restoreSession(
        book: book,
        savedSession: savedSession,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '진행 중이던 독서 타이머를 복구했습니다.',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Color(0xFF013328),
        ),
      );
    } else {
      await timerProvider.clearSavedSession();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '이전 독서 타이머를 종료했습니다.',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      if (_currentIndex == 1 && index == 1) {
        _libraryKey.currentState?.goToOverviewPage();
      } else {
        _currentIndex = index;
        _pageController.jumpToPage(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        children: [
          const HomeScreen(),
          LibraryScreen(
            key: _libraryKey,
            onNavigateMainTab: _onItemTapped,
          ),
          const ChallengeScreen(),
          const ChartScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Consumer<ReadingTimerProvider>(
        builder: (context, timerProvider, _) {
          final hasActiveTimer =
              timerProvider.hasActiveSession && timerProvider.currentBook != null;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasActiveTimer)
                _buildReadingTimerMiniBar(
                  context,
                  timerProvider,
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNavItem(Icons.home_filled, 0),
                          _buildNavItem(Icons.shelves, 1),
                          _buildNavItem(Icons.local_fire_department, 2),
                          _buildNavItem(Icons.bar_chart, 3),
                          _buildNavItem(Icons.menu, 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 56,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFE6E6E6)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Center(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 180),
              scale: isSelected ? 1.08 : 1.0,
              child: Icon(
                icon,
                size: 30,
                color: isSelected
                    ? Colors.black
                    : Colors.black.withOpacity(0.92),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showWelcomeDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 400,
                width: double.infinity,
                child: Image.asset('assets/image/welcome.jpg', fit: BoxFit.cover),
              ),
            ),
            Container(
              height: 400,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.black.withOpacity(0.45),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    "🎉 환영합니다! 🎉",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'kopub',
                    ),
                  ),
                  const Text(
                    "Labrary에 오신 걸 진심으로 환영해요!\n\n책을 통해 더 넓은 세계를 만나갈 수 있도록,\n언제나 곁에서 함께할게요. ✨",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.5,
                      fontFamily: 'kopub',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amberAccent,
                        foregroundColor: const Color(0xFF013328),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("시작하기", style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildReadingTimerMiniBar(
      BuildContext context,
      ReadingTimerProvider timerProvider,
      ) {
    final book = timerProvider.currentBook;
    if (book == null) return const SizedBox.shrink();

    String formatTime(int seconds) {
      final d = Duration(seconds: seconds);
      final hh = d.inHours.toString().padLeft(2, '0');
      final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return "$hh:$mm:$ss";
    }

    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReadingRunningScreen(book: book),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/image/dive_in.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.pause,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '현재 독서 중',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontFamily: 'kopub',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                book.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'kopub',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          formatTime(timerProvider.elapsedSeconds),
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'kopub',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}
