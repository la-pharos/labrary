import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/provider/user_data_provider.dart';
import 'dart:io'; // ← 플랫폼 감지를 위해 필요
import 'package:flutter/foundation.dart'; // ← 이거 있어야 kReleaseMode 사용 가능

String getBannerAdUnitId(AdSize adSize) {
  if (!kReleaseMode) {
    // ✅ 테스트 중엔 Google 테스트용 ID 사용
    return 'ca-app-pub-3940256099942544/6300978111';
  }

  if (Platform.isAndroid) {
    if (adSize == AdSize.largeBanner) {
      return 'ca-app-pub-2078077942593061/3929139084'; // BottomAdLargeBannerBar
    } else {
      return 'ca-app-pub-2078077942593061/5792885098'; // BottomAdBannerBar
    }
  } else if (Platform.isIOS) {
    if (adSize == AdSize.largeBanner) {
      return 'YOUR_IOS_AD_UNIT_ID_FOR_LARGE_BANNER';
    } else {
      return 'YOUR_IOS_AD_UNIT_ID_FOR_BANNER';
    }
  }
  return '';
}

class AdBannerPlaceholder extends StatefulWidget {
  final AdSize adSize; // ✅ 추가

  const AdBannerPlaceholder({
    super.key,
    this.adSize = AdSize.banner, // 기본값은 일반 banner
  });

  @override
  State<AdBannerPlaceholder> createState() => _AdBannerPlaceholderState();
}

class _AdBannerPlaceholderState extends State<AdBannerPlaceholder> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();

    _bannerAd = BannerAd(
      adUnitId: getBannerAdUnitId(widget.adSize), // ✅ 이걸로 변경
      request: const AdRequest(),
      size: widget.adSize, // ✅ 여기에 반영
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isLoaded = true),
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

  @override
  Widget build(BuildContext context) {
    final isSubscribed = context.watch<UserDataProvider>().isSubscribed;
    if (isSubscribed) return const SizedBox.shrink();
    if (!_isLoaded) return SizedBox(height: widget.adSize.height.toDouble());

    return SizedBox(
      height: widget.adSize.height.toDouble(),
      width: widget.adSize.width.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}


/// ✅ 광고 섹션 전체를 Row + Padding으로 감싸서 재사용 가능하게!
Widget buildAdSection(BuildContext context, double screenHeight) {
  final isSubscribed = context.watch<UserDataProvider>().isSubscribed;

  if (isSubscribed) return const SizedBox.shrink();

  return Padding(
    padding: EdgeInsets.symmetric(vertical: screenHeight * 0.005),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const AdBannerPlaceholder(),
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

  @override
  void initState() {
    super.initState();

    _bannerAd = BannerAd(
      adUnitId: getBannerAdUnitId(AdSize.mediumRectangle), // ✅ 이걸로 변경
      request: const AdRequest(),
      size: AdSize.mediumRectangle, // ✅ 300x250
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isLoaded = true),
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

  @override
  Widget build(BuildContext context) {
    final isSubscribed = context.watch<UserDataProvider>().isSubscribed;
    if (isSubscribed) return const SizedBox.shrink();
    if (!_isLoaded) return const SizedBox(height: 250);

    return SizedBox(
      height: 250,
      width: 300,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

Widget buildMediumAdSection(BuildContext context) {
  final isSubscribed = context.watch<UserDataProvider>().isSubscribed;
  if (isSubscribed) return const SizedBox.shrink();

  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: const AdMediumRectanglePlaceholder(),
    ),
  );
}

/// =======================================================================

class BottomAdBannerBar extends StatelessWidget {
  const BottomAdBannerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isSubscribed = context.watch<UserDataProvider>().isSubscribed;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (isSubscribed) return const SizedBox.shrink();

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
    final isSubscribed = context.watch<UserDataProvider>().isSubscribed;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (isSubscribed) return const SizedBox.shrink();

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
            padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02), // ✅ 더 큰 padding
            child: const Center(
              child: AdBannerPlaceholder(
                adSize: AdSize.largeBanner // ✅ 광고 크기만 다르게
              ),
            ),
          ),
        ),
      ),
    );
  }
}
/// =======================================================================


/// 광고배너 크기 (너비, 높이)
// AdSize.banner	320	50
// AdSize.largeBanner	320	100
// AdSize.mediumRectangle	300	250 네모 광고, 일반적으로 리스트 중간 삽입용
// AdSize.fullBanner	468	60 태블릿용
// AdSize.leaderboard	728	90 가로형, 큰 화면용
