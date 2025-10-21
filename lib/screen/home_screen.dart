import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/main.dart';
import 'package:dayverse_book/screen/reading_intro_screen.dart';
import 'package:dayverse_book/provider/user_data_provider.dart';
import 'package:dayverse_book/widget/user_data_gate.dart';
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

  // 👇 오늘의 문구 인덱스
  int _quoteIdx = 0;

  // 👇 영어 명언 + 저자 (h: quote, a: author)
  final List<Map<String, String>> _quotes = [
    {
      "h":
          "A good book is like a new friend when you first read it, and like an old friend when you read it again.",
      "a": "Oliver Goldsmith"
    },
    {"h": "A room without books is like a body without a soul.", "a": "Cicero"},
    {
      "h": "I owe my understanding of the world to books.",
      "a": "Jean-Paul Sartre"
    },
    {
      "h":
          "Books are the compass, telescope, sextant, and chart which others have prepared to help us navigate the dangerous seas of human life.",
      "a": "Jesse Lee Bennett"
    },
    {
      "h": "As medicine heals the body, so reading heals the soul.",
      "a": "Julius Caesar"
    },
    {
      "h":
          "Reading makes a full man, conference a ready man, and writing an exact man.",
      "a": "Francis Bacon"
    },
    {
      "h":
          "Spend your time reading the books of others, for through their hard work you can improve yourself with ease.",
      "a": "Socrates"
    },
    {
      "h":
          "Whenever you seek comfort from your painful illusions, turn to your books — they will always welcome you with unchanging kindness.",
      "a": "Fuller"
    },
    {
      "h":
          "Reading all good books is like a conversation with the finest minds of past centuries.",
      "a": "René Descartes"
    },
    {
      "h":
          "The library of my town made me who I am today. A habit of reading is worth more than a Harvard diploma.",
      "a": "Bill Gates"
    },
    {
      "h":
          "I have never known any distress that an hour of reading did not relieve.",
      "a": "Montesquieu"
    },
    {
      "h": "A book is a ship that sails across the vast ocean of time.",
      "a": "Francis Bacon"
    },
    {
      "h": "Choose your authors as carefully as you choose your friends.",
      "a": "Roscommon"
    },
    {
      "h": "The books you need most are the ones that make you think the most.",
      "a": "Mark Twain"
    },
    {"h": "Books and friends should be few and good.", "a": "Spanish Proverb"},
    {"h": "Within books lie the souls of all the past.", "a": "Thomas Carlyle"},
  ];

  @override
  void initState() {
    super.initState();
    _loadImageList();
    _pickQuoteForThisLaunch(); // 👈 추가
  }

  Future<void> _pickQuoteForThisLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt('home_quote_idx') ?? -1;
    final next = (last + 1) % _quotes.length; // 실행할 때마다 +1
    setState(() => _quoteIdx = next);
    await prefs.setInt('home_quote_idx', next);
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
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF013328),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              EdgeInsets.symmetric(horizontal: w * 0.05, vertical: h * 0.03),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1) 이미지
              AspectRatio(
                aspectRatio: 0.9,
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
              Text(
                "Read, Challenge, and Grow with Labrary — your companion on the journey of reading. "
                    "Through each page, broaden the way you see the world.",
                style: TextStyle(
                  fontFamily: 'Kopub',
                  fontSize: w * 0.038,
                  color: Colors.white70,
                ),
              ),

              SizedBox(height: h * 0.03),

              // 3) 독서 시작 버튼
              SizedBox(
                width: double.infinity,
                height: h * 0.075,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ReadingIntroScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(w * 0.03),
                    ),
                  ),
                  child: Text(
                    "독서 시작하기",
                    style: TextStyle(
                      fontFamily: 'kopub',
                      fontSize: w * 0.045,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF013328),
                    ),
                  ),
                ),
              ),

              SizedBox(height: h * 0.01),

              // 4) 챌린지 참여 버튼
              SizedBox(
                width: double.infinity,
                height: h * 0.075,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MainScreen(initialTabIndex: 2)),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(w * 0.03),
                    ),
                  ),
                  child: Text(
                    "🔥 챌린지 참여하기",
                    style: TextStyle(
                      fontFamily: 'kopub',
                      fontSize: w * 0.045,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF013328),
                    ),
                  ),
                ),
              ),

              SizedBox(height: h * 0.03),
            ],
          ),
        ),
      ),
    );
  }
}
