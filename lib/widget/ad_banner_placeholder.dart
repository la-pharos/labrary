import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import 'package:dayverse_book/provider/user_data_provider.dart';

String getBannerAdUnitId(AdSize adSize) {
  // 디버그 모드: Google 테스트 광고 ID 사용
  if (!kReleaseMode) {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111';
    }

    if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716';
    }
  }

  // Android 운영 광고 ID
  if (Platform.isAndroid) {
    if (adSize == AdSize.largeBanner) {
      return 'ca-app-pub-2078077942953061/3929139084';
    }

    return 'ca-app-pub-2078077942953061/5792885098';
  }

  // iOS 운영 광고 ID
  if (Platform.isIOS) {
    if (adSize == AdSize.largeBanner) {
      return 'ca-app-pub-2078077942953061/7481411488';
    }

    return 'ca-app-pub-2078077942953061/1924842796';
  }

  throw UnsupportedError('지원하지 않는 플랫폼입니다.');
}

class AdBannerPlaceholder extends StatefulWidget {
  final AdSize adSize;

  const AdBannerPlaceholder({
    super.key,
    this.adSize = AdSize.banner,
  });

  @override
  State<AdBannerPlaceholder> createState() => _AdBannerPlaceholderState();
}

class _AdBannerPlaceholderState extends State<AdBannerPlaceholder> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _shouldShowAd = true;

  @override
  void initState() {
    super.initState();

    // ✅ 프리미엄이면 광고 로드 자체를 하지 않음 (이벤트 프리미엄 포함)
    final userData = context.read<UserDataProvider>();
    _shouldShowAd = !userData.isPremiumActive;
    if (!_shouldShowAd) return;

    _bannerAd = BannerAd(
      adUnitId: getBannerAdUnitId(widget.adSize),
      request: const AdRequest(),
      size: widget.adSize,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Ad failed to load: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Widget build(BuildContext context) {
    final isPremium =
        context.watch<UserDataProvider>().isPremiumActive;

    if (isPremium ||
        !_shouldShowAd ||
        !_isLoaded ||
        _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: widget.adSize.height.toDouble(),
      width: widget.adSize.width.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

/// ✅ 광고 섹션 전체를 Row + Padding으로 감싸서 재사용 가능하게!
Widget buildAdSection(BuildContext context, double screenHeight) {
  final isPremium = context.watch<UserDataProvider>().isPremiumActive;
  if (isPremium) return const SizedBox.shrink();

  return Padding(
    padding: EdgeInsets.symmetric(vertical: screenHeight * 0.005),
    child: const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AdBannerPlaceholder(),
      ],
    ),
  );
}

/// =======================================================================

class AdMediumRectanglePlaceholder extends StatefulWidget {
  const AdMediumRectanglePlaceholder({super.key});

  @override
  State<AdMediumRectanglePlaceholder> createState() => _AdMediumRectanglePlaceholderState();
}

class _AdMediumRectanglePlaceholderState extends State<AdMediumRectanglePlaceholder> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _shouldShowAd = true;

  @override
  void initState() {
    super.initState();

    // ✅ 프리미엄이면 로드 자체를 하지 않음
    final userData = context.read<UserDataProvider>();
    _shouldShowAd = !userData.isPremiumActive;
    if (!_shouldShowAd) return;

    _bannerAd = BannerAd(
      adUnitId: getBannerAdUnitId(AdSize.mediumRectangle),
      request: const AdRequest(),
      size: AdSize.mediumRectangle,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();

          if (!mounted) return;

          setState(() {
            _bannerAd = null;
            _isLoaded = false;
            _shouldShowAd = false;
          });

          debugPrint('Ad failed to load: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<UserDataProvider>().isPremiumActive;
    if (isPremium || !_shouldShowAd) return const SizedBox.shrink();

    if (!_isLoaded) return const SizedBox(height: 250);

    return SizedBox(
      height: 250,
      width: 300,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

Widget buildMediumAdSection(BuildContext context) {
  final isPremium = context.watch<UserDataProvider>().isPremiumActive;
  if (isPremium) return const SizedBox.shrink();

  return const Center(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: AdMediumRectanglePlaceholder(),
    ),
  );
}

/// =======================================================================

class BottomAdBannerBar extends StatelessWidget {
  const BottomAdBannerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<UserDataProvider>().isPremiumActive;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (isPremium) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: screenHeight * 0.015,
          left: screenWidth * 0.04,
          right: screenWidth * 0.04,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            color: const Color(0xFF013328).withOpacity(0.8),
            padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
            child: const Center(
              child: AdBannerPlaceholder(),
            ),
          ),
        ),
      ),
    );
  }
}

class BottomAdLargeBannerBar extends StatelessWidget {
  const BottomAdLargeBannerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<UserDataProvider>().isPremiumActive;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (isPremium) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          left: screenWidth * 0.04,
          right: screenWidth * 0.04,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            color: const Color(0xFF013328).withOpacity(0.8),
            padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
            child: const Center(
              child: AdBannerPlaceholder(adSize: AdSize.largeBanner),
            ),
          ),
        ),
      ),
    );
  }
}

/// =======================================================================
/// 광고배너 크기 (너비, 높이)
/// AdSize.banner           320 x 50
/// AdSize.largeBanner      320 x 100
/// AdSize.mediumRectangle  300 x 250 (리스트 중간 삽입용)
/// AdSize.fullBanner       468 x 60  (태블릿용)
/// AdSize.leaderboard      728 x 90  (큰 화면용)

