import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dayverse_book/screen/setting_screen/account_settings_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/utils/level_utils.dart'; // ✅ 추가
import 'package:flutter/services.dart' show Clipboard, ClipboardData, rootBundle;
import 'package:dayverse_book/utils/auth_utils.dart'; // ✅ checkLoginAndProceed
import 'package:dayverse_book/widget/ad_banner_placeholder.dart';
import 'package:dayverse_book/screen/premium_upgrade_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;




class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  User? user;
  String nickname = '';
  String bio = '';
  LevelInfo? currentLevel;
  int bookCount = 0;
  String? profileImageUrl = ''; // 위에 선언 추가

  bool isPremium = false;           // ✅ 추가
  DateTime? premiumUntil;           // ✅ 추가


  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    final uid = user!.uid;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server));

    if (!mounted) return;
    if (snap.exists) {
      final data = snap.data()!;
      setState(() {
        nickname = data['nickname'] ?? '';
        bio = data['bio'] ?? '';
        profileImageUrl = data['profileImageUrl'] ?? '';

        // ✅ 어떤 구조든 최대한 유연하게 읽기
        isPremium = (data['isPremium'] == true) ||
            (data['premium']?['isActive'] == true) ||
            (data['subscription']?['status'] == 'active');

        final ts = (data['premiumUntil'] ??
            data['premium']?['until'] ??
            data['subscription']?['expiresAt']);
        if (ts is Timestamp) premiumUntil = ts.toDate();
        if (ts is String) premiumUntil = DateTime.tryParse(ts);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final savedBooksProvider = Provider.of<SavedBooksProvider>(context);
    final count = savedBooksProvider.savedBooks.where((b) => b.category == 'done').length;
    final level = LevelUtils.getCurrentLevel(count);

    setState(() {
      bookCount = count;
      currentLevel = level;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmall = screenWidth < 360;

    return Scaffold(
      backgroundColor: const Color(0xFF013328),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: screenHeight * 0.065),
          _buildTopBar(screenWidth),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: screenHeight * 0.02),
                  _buildUserProfileCard(screenWidth, screenHeight),
                  SizedBox(height: screenHeight * 0.02),
                  const Divider(color: Colors.white24),
                  _buildSettingsItem("계정 관리", onTap: () async {
                    final shouldProceed = await checkLoginAndProceed(context);
                    if (!shouldProceed) return;

                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
                    );
                  }),
                  _buildSettingsItem("프리미엄 업그레이드", trailing: _buildUpgradeBadge(), onTap: () async {
                    final shouldProceed = await checkLoginAndProceed(context);
                    if (!shouldProceed) return;

                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) =>  PremiumUpgradeScreen()), // ✅ 여기에 연결!
                    );
                  }),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, s) {
                    final info = s.data;
                    final text = (s.connectionState == ConnectionState.done && info != null)
                        ? '${info.version} (+${info.buildNumber})'
                        : '정보 없음';
                    return _buildSettingsItem(
                      "앱 버전",
                      trailing: GestureDetector(
                        onLongPress: () {
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('버전 정보를 복사했어요')),
                          );
                        },
                        child: Text(text, style: TextStyle(color: Colors.white70, fontSize: MediaQuery.of(context).size.width * 0.03, fontFamily: 'kopub')),
                      ),
                    );
                  },
                ),
                  _buildSettingsItem("칭찬 남기기", onTap: () async {
                    final shouldProceed = await checkLoginAndProceed(context);
                    if (!shouldProceed) return;
                    _openStoreReview(); // ✅ 여기!
                  }),
                  _buildSettingsItem("공지사항", onTap: () async {
                    final shouldProceed = await checkLoginAndProceed(context);
                    if (!shouldProceed) return;

                    _openNotionLink("https://laser-celestite-d8b.notion.site/Labrary-2384357caf3c80e4a036f9680cbaa78c?source=copy_link"); // ✅ 공지사항 Notion URL
                  }),
                  _buildSettingsItem("문의하기", onTap: () async {
                    final shouldProceed = await checkLoginAndProceed(context);
                    if (!shouldProceed) return;
                    _sendInquiryEmail(); // ✅ 여기!
                  }),
                  _buildSettingsItem("서비스 이용약관", onTap: () {
                    _openNotionLink("https://laser-celestite-d8b.notion.site/2384357caf3c805d852cda200ab53094");
                  }),
                  _buildSettingsItem("개인정보 처리방침", onTap: () {
                    _openNotionLink("https://laser-celestite-d8b.notion.site/2384357caf3c8065ac74f8237ba34438");
                  }),

                  SizedBox(height: screenHeight * 0.02),
                  BottomAdBannerBar(),
                ],
              ),
            ),
          ),
        ],
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
        "MY PAGE",
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

  Widget _buildUserProfileCard(double screenWidth, double screenHeight) {
    const String defaultProfileImageUrl =
        'https://firebasestorage.googleapis.com/v0/b/la-pharos.firebasestorage.app/o/profile_images%2Fprofile_default.png?alt=media&token=1f0cbfc9-e6ea-45b7-a5e4-2a8d1efc709f';

    return Stack(
      children: [
        Container(
          padding: EdgeInsets.all(screenWidth * 0.045),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(15),
            border: isPremium
                ? Border.all(
              color: const Color(0xFFFFD369), // 💎 프리미엄 금빛 테두리
              width: 2,
            )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    key: ValueKey(profileImageUrl),
                    radius: screenWidth * 0.10,
                    backgroundColor: Colors.white24,
                    backgroundImage: (profileImageUrl != null && profileImageUrl!.trim().isNotEmpty)
                        ? NetworkImage(profileImageUrl!)
                        : null,
                    child: (profileImageUrl == null || profileImageUrl!.trim().isEmpty)
                        ? const Icon(Icons.person, color: Colors.white70)
                        : null,
                  ),
                  SizedBox(width: screenWidth * 0.045),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              nickname.isNotEmpty ? nickname : "이름 없음",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: screenWidth * 0.05,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isPremium) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.workspace_premium,
                                  color: Color(0xFFFFD369), size: 18),
                            ],
                          ],
                        ),
                        SizedBox(height: screenHeight * 0.007),
                        Row(
                          children: [
                            Text(
                              currentLevel?.name ?? "레벨 없음",
                              style: TextStyle(color: Colors.white, fontSize: screenWidth * 0.03),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              width: 1,
                              height: 16,
                              color: Colors.white38,
                            ),
                            Text("총 $bookCount권",
                                style: TextStyle(color: Colors.white, fontSize: screenWidth * 0.03)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.015),
              Text(
                bio.isNotEmpty ? bio : "자기소개를 남겨보세요 :)",
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70),
              ),
              SizedBox(height: screenHeight * 0.015),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final shouldProceed = await checkLoginAndProceed(context);
                    if (!shouldProceed) return;

                    await Navigator.pushNamed(context, '/profile_edit');
                    await _loadUserData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    isPremium ? const Color(0xFFFFD369) : Colors.amberAccent,
                  ),
                  child: Text(
                    "프로필 편집",
                    style: TextStyle(color: const Color(0xFF0A1D27)),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ✅ 프리미엄 뱃지 (우상단)
        if (isPremium)
          Positioned(
            top: 8,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1D27),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD369), width: 1),
              ),
              child: const Text(
                "PREMIUM",
                style: TextStyle(
                  color: Color(0xFFFFD369),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSettingsItem(
      String title, {
        Widget? trailing,
        Color color = Colors.white,
        VoidCallback? onTap,
      }) {
    return Builder(
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final fontSize = screenWidth * 0.035; // 약 16~18px 기준
        final iconSize = screenWidth * 0.04;  // 약 14~16px 기준

        return ListTile(
          title: Text(
            title,
            style: TextStyle(
              color: color,
              fontFamily: 'kopub',
              fontSize: fontSize,
            ),
          ),
          trailing: trailing ??
              Icon(
                Icons.arrow_forward_ios,
                size: iconSize,
                color: Colors.white30,
              ),
          onTap: onTap,
          contentPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
          horizontalTitleGap: screenWidth * 0.03,
        );
      },
    );
  }

  Widget _buildUpgradeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amberAccent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text("💎 업그레이드", style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
    );
  }

  void _openStoreReview() async {
    String url;

    if (Platform.isAndroid) {
      url = "https://play.google.com/store/apps/details?id=com.your.package.name"; // ✅ Android 패키지명
    } else if (Platform.isIOS) {
      url = "https://apps.apple.com/app/id1234567890?action=write-review"; // ✅ iOS 앱 ID
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지원되지 않는 플랫폼입니다')),
      );
      return;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('스토어 링크를 열 수 없습니다')),
      );
    }
  }

  void _sendInquiryEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'la.pharos711@gmail.com',
      query: Uri.encodeFull("subject=문의 사항&body=문의 내용을 여기에 작성해주세요."),
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메일 앱을 열 수 없습니다')),
      );
    }
  }

  Future<void> _openNotionLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('링크를 열 수 없습니다')),
      );
    }
  }
  void _showTermsDialog(BuildContext context, String title, String assetPath) async {
    final content = await rootBundle.loadString(assetPath);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Text(content, style: const TextStyle(fontSize: 14)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("닫기"),
          ),
        ],
      ),
    );
  }

}
