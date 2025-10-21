import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;

class ChallengePreview {
  final String id;
  final String title;
  final String imagePath;
  final bool isPremium;
  final List<String> bookTitles;

  ChallengePreview({
    required this.id,
    required this.title,
    required this.imagePath,
    required this.isPremium,
    required this.bookTitles,
  });
}

class PremiumUpgradeScreen extends StatefulWidget {
  final bool isPremium;            // ✅ 추가
  final DateTime? premiumUntil;    // ✅ 추가

  const PremiumUpgradeScreen({
    super.key,
    this.isPremium = false,
    this.premiumUntil,
  });

  @override
  State<PremiumUpgradeScreen> createState() => _PremiumUpgradeScreenState();
}

class _PremiumUpgradeScreenState extends State<PremiumUpgradeScreen> {
  // ====== IAP ======
  static const Set<String> _kProductIds = {'premium_monthly'};
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  bool _billingAvailable = false;
  bool _loading = true;
  ProductDetails? _product; // premium_monthly
  String? _lastMessage;     // 화면 하단 안내 스낵바용
  bool _restoring = false;
  Timer? _restoreTimer;

  @override
  void initState() {
    super.initState();
    _initIap();
  }

  void _startRestoreTimeout([Duration d = const Duration(seconds: 8)]) {
    _restoreTimer?.cancel();
    _restoreTimer = Timer(d, () {
      if (!_restoring) return;
      _restoring = false;
      _showToast('복원할 내역을 찾지 못했어요. 같은 Google 계정인지 확인해 주세요.');
    });
  }

  void _finishRestoreSuccess() {
    _restoreTimer?.cancel();
    _restoring = false;
    _showToast('복원 완료! 프리미엄이 활성화됐어요.');
  }

