import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dayverse_book/provider/user_data_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dayverse_book/service/subscription_service.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/model/challenge_model.dart';

class PremiumUpgradeScreen extends StatefulWidget {
  const PremiumUpgradeScreen({super.key});

  @override
  State<PremiumUpgradeScreen> createState() => _PremiumUpgradeScreenState();
}

class _PremiumUpgradeScreenState extends State<PremiumUpgradeScreen> {
  // ====== IAP (나중에 바로 원복 가능하게 유지) ======
  static const String _appleProductId = 'labrary_premium_monthly';
  static const String _googleProductId = 'premium_monthly';

  Set<String> get _productIds {
    if (Platform.isAndroid) {
      return {_googleProductId};
    }

    if (Platform.isIOS) {
      return {_appleProductId};
    }

    return {};
  }
  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  bool _billingAvailable = false;
  bool _loading = true;
  ProductDetails? _product;

  bool _restoring = false;
  Timer? _restoreTimer;

  // ✅ 런칭 이벤트 프리미엄 여부 (UserDataProvider 상수 기반)
  bool get _isEventPremium =>
      UserDataProvider.kLaunchEventPremiumEnabled &&
          DateTime.now().isBefore(UserDataProvider.kLaunchEventEnd);

  @override
  void initState() {
    super.initState();
    _initIap();
  }


