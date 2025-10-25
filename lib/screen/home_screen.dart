import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dayverse_book/main.dart';
import 'package:dayverse_book/screen/reading_intro_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> _images = [];
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadImageList();
  }

  Future<void> _loadImageList() async {
    final jsonString =
    await rootBundle.loadString('assets/background_images/image_list.json');
    final List<dynamic> jsonList = json.decode(jsonString);
    setState(() {
      _images = jsonList.cast<String>()..shuffle();
    });
    _startAutoSlide();
  }

  void _startAutoSlide() {
    if (_images.isEmpty) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % _images.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;
    final padding = MediaQuery.of(context).padding;

    // 1) 이 기기가 "짧은 화면"인지 판별
    //    - 그냥 전체 height로만 보면 애매하니까
    //    - 우리가 실제 컨텐츠를 넣을 수 있는 유효 높이를 보자.
    //
    // usableHeight = 전체 높이 - (bottomNav 대략 높이) - (소프트키 영역 padding.bottom)
    // bottomNav 자체는 우리가 대충 60~70px 쓰고 있으니 72로 가정.
    final usableHeight = h - padding.bottom - 72;

    // 임계값: usableHeight가 작으면(예: 600 이하) 이미지 줄여야 함.
    final bool isTight = usableHeight < 600;

    // 2) 이미지 세로 비율
    //    AspectRatio는 "가로/세로"라서 숫자가 클수록 더 납작(=세로 작아짐).
    //    - 기본(여유로운 화면): 1.1 → 꽤 큼
    //    - 답답한 화면:      1.5 → 더 납작
    final double imageAspect = isTight ? 1.5 : 0.9;

    // 3) 아래쪽 여백
    //    작은 화면일 땐 버튼 바로 밑에 쓸데없이 크게 띄우면 오히려 스크롤 생김.
    //    그래서 여유 있을 땐 크게, 없을 땐 작게.
    final double bottomExtraSpace = isTight ? 16 : 80;

    return Scaffold(
      backgroundColor: const Color(0xFF013328),
      body: SafeArea(
        child: SingleChildScrollView(
          // SingleChildScrollView 남겨두는 이유:
          // 극단적으로 작은 기기일 땐 어차피 스크롤은 필요할 수도 있으니까,
          // 근데 대부분 기기에서는 우리가 위에서 조정한 덕분에 스크롤 안 생김.
          padding: EdgeInsets.symmetric(
            horizontal: w * 0.05,
            vertical: h * 0.03,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 이미지
              AspectRatio(
                aspectRatio: imageAspect,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(w * 0.035),
                  child: _images.isNotEmpty
                      ? AnimatedSwitcher(
                    duration: const Duration(seconds: 1),
                    child: Image.asset(
                      _images[_currentIndex],
                      key: ValueKey(_images[_currentIndex]),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  )
                      : Container(color: Colors.black26),
                ),
              ),

              SizedBox(height: h * 0.03),

              // 타이틀
              Text(
                "This is your journey",
                style: TextStyle(
                  fontFamily: 'Kopub',
                  fontSize: w * 0.06,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              SizedBox(height: h * 0.01),

              // 설명
              Text(
                "Read, challenge, and grow with Labrary — your companion on the journey of reading. "
                    "Through each page, broaden the way you see the world.",
                style: TextStyle(
                  fontFamily: 'Kopub',
                  fontSize: w * 0.038,
                  height: 1.4,
                  color: Colors.white70,
                ),
              ),

              SizedBox(height: h * 0.03),

              // 버튼1
              _buildHomeButton(
                context: context,
                w: w,
                h: h,
                label: "독서 시작하기",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ReadingIntroScreen(),
                    ),
                  );
                },
              ),

              SizedBox(height: h * 0.012),

              // 버튼2
              _buildHomeButton(
                context: context,
                w: w,
                h: h,
                label: "🔥 챌린지 참여하기",
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                      const MainScreen(initialTabIndex: 2),
                    ),
                        (route) => false,
                  );
                },
              ),

              // 아래 여백
              // - padding.bottom: 소프트키/홈 인디케이터 같은 시스템 영역 피하기
              // - bottomExtraSpace: 우리가 시각적으로 주고 싶은 추가 공간
              SizedBox(height: padding.bottom + bottomExtraSpace),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeButton({
    required BuildContext context,
    required double w,
    required double h,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: h * 0.075,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(w * 0.03),
          ),
          padding: EdgeInsets.zero,
          elevation: 0,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Kopub',
            fontSize: w * 0.045,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF013328),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