  Future<void> _initIap() async {
    try {
      final available = await _iap.isAvailable();
      _billingAvailable = available;

      // 구매 스트림
      _purchaseSub = _iap.purchaseStream.listen(_onPurchases,
          onError: (e) => _showToast('구매 스트림 오류: $e'));

      // 상품 조회
      final resp = await _iap.queryProductDetails(_kProductIds);
      if (resp.error != null) {
        _showToast('상품 조회 오류: ${resp.error}');
      } else if (resp.productDetails.isEmpty) {
        _showToast('상품을 찾을 수 없습니다. (콘솔 활성/트랙 게시/테스트계정 확인)');
      } else {
        _product = resp.productDetails.first;
      }
    } catch (e) {
      _showToast('초기화 오류: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p); // acknowledge
          }
          if (_restoring) {
            _finishRestoreSuccess(); // ✅ 복원 성공 메시지
          } else {
            _showToast('프리미엄 활성화 완료 🎉'); // 일반 구매 성공 메시지
          }
          // TODO: UserDataProvider.isSubscribed = true 반영
          break;

        case PurchaseStatus.pending:
          _showToast('결제 진행 중…');
          break;

        case PurchaseStatus.canceled:
          if (_restoring) {
            _restoreTimer?.cancel();
            _restoring = false;
          }
          _showToast('구매가 취소되었습니다.');
          break;

        case PurchaseStatus.error:
          if (_restoring) {
            _restoreTimer?.cancel();
            _restoring = false;
          }
          _showToast('구매 실패: ${p.error}');
          break;
      }
    }
  }

  Future<void> _buy() async {
    if (widget.isPremium) {
      _openSubscriptionSettings();
      _showToast('이미 프리미엄 구독 중입니다.');
      return;
    }
    if (!_billingAvailable) {
      _showToast('스토어 사용 불가');
      return;
    }
    if (_product == null) {
      _showToast('상품을 찾지 못했습니다');
      return;
    }
    try {
      final param = PurchaseParam(productDetails: _product!);
      await _iap.buyNonConsumable(purchaseParam: param); // 구독도 이 메서드 사용
    } catch (e) {
      _showToast('구매 요청 실패: $e');
    }
  }

  Future<void> _restore() async {
    if (_restoring) return; // 중복 탭 방지
    try {
      _restoring = true;
      _showToast('복원 요청을 보냈어요. 잠시만 기다려 주세요.');
      _startRestoreTimeout(); // 8초 대기 후 미응답이면 안내

      await _iap.restorePurchases(); // 결과는 purchaseStream으로 옴
    } catch (e) {
      _restoreTimer?.cancel();
      _restoring = false;
      _showToast('복원 요청 실패: $e');
    }
  }


  void _showToast(String msg) {
    _lastMessage = msg;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  void dispose() {
    _restoreTimer?.cancel();
    _purchaseSub?.cancel();
    super.dispose();
  }

  // ====== UI ======

  final List<ChallengePreview> premiumChallenges = [
    ChallengePreview(
      id: 'a_study_of_love',
      title: '사랑에 대한 탐구',
      imagePath: 'assets/image/a_study_of_love.JPEG',
      isPremium: true,
      bookTitles: [
        '사랑의 기술',
        '화성에서 온 남자 금성에서 온 여자',
        '연애의 이해',
        "왜 나는 너를 사랑하는가",
        "잃어버린 시간을 찾아서"
      ],
    ),
    ChallengePreview(
      id: 'self_respect_kit',
      title: '자존감 회복 키트',
      imagePath: 'assets/image/self_respect_kit.jpg',
      isPremium: true,
      bookTitles: ['자존감 수업', '나는 나로 살기로 했다', '미움받을 용기'],
    ),
    ChallengePreview(
      id: 'founders_desk',
      title: '창업가의 책상',
      imagePath: 'assets/image/founders_desk.png',
      isPremium: true,
      bookTitles: ['제로투원', '린스타트업', '하드씽', "OKR"],
    ),
    ChallengePreview(
      id: 'essay_lover',
      title: 'For Essay Lover',
      imagePath: 'assets/image/essay_lover.jpg',
      isPremium: true,
      bookTitles: ['결혼ㆍ여름', '호주머니 속의 축제', '불안', "달리기를 말할 때 내가 하고 싶은 이야기"],
    ),
    ChallengePreview(
      id: 'travel_reads',
      title: '휴가, 책',
      imagePath: 'assets/image/travel_reads.jpg',
      isPremium: true,
      bookTitles: ['여행의 기술', '먹고 기도하고 사랑하라', '행복의 지도'],
    ),
    ChallengePreview(
      id: 'ai_and_future',
      title: 'AI & Future',
      imagePath: 'assets/image/ai_and_future.jpg',
      isPremium: true,
      bookTitles: ['맥스 테그마크의 라이프 3.0', '호모데우스', 'AI 슈퍼파워'],
    ),
    ChallengePreview(
      id: 'mastering_writing',
      title: 'Mastering Writing',
      imagePath: 'assets/image/mastering_writing.jpg',
      isPremium: true,
      bookTitles: ['유혹하는 글쓰기', '유시민의 글쓰기 특강', '대통령의 글쓰기'],
    ),
    ChallengePreview(
      id: 'han_kang_mastery',
      title: '한강 작가 읽기',
      imagePath: 'assets/image/han_kang_challenge.jpg',
      isPremium: true,
      bookTitles: ['채식주의자', '소년이 온다', '흰'],
    ),
    ChallengePreview(
      id: 'social_issues_explorer',
      title: '현대 사회 4대 이슈 탐구',
      imagePath: 'assets/image/social_issues_explorer.png',
      isPremium: true,
      bookTitles: ['2050 거주불능 지구', '슈퍼인텔리전스: 경로, 위험, 전략', '벌거벗은 정신력', "보이지 않는 여자들"],
    ),
  ];

  void _openSubscriptionSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F3C34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),

              if (widget.isPremium)
                ListTile(
                  leading: const Icon(Icons.verified, color: Colors.white70),
                  title: Text(
                    widget.premiumUntil != null
                        ? '프리미엄 활성화됨 · 만료 ${_formatDate(widget.premiumUntil!)}'
                        : '프리미엄 활성화됨',
                    style: const TextStyle(color: Colors.white, fontFamily: 'Kopub'),
                  ),
                ),

              ListTile(
                leading: const Icon(Icons.manage_accounts, color: Colors.white70),
                title: const Text('구독 관리 열기',
                    style: TextStyle(color: Colors.white, fontFamily: 'Kopub')),
                subtitle: const Text(
                  '스토어 구독 관리 페이지로 이동합니다.',
                  style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4, fontFamily: 'Kopub'),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openManageSubscriptions();
                },
              ),

              ListTile(
                leading: const Icon(Icons.restore, color: Colors.white70),
                title: const Text('구매 내역 복원',
                    style: TextStyle(color: Colors.white, fontFamily: 'Kopub')),
                subtitle: const Text(
                  '기기를 바꾸거나 앱을 다시 설치했을 때 구독을 불러옵니다.\n같은 스토어 계정이어야 하며 추가 결제는 없습니다.',
                  style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4, fontFamily: 'Kopub'),
                ),
                isThreeLine: true,
                onTap: () {
                  Navigator.pop(context);
                  _restore();
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 20) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF013328),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            "PREMIUM UPGRADE",
            style: TextStyle(color: Colors.white, fontFamily: 'Kopub', letterSpacing: 1.2),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert_outlined),
              tooltip: '설정',
              onPressed: _openSubscriptionSettings, // ⬅️ 아래 함수 추가
            ),
          ],
        ),


        bottomNavigationBar: Container(
          padding: EdgeInsets.fromLTRB(
            screenWidth * 0.08,
            16,
            screenWidth * 0.08,
            MediaQuery.of(context).padding.bottom + 16,
          ),
          decoration: const BoxDecoration(color: Color(0xFF013328)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ 구독 상태에 따라 문구 분기
              Text(
                widget.isPremium
                    ? (widget.premiumUntil != null
                    ? '프리미엄 활성화됨 · 만료 ${_formatDate(widget.premiumUntil!)}'
                    : '프리미엄 활성화됨')
                    : (_product?.price != null
                    ? '${_product!.price}/월 구독으로 독서를 확장하세요'
                    : '₩4,200/월 구독으로 독서를 확장하세요'),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),

              // ✅ 버튼 동작/스타일 분기
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading
                      ? null
                      : (widget.isPremium ? _openSubscriptionSettings : _buy),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    widget.isPremium ? const Color(0xFF3DB39E) : Colors.amberAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    widget.isPremium ? '구독 관리 열기' : '프리미엄으로 업그레이드',
                    style: const TextStyle(color: Colors.black, fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),

        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          child: Column(
            children: [
              // 상단 배너
              Stack(
                children: [
                  Image.asset(
                    'assets/image/premium_banner.jpg',
                    width: double.infinity,
                    height: screenHeight * 0.35,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: screenHeight * 0.08,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: const [
                        Text("Read. Challenge. Grow.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.amberAccent, fontSize: 16)),
                        SizedBox(height: 85),
                        Text("Labrary와 함께\n책을 통해 더 넓은 세계를 만나보세요.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // 혜택 리스트
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("한 눈에 보는 프리미엄 혜택",
                        style: TextStyle(
                            fontSize: 20, fontFamily: 'Kopub', fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 6),
                    const Text("Premium과 함께라면 이 모든 혜택이 무제한!",
                        style: TextStyle(fontSize: 14, fontFamily: 'Kopub', color: Colors.white60)),
                    const SizedBox(height: 24),
                    ..._buildBenefitItems(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),

              _buildPremiumChallengeSlider(screenWidth, screenHeight),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBenefitItems() {
    const benefitData = [
      ["커스텀 챌린지 무제한", "도서·기간·목표를 내 취향대로", Icons.all_inclusive],
      ["커스텀 서재 무제한", "자유로운 개인 서재 생성", Icons.library_add],
      ["프리미엄 전용 챌린지", "프리미엄 챌린지 도전 가능", Icons.star],
      ["광고 제거", "쾌적한 이용 환경 제공", Icons.block],
    ];

    return benefitData.map((item) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(item[2] as IconData, color: Colors.amberAccent, size: 26),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item[0] as String,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16, fontFamily: 'Kopub', fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(item[1] as String,
                    style: const TextStyle(color: Colors.white70, fontFamily: 'Kopub', fontSize: 13)),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildPremiumChallengeSlider(double screenWidth, double screenHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
          child: const Text(
            "프리미엄 챌린지 미리보기",
            style: TextStyle(fontSize: 20, fontFamily: 'Kopub', fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: screenHeight * 0.33,
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.82),
            itemCount: premiumChallenges.length,
            itemBuilder: (context, index) {
              final challenge = premiumChallenges[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(challenge.imagePath, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
                    ),
                    Container(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.black.withOpacity(0.35)),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(challenge.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Kopub', height: 1.4)),
                            const SizedBox(height: 15),
                            ...challenge.bookTitles.map((book) => Text("• $book",
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70, fontSize: 15, fontFamily: 'Kopub'))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Future<void> _openManageSubscriptions() async {
    String url;
    if (Platform.isAndroid) {
      final info = await PackageInfo.fromPlatform();
      final pkg = info.packageName;
      // sku는 콘솔의 productId
      final sku = _product?.id ?? 'premium_monthly';
      url = 'https://play.google.com/store/account/subscriptions?sku=$sku&package=$pkg';
    } else if (Platform.isIOS) {
      // iOS 구독 관리(앱 구독 관리 페이지)
      url = 'https://apps.apple.com/account/subscriptions';
    } else {
      _showToast('이 플랫폼에서는 구독 관리를 열 수 없습니다.');
      return;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showToast('구독 관리 페이지를 열 수 없습니다.');
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';

}