  Future<void> _initIap() async {
    debugPrint('📱 Platform.operatingSystem: ${Platform.operatingSystem}');
    debugPrint('📱 Platform.isAndroid: ${Platform.isAndroid}');
    debugPrint('📱 Platform.isIOS: ${Platform.isIOS}');
    debugPrint('📱 defaultTargetPlatform: $defaultTargetPlatform');


    try {
      _purchaseSub = _iap.purchaseStream.listen(
        _onPurchases,
        onError: (e) => _showToast('구매 스트림 오류: $e'),
      );

      final available = await _iap.isAvailable();
      _billingAvailable = available;

      debugPrint('🛒 스토어 결제 사용 가능: $available');
      debugPrint('🛒 조회할 상품 ID: $_productIds');

      if (!available) {
        _showToast('스토어 결제를 사용할 수 없습니다.');
        return;
      }

      final resp = await _iap.queryProductDetails(_productIds);

      debugPrint('🛒 조회된 상품 수: ${resp.productDetails.length}');
      debugPrint('🛒 조회되지 않은 ID: ${resp.notFoundIDs}');
      debugPrint('🛒 상품 조회 오류: ${resp.error}');

      if (resp.error != null) {
        _showToast('상품 조회 오류: ${resp.error}');
      } else if (resp.productDetails.isEmpty) {
        _showToast('상품을 찾을 수 없습니다.');
      } else {
        _product = resp.productDetails.first;

        debugPrint('✅ 상품 조회 성공: ${_product!.id}');
        debugPrint('✅ 상품 가격: ${_product!.price}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ IAP 초기화 오류: $e');
      debugPrint('$stackTrace');
      _showToast('초기화 오류: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _startRestoreTimeout([Duration d = const Duration(seconds: 8)]) {
    _restoreTimer?.cancel();
    _restoreTimer = Timer(d, () {
      if (!_restoring) return;
      _restoring = false;
      _showToast('복원할 내역을 찾지 못했어요. 같은 스토어 계정인지 확인해 주세요.');
    });
  }

  void _finishRestoreSuccess() {
    _restoreTimer?.cancel();
    _restoring = false;
    _showToast('복원 완료! 프리미엄이 활성화됐어요.');
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    debugPrint('📦 purchaseStream 수신');
    debugPrint('📦 구매 내역 개수: ${purchases.length}');

    for (final purchase in purchases) {
      debugPrint('📦 상품 ID: ${purchase.productID}');
      debugPrint('📦 구매 ID: ${purchase.purchaseID}');
      debugPrint('📦 구매 상태: ${purchase.status}');
      debugPrint(
        '📦 pendingCompletePurchase: ${purchase.pendingCompletePurchase}',
      );

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _handleVerifiedPurchase(purchase);
          break;

        case PurchaseStatus.pending:
          _showToast('결제 진행 중…');
          break;

        case PurchaseStatus.canceled:
          _finishRestoreFailure();
          _showToast('구매가 취소되었습니다.');
          break;

        case PurchaseStatus.error:
          _finishRestoreFailure();
          _showToast(
            purchase.error?.message != null
                ? '구매 실패: ${purchase.error!.message}'
                : '구매 처리 중 오류가 발생했습니다.',
          );
          break;
      }
    }
  }

  Future<void> _handleVerifiedPurchase(
      PurchaseDetails purchase,
      ) async {
    bool shouldCompletePurchase = false;

    try {
      // 스낵바가 연속으로 두 번 뜨므로 이 메시지는 제거
      // _showToast('구독 상태를 확인하고 있어요…');

      final verification =
      await SubscriptionService.instance.verifyPurchase(
        purchase,
      );

      if (!verification.success) {
        _finishRestoreFailure();

        _showToast(
          verification.message ?? '구독 내역을 확인하지 못했습니다.',
        );

        return;
      }

      // 서버에서 정상적으로 확인한 거래이므로 StoreKit 거래 종료 가능
      shouldCompletePurchase = true;

      debugPrint('✅ 구독 서버 검증 성공');
      debugPrint('✅ 활성 상태: ${verification.active}');
      debugPrint('✅ 상품 ID: ${verification.productId}');
      debugPrint('✅ 만료일: ${verification.expiresAt}');
      debugPrint('✅ 환경: ${verification.environment}');

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        debugPrint('✅ Apple 거래 ID: ${verification.transactionId}');
        debugPrint(
          '✅ Apple 원본 거래 ID: '
              '${verification.originalTransactionId}',
        );
        debugPrint('✅ Apple 상태 코드: ${verification.status}');
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        debugPrint(
          '✅ Google Play 주문 ID: '
              '${verification.latestOrderId}',
        );
        debugPrint(
          '✅ Google Play 상태: '
              '${verification.androidStatus}',
        );
        debugPrint(
          '✅ Google Play 승인 상태: '
              '${verification.acknowledgementState}',
        );
      }

      if (!verification.active) {
        _finishRestoreFailure();

        _showToast(
          verification.message ??
              '현재 활성화된 프리미엄 구독이 없습니다.',
        );

        return;
      }

      if (_restoring) {
        _finishRestoreSuccess();
      } else {
        _showToast('프리미엄 구독이 활성화됐어요 🎉');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 구매 검증 처리 실패: $e');
      debugPrint('$stackTrace');

      _finishRestoreFailure();

      final message = e.toString();

      if (message.contains('다른 Labrary 계정')) {
        // 영구적인 소유권 충돌이므로 현재 pending 거래는 종료
        shouldCompletePurchase = true;

        _showToast(
          '이 Apple 구독은 다른 Labrary 계정에 연결되어 있습니다.',
        );
      } else {
        // 네트워크 오류 등 일시적인 실패라면 거래를 완료하지 않고
        // 다음 실행 또는 복원 때 재검증할 수 있게 둔다.
        _showToast('구독 확인 중 오류가 발생했습니다.');
      }
    } finally {
      if (
      shouldCompletePurchase &&
          purchase.pendingCompletePurchase
      ) {
        try {
          await _iap.completePurchase(purchase);

          debugPrint(
            '✅ 스토어 거래 완료 처리: ${purchase.productID}',
          );
        } catch (e, stackTrace) {
          debugPrint('❌ 스토어 거래 완료 처리 실패: $e');
          debugPrint('$stackTrace');
        }
      }
    }
  }

  void _finishRestoreFailure() {
    if (!_restoring) return;

    _restoreTimer?.cancel();
    _restoring = false;
  }

  Future<void> _buy() async {
    // ✅ 이벤트 기간에는 결제 막기
    if (_isEventPremium) {
      _showToast('런칭 이벤트 기간에는 결제 없이 프리미엄이 제공돼요 😊');
      return;
    }

    final isPremium = context.read<UserDataProvider>().isPremiumActive;

    if (isPremium) {
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
      // 구독도 buyNonConsumable로 처리 가능(패키지 내부에서 처리)
      await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e, stackTrace) {
      debugPrint('❌ 구매 요청 실패: $e');
      debugPrint('$stackTrace');

      final message = e.toString();

      if (message.contains('storekit_duplicate_product_object') ||
          message.contains('pending transaction')) {
        _showToast(
          '이전 결제 처리가 아직 완료되지 않았습니다. '
              '잠시 후 다시 시도해주세요.',
        );
      } else {
        _showToast('구매 요청 중 오류가 발생했습니다.');
      }
    }
  }

  Future<void> _restore() async {
    if (_isEventPremium) {
      _showToast('런칭 이벤트 기간에는 복원이 필요 없어요 😊');
      return;
    }

    if (_restoring) {
      debugPrint('⚠️ 이미 구매 복원 진행 중');
      return;
    }

    try {
      debugPrint('🔄 구매 내역 복원 시작');

      _restoring = true;
      _showToast('복원 요청을 보냈어요. 잠시만 기다려 주세요.');
      _startRestoreTimeout();

      await _iap.restorePurchases();

      debugPrint('🔄 restorePurchases 호출 완료');
      debugPrint('🔄 이제 purchaseStream 응답 대기 중');
    } catch (e, stackTrace) {
      debugPrint('❌ 구매 내역 복원 요청 실패: $e');
      debugPrint('$stackTrace');

      _restoreTimer?.cancel();
      _restoring = false;
      _showToast('복원 요청 실패: $e');
    }
  }

  void _openSubscriptionSettings() {
    if (_isEventPremium) {
      _showEventInfoSheet();
      return;
    }

    final storeName = Platform.isAndroid ? 'Google Play' : 'Apple';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F3C34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final isPremium = context.watch<UserDataProvider>().isPremiumActive;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              if (isPremium)
                const ListTile(
                  leading: Icon(Icons.verified, color: Colors.white70),
                  title: Text(
                    '프리미엄 활성화됨',
                    style: TextStyle(color: Colors.white, fontFamily: 'Kopub'),
                  ),
                ),

              ListTile(
                leading: const Icon(Icons.manage_accounts, color: Colors.white70),
                title: const Text(
                  '구독 관리 및 해지',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Kopub',
                  ),
                ),
                subtitle: Text(
                  '$storeName 구독 관리 화면에서 구독을 변경하거나 해지할 수 있습니다.',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.4,
                    fontFamily: 'Kopub',
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openManageSubscriptions();
                },
              ),

              ListTile(
                leading: const Icon(Icons.restore, color: Colors.white70),
                title: const Text('구매 내역 복원', style: TextStyle(color: Colors.white, fontFamily: 'Kopub')),
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

  void _showEventInfoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F3C34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final end = UserDataProvider.kLaunchEventEnd;
        final endText = '${end.year}.${end.month.toString().padLeft(2, '0')}.${end.day.toString().padLeft(2, '0')}';

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const ListTile(
                leading: Icon(Icons.card_giftcard, color: Color(0xFF3DB39E)),
                title: Text(
                  '런칭 이벤트 프리미엄 제공 중',
                  style: TextStyle(color: Colors.white, fontFamily: 'Kopub'),
                ),
                subtitle: Text(
                  '현재는 결제 없이 프리미엄 기능을 모두 이용할 수 있어요.',
                  style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4, fontFamily: 'Kopub'),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.schedule, color: Colors.white70),
                title: Text(
                  '이벤트 종료 예정: $endText',
                  style: const TextStyle(color: Colors.white, fontFamily: 'Kopub'),
                ),
                subtitle: const Text(
                  '이벤트 종료 후 프리미엄 결제가 다시 활성화될 수 있어요.',
                  style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4, fontFamily: 'Kopub'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showToast(String msg) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    // 기존 스낵바가 큐에 쌓이지 않도록 교체
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  @override
  void dispose() {
    _restoreTimer?.cancel();
    _purchaseSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userData = context.watch<UserDataProvider>();
    final isPremium = userData.isPremiumActive; // ✅ 만료 포함
    final isAnonymous = FirebaseAuth.instance.currentUser?.isAnonymous ?? true;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final isEventPremium = _isEventPremium;


    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 20) Navigator.pop(context);
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: const Color(0xFF013328),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            "PREMIUM",
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Kopub',
              fontWeight: FontWeight.w600,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: Platform.isIOS || Platform.isAndroid
              ? [
            IconButton(
              icon: const Icon(Icons.more_vert_outlined),
              tooltip: '설정',
              onPressed: _openSubscriptionSettings,
            ),
          ]
              : null,
        ),
        bottomNavigationBar: Platform.isIOS || Platform.isAndroid
            ? _buildPremiumBottomCta(
          screenWidth: screenWidth,
          isPremium: isPremium,
          isEventPremium: isEventPremium,
          canPurchase: _billingAvailable && _product != null,
        )

            : null,
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
            : SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 150,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              _buildPremiumHero(screenWidth, screenHeight),

              if (isAnonymous)
                Container(
                  margin: EdgeInsets.fromLTRB(
                    screenWidth * 0.06,
                    0,
                    screenWidth * 0.06,
                    20,
                  ),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.10),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '게스트 상태에서도 구독할 수 있어요. '
                              '현재 기록과 계정을 안전하게 유지하려면 새 계정으로 회원가입해주세요.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.5,
                            fontFamily: 'Kopub',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const Text(
                      "프리미엄 혜택",
                      style: TextStyle(
                        fontSize: 21,
                        fontFamily: 'Kopub',
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "독서 습관을 더 오래 유지하게 만드는 기능들",
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Kopub',
                        color: Colors.white.withOpacity(0.58),
                      ),
                    ),
                    const SizedBox(height: 18),

                    _buildPremiumBenefitGrid(screenWidth),

                    SizedBox(height: screenHeight * 0.04),
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

  Widget _buildPremiumHero(double screenWidth, double screenHeight) {
    return Container(
      height: screenHeight * 0.4,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/image/premium_banner.jpg',
            fit: BoxFit.cover,
          ),

          Container(
            color: Colors.black.withOpacity(0.32),
          ),

          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.10),
                  Colors.transparent,
                  const Color(0xFF013328).withOpacity(0.98),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),

          if (_isEventPremium)
            Positioned(
              top: 18,
              left: screenWidth * 0.06,
              right: screenWidth * 0.06,
              child: _buildEventHeroBadge(screenWidth),
            ),

          Positioned(
            left: screenWidth * 0.07,
            right: screenWidth * 0.07,
            bottom: screenHeight * 0.08,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.amberAccent.withOpacity(0.55),
                    ),
                  ),

                  child: const Text(
                    'LABRARY PREMIUM',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                      fontFamily: 'Kopub',
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Text(
                  '프리미엄과 함께\n더 큰 성장을 이루세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Kopub',
                    fontSize: screenWidth * 0.06,
                    height: 1.24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),

                const SizedBox(height: 12),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventHeroBadge(double screenWidth) {
    final end = UserDataProvider.kLaunchEventEnd;
    final endText =
        '${end.year}.${end.month.toString().padLeft(2, '0')}.${end.day.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.38),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.amberAccent.withOpacity(0.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.amberAccent.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: Colors.amberAccent,
              size: 18,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '런칭 이벤트 프리미엄 무료 제공 중',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'Kopub',
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '종료 예정 $endText',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.68),
                    fontSize: 11.5,
                    height: 1.3,
                    fontFamily: 'Kopub',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBenefitGrid(double screenWidth) {
    final items = [
      {
        "title": "커스텀 서재 무제한",
        "desc": "나만의 서재를\n무제한으로 만들기",
        "icon": Icons.library_books_rounded,
      },
      {
        "title": "커스텀 챌린지 무제한",
        "desc": "내 목표에 맞는 챌린지\n무제한 생성",
        "icon": Icons.all_inclusive_rounded,
      },
      {
        "title": "프리미엄 전용 챌린지",
        "desc": "프리미엄 전용 챌린지\n참여 가능",
        "icon": Icons.auto_awesome_rounded,
      },
      {
        "title": "광고 제거",
        "desc": "방해 없이 몰입하는\n독서 경험",
        "icon": Icons.block_rounded,
      },
    ];

    return GridView.count(
      padding: EdgeInsets.zero,
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.08,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item["icon"] as IconData,
                  color: Colors.amberAccent,
                  size: 23,
                ),
              ),

              const Spacer(),

              Text(
                item["title"] as String,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: screenWidth * 0.039,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Kopub',
                ),
              ),

              const SizedBox(height: 6),

              Text(
                item["desc"] as String,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.62),
                  fontSize: screenWidth * 0.031,
                  height: 1.35,
                  fontFamily: 'Kopub',
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formattedProductPrice(BuildContext context) {
    final product = _product;

    if (product == null) {
      return '가격 정보를 불러오는 중';
    }

    final locale = Localizations.localeOf(context).toString();

    return NumberFormat.currency(
      locale: locale,
      name: product.currencyCode,
      symbol: product.currencySymbol,
      decimalDigits: product.currencyCode == 'KRW' ? 0 : null,
    ).format(product.rawPrice);
  }

  Widget _buildPremiumBottomCta({
    required double screenWidth,
    required bool isPremium,
    required bool isEventPremium,
    required bool canPurchase,
  }) {
    final priceText = isEventPremium
        ? '런칭 이벤트로 프리미엄 무료 제공 중'
        : isPremium
        ? '프리미엄 활성화됨'
        : _product != null
        ? '${_formattedProductPrice(context)}/월'
        : '가격 정보를 불러오는 중';

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          screenWidth * 0.05,
          8,
          screenWidth * 0.05,
          14,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF082B25).withOpacity(0.96),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withOpacity(0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.32),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.amberAccent,
                    size: 23,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      priceText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Kopub',
                      ),
                    ),
                  ),
                  if (!isPremium && !isEventPremium)
                    Text(
                      '언제든 해지 가능',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.48),
                        fontSize: 12,
                        fontFamily: 'Kopub',
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 13),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading
                      ? null
                      : isEventPremium
                      ? () {
                    _showToast(
                      '런칭 이벤트 기간에는 결제 없이 프리미엄이 제공돼요 😊',
                    );
                  }
                      : isPremium
                      ? _openSubscriptionSettings
                      : canPurchase
                      ? _buy
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEventPremium || isPremium
                        ? const Color(0xFF3DB39E)
                        : Colors.amberAccent,
                    foregroundColor: const Color(0xFF013328),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    isEventPremium
                        ? '이벤트 프리미엄 이용 중'
                        : isPremium
                        ? '구독 관리 및 해지'
                        : canPurchase
                        ? '프리미엄 시작하기'
                        : '결제 정보를 불러올 수 없어요',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Kopub',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumChallengeSlider(
      double screenWidth,
      double screenHeight,
      ) {
    final challengeProvider =
    context.watch<ChallengeProvider>();

    final premiumChallenges =
    challengeProvider.allChallenges
        .where(
          (challenge) =>
      challenge.isPremium &&
          !challenge.isArchived &&
          !challenge.isCustom,
    )
        .take(7)
        .toList();

    if (premiumChallenges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.06,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Text(
                "프리미엄 챌린지 미리보기",
                style: TextStyle(
                  fontSize: 21,
                  fontFamily: 'Kopub',
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Labrary가 큐레이션한 독서 챌린지",
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Kopub',
                  color:
                  Colors.white.withOpacity(0.58),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        SizedBox(
          height: screenHeight * 0.34,
          child: PageView.builder(
            controller: PageController(
              viewportFraction: 0.84,
            ),
            itemCount:
            premiumChallenges.length +1,

            itemBuilder: (context, index) {
              if (index == premiumChallenges.length) {
                return _buildMorePremiumChallengeCard(
                  screenWidth,
                );
              }

              final challenge =
              premiumChallenges[index];

              final bookTitles =
              (challenge.requiredBooks ??
                  challenge.participatingBooks ??
                  const [])
                  .map(
                    (book) =>
                book.title,
              )
                  .where(
                    (title) =>
                title.trim().isNotEmpty,
              )
                  .toList();

              return Padding(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 7,
                ),
                child: ClipRRect(
                  borderRadius:
                  BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildPremiumChallengeImage(
                        challenge.imageUrl,
                      ),

                      Container(
                        color:
                        Colors.black.withOpacity(
                          0.32,
                        ),
                      ),

                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin:
                            Alignment.topCenter,
                            end:
                            Alignment.bottomCenter,
                            colors: [
                              Colors.black
                                  .withOpacity(0.15),
                              Colors.transparent,
                              Colors.black
                                  .withOpacity(0.82),
                            ],
                            stops: const [
                              0.0,
                              0.36,
                              1.0,
                            ],
                          ),
                        ),
                      ),

                      Positioned(
                        left: 18,
                        right: 18,
                        top: 18,
                        child: Row(
                          children: [
                            Container(
                              padding:
                              const EdgeInsets
                                  .symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration:
                              BoxDecoration(
                                color: Colors
                                    .amberAccent
                                    .withOpacity(0.18),
                                borderRadius:
                                BorderRadius
                                    .circular(999),
                                border: Border.all(
                                  color: Colors
                                      .amberAccent
                                      .withOpacity(
                                    0.45,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'PREMIUM',
                                style: TextStyle(
                                  color:
                                  Colors.amberAccent,
                                  fontSize: 10,
                                  fontWeight:
                                  FontWeight.w800,
                                  letterSpacing: 1.2,
                                  fontFamily: 'Kopub',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 22,
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              challenge.title,
                              maxLines: 2,
                              overflow:
                              TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize:
                                screenWidth *
                                    0.052,
                                fontWeight:
                                FontWeight.w900,
                                fontFamily: 'Kopub',
                                height: 1.25,
                              ),
                            ),

                            if (bookTitles
                                .isNotEmpty) ...[
                              const SizedBox(
                                height: 12,
                              ),

                              ...bookTitles
                                  .take(3)
                                  .map(
                                    (book) =>
                                    Padding(
                                      padding:
                                      const EdgeInsets
                                          .only(
                                        bottom: 4,
                                      ),
                                      child: Text(
                                        '• $book',
                                        maxLines: 1,
                                        overflow:
                                        TextOverflow
                                            .ellipsis,
                                        style:
                                        TextStyle(
                                          color: Colors
                                              .white
                                              .withOpacity(
                                            0.72,
                                          ),
                                          fontSize: 13,
                                          fontFamily:
                                          'Kopub',
                                        ),
                                      ),
                                    ),
                              ),

                              if (bookTitles.length >
                                  3)
                                Padding(
                                  padding:
                                  const EdgeInsets
                                      .only(
                                    top: 2,
                                  ),
                                  child: Text(
                                    '+ ${bookTitles.length - 3}권 더',
                                    style:
                                    const TextStyle(
                                      color: Colors
                                          .amberAccent,
                                      fontSize: 13,
                                      fontWeight:
                                      FontWeight
                                          .w800,
                                      fontFamily:
                                      'Kopub',
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 34),
      ],
    );
  }

  Widget _buildPremiumChallengeImage(
      String imageUrl,
      ) {
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (
            _,
            __,
            ___,
            ) {
          return Container(
            color: const Color(0xFF16483F),
          );
        },
      );
    }

    return Image.asset(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (
          _,
          __,
          ___,
          ) {
        return Container(
          color: const Color(0xFF16483F),
        );
      },
    );
  }

  Widget _buildMorePremiumChallengeCard(
      double screenWidth,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
      ),
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: const Color(0xFF16483F),
          borderRadius:
          BorderRadius.circular(24),
          border: Border.all(
            color:
            Colors.amberAccent.withOpacity(
              0.22,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Container(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.amberAccent
                    .withOpacity(0.14),
                borderRadius:
                BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.amberAccent
                      .withOpacity(0.35),
                ),
              ),
              child: const Text(
                'AND MORE',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  fontFamily: 'Kopub',
                ),
              ),
            ),

            const Spacer(),

            Icon(
              Icons.auto_awesome_rounded,
              color: Colors.amberAccent,
              size: screenWidth * 0.09,
            ),

            SizedBox(
              height: screenWidth * 0.04,
            ),

            Text(
              '더 많은 프리미엄\n챌린지가 기다리고 있어요',
              style: TextStyle(
                color: Colors.white,
                fontSize:
                screenWidth * 0.052,
                height: 1.3,
                fontWeight: FontWeight.w900,
                fontFamily: 'Kopub',
              ),
            ),

            SizedBox(
              height: screenWidth * 0.035,
            ),

            Text(
              '다양한 주제의 새로운 챌린지가\n계속해서 추가됩니다.',
              style: TextStyle(
                color:
                Colors.white.withOpacity(
                  0.6,
                ),
                fontSize:
                screenWidth * 0.032,
                height: 1.5,
                fontFamily: 'Kopub',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openManageSubscriptions() async {
    // ✅ 이벤트 기간엔 구독 관리 링크가 의미 없으니 안내만
    if (_isEventPremium) {
      _showToast('런칭 이벤트 기간에는 구독 관리가 필요 없어요 😊');
      return;
    }

    String url;
    if (Platform.isAndroid) {
      final info = await PackageInfo.fromPlatform();
      final pkg = info.packageName;
      final sku = _product?.id ?? _googleProductId;
      url = 'https://play.google.com/store/account/subscriptions?sku=$sku&package=$pkg';
    } else if (Platform.isIOS) {
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
}
