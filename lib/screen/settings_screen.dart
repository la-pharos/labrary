import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/provider/user_data_provider.dart';
import 'package:dayverse_book/screen/premium_upgrade_screen.dart';
import 'package:dayverse_book/screen/setting_screen/account_settings_screen.dart';
import 'package:dayverse_book/utils/auth_utils.dart';
import 'package:dayverse_book/utils/level_utils.dart';
import 'package:dayverse_book/widget/ad_banner_placeholder.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, rootBundle;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dayverse_book/widget/card_box.dart';
import 'package:dayverse_book/screen/friends_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  User? user;
  String nickname = '';
  String bio = '';
  String? profileImageUrl = '';
  bool _isProfileLoading = true;
  late final Future<PackageInfo> _packageInfoFuture;

  static const String _termsUrl = 'https://viixi.kr/labrary/terms';
  static const String _privacyUrl = 'https://viixi.kr/labrary/privacy';
  static const String _contactEmail = 'la.pharos711@gmail.com';

  @override
  void initState() {
    super.initState();

    user = FirebaseAuth.instance.currentUser;
    _packageInfoFuture = PackageInfo.fromPlatform();

    if (user != null) {
      _loadUserProfile();
    }
  }

  Future<void> _loadUserProfile() async {
    final uid = user?.uid;

    if (uid == null) {
      if (mounted) {
        setState(() {
          _isProfileLoading = false;
        });
      }
      return;
    }

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid);

    // ✅ 1. 로컬 캐시를 먼저 읽어서 빠르게 표시
    try {
      final cachedSnap = await userRef.get(
        const GetOptions(source: Source.cache),
      );

      if (cachedSnap.exists && mounted) {
        _applyProfileData(cachedSnap.data()!);
      }
    } catch (e) {
      debugPrint('⚠️ 프로필 캐시 불러오기 실패: $e');
    }

    // ✅ 2. 서버에서 최신 데이터 갱신
    try {
      final serverSnap = await userRef.get(
        const GetOptions(source: Source.server),
      );

      if (!mounted) return;

      if (serverSnap.exists) {
        _applyProfileData(serverSnap.data()!);
      }
    } catch (e) {
      debugPrint('⚠️ 프로필 서버 불러오기 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProfileLoading = false;
        });
      }
    }
  }

  void _applyProfileData(
      Map<String, dynamic> data,
      ) {
    final nextNickname =
    (data['nickname'] ?? '').toString();

    final nextBio =
    (data['bio'] ?? '').toString();

    final nextProfileImageUrl =
    (data['profileImageUrl'] ?? '')
        .toString()
        .trim();

    if (!mounted) return;

    final hasChanged =
        nickname != nextNickname ||
            bio != nextBio ||
            profileImageUrl != nextProfileImageUrl;

    if (!hasChanged) return;

    setState(() {
      nickname = nextNickname;
      bio = nextBio;
      profileImageUrl = nextProfileImageUrl;
    });

    if (nextProfileImageUrl.isNotEmpty) {
      precacheImage(
        CachedNetworkImageProvider(
          nextProfileImageUrl,
          maxWidth: 300,
        ),
        context,
      ).catchError((error) {
        debugPrint(
          '⚠️ 프로필 이미지 미리 불러오기 실패: $error',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 프리미엄 단일 소스: 만료 로직 포함
    final userData = context.watch<UserDataProvider>();
    final isPremium = userData.isPremiumActive;
    final isAnonymous = FirebaseAuth.instance.currentUser?.isAnonymous ?? true;

    // ✅ 레벨/완독 권수는 build에서 계산 (setState 제거)
    final savedBooksProvider = context.watch<SavedBooksProvider>();
    final doneCount = savedBooksProvider.savedBooks.where((b) => b.category == 'done').length;
    final currentLevel = LevelUtils.getCurrentLevel(doneCount);

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isEventPremium = UserDataProvider.kLaunchEventPremiumEnabled &&
        DateTime.now().isBefore(UserDataProvider.kLaunchEventEnd);

    return Scaffold(
      backgroundColor: const Color(0xFF013328),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(screenWidth),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: screenWidth * 0.04,
                  right: screenWidth * 0.04,
                  top: screenHeight * 0.02,
                  bottom: screenHeight * 0.15,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserProfileCard(
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
                      isPremium: isPremium,
                      isAnonymous: isAnonymous,
                      currentLevel: currentLevel,
                      doneCount: doneCount,
                    ),

                    SizedBox(height: screenWidth * 0.03),

                    _buildAccountSettingsCard(
                      screenWidth: screenWidth,
                      isPremium: isPremium,
                      isEventPremium: isEventPremium,
                    ),

                    SizedBox(height: screenWidth * 0.03),

                    _buildAppSettingsCard(screenWidth),

                    SizedBox(height: screenWidth * 0.03),

                    const BottomAdBannerBar(),

                    SizedBox(height: screenHeight * 0.05),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Color(0xFF3DB39E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        '이벤트',
        style: TextStyle(
          color: Color(0xFF013328),
          fontFamily: 'kopub',
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
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

  Widget _buildUserProfileCard({
    required double screenWidth,
    required double screenHeight,
    required bool isPremium,
    required bool isAnonymous,
    required LevelInfo currentLevel,
    required int doneCount,
  }) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(screenWidth * 0.045),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(15),
            border: isPremium
                ? Border.all(
              color: const Color(0xFFFFD369),
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
                  // 이미지 로딩 최적화 버전은 그대로 사용
                  _buildProfileImage(screenWidth),

                  SizedBox(width: screenWidth * 0.045),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                isAnonymous
                                    ? '익명의 사용자'
                                    : nickname.isNotEmpty
                                    ? nickname
                                    : '이름 없음',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'kopub',
                                  fontSize: screenWidth * 0.05,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                            if (isPremium) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.workspace_premium,
                                color: Color(0xFFFFD369),
                                size: 18,
                              ),
                            ],
                          ],
                        ),

                        SizedBox(height: screenHeight * 0.007),

                        Row(
                          children: [
                            LevelUtils.buildLevelIcon(
                              currentLevel,
                              size: screenWidth * 0.05,
                            ),

                            const SizedBox(width: 5),

                            Flexible(
                              child: Text(
                                currentLevel.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'kopub',
                                  fontSize: screenWidth * 0.03,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              width: 1,
                              height: 16,
                              color: Colors.white38,
                            ),

                            Text(
                              '총 $doneCount권',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'kopub',
                                fontSize: screenWidth * 0.03,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: screenHeight * 0.015),

              Text(
                isAnonymous
                    ? '현재 기록을 유지하려면 새 계정으로 회원가입해주세요.'
                    : bio.isNotEmpty
                    ? bio
                    : '자기소개를 남겨보세요 :)',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'kopub',
                  height: 1.4,
                ),
              ),

              SizedBox(height: screenHeight * 0.015),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (isAnonymous) {
                      await Navigator.pushNamed(
                        context,
                        '/signup',
                      );

                      user = FirebaseAuth.instance.currentUser;
                      await _loadUserProfile();
                      return;
                    }

                    await Navigator.pushNamed(
                      context,
                      '/profile_edit',
                    );

                    await _loadUserProfile();
                  },
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: isPremium
                        ? const Color(0xFFFFD369)
                        : Colors.amberAccent,
                    padding: EdgeInsets.symmetric(
                      vertical: screenWidth * 0.03,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isAnonymous
                        ? '회원가입하고 기록 유지'
                        : '프로필 편집',
                    style: const TextStyle(
                      color: Color(0xFF0A1D27),
                      fontFamily: 'kopub',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (isPremium)
          Positioned(
            top: 8,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1D27),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFD369),
                  width: 1,
                ),
              ),
              child: const Text(
                'PREMIUM',
                style: TextStyle(
                  color: Color(0xFFFFD369),
                  fontFamily: 'kopub',
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAccountSettingsCard({
    required double screenWidth,
    required bool isPremium,
    required bool isEventPremium,
  }) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(
        vertical: screenWidth * 0.012,
      ),
      child: Column(
        children: [
          _buildSettingsItem(
            icon: Icons.manage_accounts_outlined,
            title: '계정 관리',
            screenWidth: screenWidth,
            onTap: () async {
              final shouldProceed =
              await checkLoginAndProceed(context);

              if (!shouldProceed) return;

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const AccountSettingsScreen(),
                ),
              );

              await _loadUserProfile();
            },
          ),

          _buildMenuDivider(screenWidth),

          // ✅ 친구
          _buildSettingsItem(
            icon: Icons.people_outline_rounded,
            title: '친구',
            screenWidth: screenWidth,
            onTap: () async {
              final shouldProceed =
              await checkLoginAndProceed(context);

              if (!shouldProceed) return;

              if (!mounted) return;

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const FriendsScreen(),
                ),
              );
            },
          ),

          _buildMenuDivider(screenWidth),

          _buildSettingsItem(
            icon: Icons.workspace_premium_outlined,
            title: isPremium
                ? '프리미엄 관리'
                : '프리미엄 업그레이드',
            screenWidth: screenWidth,
            trailing: isPremium
                ? isEventPremium
                ? _buildEventBadge()
                : _buildPremiumBadge()
                : _buildUpgradeBadge(),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const PremiumUpgradeScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage(
      double screenWidth,
      ) {
    final size =
        screenWidth * 0.20;

    final imageUrl =
        profileImageUrl?.trim() ?? '';

    final hasImage =
        imageUrl.isNotEmpty;

    final heroTag =
        'profile_image_$imageUrl';

    return GestureDetector(
      behavior:
      HitTestBehavior.opaque,
      onTap: hasImage
          ? () {
        _openProfileImageViewer(
          imageUrl,
          heroTag,
        );
      }
          : null,
      child: Hero(
        tag: heroTag,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
            Colors.white.withOpacity(0.07),
            border: Border.all(
              color:
              Colors.white.withOpacity(0.10),
            ),
          ),
          child: ClipOval(
            child: !hasImage
                ? Image.asset(
              'assets/image/profile_default.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
            )
                : CachedNetworkImage(
              imageUrl: imageUrl,
              key: ValueKey(imageUrl),
              width: size,
              height: size,
              fit: BoxFit.cover,
              memCacheWidth: 300,
              placeholder: (_, __) {
                return Image.asset(
                  'assets/image/profile_default.png',
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                );
              },
              errorWidget: (_, __, ___) {
                return Image.asset(
                  'assets/image/profile_default.png',
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                );
              },
            )
          ),
        ),
      ),
    );
  }

  void _openProfileImageViewer(
      String imageUrl,
      String heroTag,
      ) {
    if (imageUrl.trim().isEmpty) {
      return;
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration:
        const Duration(
          milliseconds: 220,
        ),
        reverseTransitionDuration:
        const Duration(
          milliseconds: 180,
        ),
        pageBuilder: (
            context,
            animation,
            secondaryAnimation,
            ) {
          return FadeTransition(
            opacity: animation,
            child: Scaffold(
              backgroundColor:
              Colors.black,
              body: SafeArea(
                child: Stack(
                  children: [
                    // =========================
                    // 이미지
                    // =========================
                    Positioned.fill(
                      child: Center(
                        child:
                        InteractiveViewer(
                          minScale: 1.0,
                          maxScale: 4.0,
                          boundaryMargin:
                          const EdgeInsets.all(
                            80,
                          ),
                          child: Hero(
                            tag: heroTag,
                            child:
                            CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.contain,

                              placeholder: (_, __) {
                                return const SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white54,
                                  ),
                                );
                              },

                              errorWidget: (_, __, ___) {
                                return const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.white54,
                                      size: 54,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      '이미지를 불러오지 못했습니다.',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontFamily: 'kopub',
                                      ),
                                    ),
                                  ],
                                );
                              },
                            )
                          ),
                        ),
                      ),
                    ),

                    // =========================
                    // 닫기
                    // =========================
                    Positioned(
                      top: 10,
                      right: 12,
                      child: Material(
                        color: Colors.black
                            .withOpacity(
                          0.45,
                        ),
                        shape:
                        const CircleBorder(),
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(
                              context,
                            );
                          },
                          customBorder:
                          const CircleBorder(),
                          child:
                          const Padding(
                            padding:
                            EdgeInsets.all(
                              10,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              color:
                              Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppSettingsCard(double screenWidth) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(
        vertical: screenWidth * 0.012,
      ),
      child: Column(
        children: [
          FutureBuilder<PackageInfo>(
            future: _packageInfoFuture,
            builder: (context, snapshot) {
              final info = snapshot.data;

              final versionText =
              snapshot.connectionState ==
                  ConnectionState.done &&
                  info != null
                  ? '${info.version} (+${info.buildNumber})'
                  : '불러오는 중';

              return _buildSettingsItem(
                icon: Icons.info_outline_rounded,
                title: '앱 버전',
                screenWidth: screenWidth,
                trailing: GestureDetector(
                  onLongPress: () {
                    Clipboard.setData(
                      ClipboardData(text: versionText),
                    );

                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content:
                        Text('버전 정보를 복사했어요.'),
                      ),
                    );
                  },
                  child: Text(
                    versionText,
                    style: TextStyle(
                      color: Colors.white54,
                      fontFamily: 'kopub',
                      fontSize: screenWidth * 0.03,
                    ),
                  ),
                ),
              );
            },
          ),

          _buildMenuDivider(screenWidth),

          _buildSettingsItem(
            icon: Icons.star_outline_rounded,
            title: '칭찬 남기기',
            screenWidth: screenWidth,
            onTap: _openStoreReview,
          ),

          _buildMenuDivider(screenWidth),

          _buildSettingsItem(
            icon: Icons.mail_outline_rounded,
            title: '문의하기',
            screenWidth: screenWidth,
            onTap: _sendInquiryEmail,
          ),

          _buildMenuDivider(screenWidth),

          _buildSettingsItem(
            icon: Icons.description_outlined,
            title: '서비스 이용약관',
            screenWidth: screenWidth,
            onTap: () {
              _openExternalLink(_termsUrl);
            },
          ),

          _buildMenuDivider(screenWidth),

          _buildSettingsItem(
            icon: Icons.privacy_tip_outlined,
            title: '개인정보 처리방침',
            screenWidth: screenWidth,
            onTap: () {
              _openExternalLink(_privacyUrl);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required double screenWidth,
    Widget? trailing,
    Color color = Colors.white,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.035,
            vertical: screenWidth * 0.032,
          ),
          child: Row(
            children: [
              Container(
                width: screenWidth * 0.085,
                height: screenWidth * 0.085,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.055),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Colors.white60,
                  size: screenWidth * 0.047,
                ),
              ),

              SizedBox(width: screenWidth * 0.03),

              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontFamily: 'kopub',
                    fontSize: screenWidth * 0.035,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white30,
                    size: screenWidth * 0.055,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuDivider(double screenWidth) {
    return Padding(
      padding: EdgeInsets.only(
        left: screenWidth * 0.15,
        right: screenWidth * 0.035,
      ),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Colors.white.withOpacity(0.055),
      ),
    );
  }

  Widget _buildUpgradeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.amberAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        '업그레이드',
        style: TextStyle(
          color: Colors.amberAccent,
          fontFamily: 'kopub',
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPremiumBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD369),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        '이용 중',
        style: TextStyle(
          color: Color(0xFF013328),
          fontFamily: 'kopub',
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _openStoreReview() async {
    final Uri uri;

    if (Platform.isAndroid) {
      uri = Uri.parse(
        'https://play.google.com/store/apps/details'
            '?id=com.la_pharos.labrary',
      );
    } else if (Platform.isIOS) {
      uri = Uri.parse(
        'https://apps.apple.com/kr/app/'
            'labrary-%EB%8F%85%EC%84%9C-%EA%B8%B0%EB%A1%9D-'
            '%EC%B1%8C%EB%A6%B0%EC%A7%80/'
            'id6758513187?action=write-review',
      );
    } else {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('지원되지 않는 플랫폼입니다.'),
        ),
      );
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('스토어 링크를 열 수 없습니다.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ 스토어 리뷰 링크 열기 실패: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('스토어 링크를 열 수 없습니다.'),
        ),
      );
    }
  }

  Future<void> _sendInquiryEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _contactEmail,
      queryParameters: {
        'subject': 'Labrary 문의',
        'body': '문의 내용을 여기에 작성해주세요.',
      },
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        _showContactFallback();
      }
    } catch (e) {
      debugPrint('❌ 메일 앱 실행 실패: $e');

      if (mounted) {
        _showContactFallback();
      }
    }
  }

  void _showContactFallback() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16483F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          title: const Text(
            '메일 앱을 열 수 없어요',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            '아래 이메일 주소로 문의해주세요.\n'
                'la.pharos711@gmail.com',
            style: TextStyle(
              color: Colors.white60,
              fontFamily: 'kopub',
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                '닫기',
                style: TextStyle(
                  color: Colors.white60,
                  fontFamily: 'kopub',
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(
                  const ClipboardData(
                    text: _contactEmail,
                  ),
                );

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '문의 이메일 주소를 복사했어요.',
                      style: TextStyle(fontFamily: 'kopub'),
                    ),
                  ),
                );
              },
              child: const Text(
                '주소 복사',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontFamily: 'kopub',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openExternalLink(String url) async {
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
