import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import 'package:dayverse_book/screen/login_screen.dart';
import 'package:dayverse_book/screen/signup_screen.dart';
import 'package:dayverse_book/screen/home_screen.dart';
import 'package:dayverse_book/screen/library_screen.dart';
import 'package:dayverse_book/screen/chart_screen.dart';
import 'package:dayverse_book/screen/settings_screen.dart';
import 'package:dayverse_book/screen/challenge_screen.dart';
import 'package:dayverse_book/screen/find_account_screen.dart';

import 'package:dayverse_book/screen/setting_screen/profile_edit_screen.dart';
import 'package:dayverse_book/service/user_data_loader.dart';
// ✅ auth_gate 제거됨

import 'package:dayverse_book/provider/user_data_provider.dart';
import 'package:dayverse_book/provider/challenge_provider.dart'; // ✅ 통합된 Provider
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/provider/custom_library_provider.dart';

import 'package:dayverse_book/widget/user_data_gate.dart';

import 'package:in_app_purchase/in_app_purchase.dart'; // 추가 ✅


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 세로 고정 & 시스템 UI는 기존 그대로
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);

  print("🚀[START] DateTime.now() at app startup: ${DateTime.now()}");

  // 1) Firebase 초기화
  await Firebase.initializeApp();

  // 2) ✅ App Check 활성화 (필수)
  await FirebaseAppCheck.instance.activate(
    androidProvider: kReleaseMode
        ? AndroidProvider.playIntegrity   // 릴리스: Play Integrity
        : AndroidProvider.debug,          // 디버그/에뮬: Debug Provider
    appleProvider: AppleProvider.debug,   // iOS 쓰면 나중에 적절히 교체
  );
  // (선택) 토큰 자동 갱신
  await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);

  // 3) 익명 로그인 (App Check 뒤에 실행)
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    try {
      final result = await FirebaseAuth.instance.signInAnonymously();
      print("✅ 익명 로그인 완료: ${result.user?.uid}");
    } catch (e) {
      print("❌ 익명 로그인 실패: $e");
    }
  } else {
    print("✅ 이미 로그인된 유저: ${currentUser.uid}");
  }

  // 4) 앱 실행
  runApp(const RootApp());
}


class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ChallengeProvider()), // ✅ 초기화 여기서
            ChangeNotifierProvider(create: (_) => SavedBooksProvider()),
            ChangeNotifierProvider(create: (_) => CustomLibraryProvider()),
            ChangeNotifierProvider(create: (_) => UserDataProvider()), // ✅ 추가
          ],
          child: const _AppWithUserLoader(),
        );
      },
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      _initialized = true;
      _loadUserDataIfNeeded(); // ✅ 비동기 처리 따로 분리해서 호출
    }
  }

  Future<void> _loadUserDataIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final savedBooksProvider = context.read<SavedBooksProvider>();
    final customLibraryProvider = context.read<CustomLibraryProvider>();
    final challengeProvider = context.read<ChallengeProvider>();

    final books = savedBooksProvider.savedBooks; // ✅ 현재 저장된 책 목록 불러오기

    await challengeProvider.initialize(user, books); // ✅ 여기서 초기화

    await loadUserDataAfterLogin(
      savedBooksProvider: savedBooksProvider,
      customLibraryProvider: customLibraryProvider,
      challengeProvider: challengeProvider,
      userDataProvider: context.read<UserDataProvider>(),
    );
    context.read<UserDataProvider>().markAsLoaded(); // ✅ 유저 데이터 로드 완료 후

  }

  @override
  Widget build(BuildContext context) {
    return const MyApp();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      initialRoute: '/main', // ✅ 기본 라우트를 명시적으로 지정
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/find_account': (context) => const FindAccountScreen(),
        '/main': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

          return UserDataGate(
            child: MainScreen(
              initialTabIndex: 0,
              showWelcome: args?['showWelcome'] ?? false,
            ),
          );
        },
        '/profile_edit': (context) => const ProfileEditScreen(),
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  final int initialTabIndex;
  final bool showWelcome; // ✅ 분리해서 정의
  const MainScreen({
    Key? key,
    this.initialTabIndex = 0,
    this.showWelcome = false,
  }) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  final PageController _pageController = PageController();
  final GlobalKey<LibraryScreenState> _libraryKey = GlobalKey<LibraryScreenState>();

  bool _didShowWelcome = false; // ✅ 여기 추가

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
        await prefs.remove('justSignedUp'); // 다음에 안 뜨게
      }
    });
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
      backgroundColor: const Color(0xFF013328),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: [
          HomeScreen(),
          LibraryScreen(key: _libraryKey),
          ChallengeScreen(),
          ChartScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFF01241c),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
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
    );
  }

  Widget _buildNavItem(IconData icon, int index, {bool isCenter = false}) {
    bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        padding: isCenter ? const EdgeInsets.all(12) : const EdgeInsets.all(8),
        decoration: isCenter
            ? BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.9),
        )
            : null,
        child: Icon(
          icon,
          color: isCenter
              ? const Color(0xFF013328)
              : (isSelected ? Colors.white : Colors.grey[500]),
          size: isCenter ? 35 : 28,
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
            // 🔽 배경 이미지
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 400,
                width: double.infinity,
                child: Image.asset(
                  'assets/image/welcome.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // 🔽 반투명 배경 + 텍스트
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
                    "Labrary에 오신 걸 진심으로 환영해요!\n\n당신이 책을 통해 더 넓은 세계를 만나갈 수 있도록,\n언제나 곁에서 함께할게요. ✨",
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
                      onPressed: () {
                        Navigator.pop(context);
                      },
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

}
