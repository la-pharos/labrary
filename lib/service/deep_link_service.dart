import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/screen/challenge_detail_screen.dart';

class DeepLinkService {
  DeepLinkService._();
  static final instance = DeepLinkService._();

  // 🔧 너의 도메인으로 교체
  static const String _prefix = 'https://labrary.page.link';
  // 앱 내부에서 실제로 열 주소 (파라미터만 파싱해서 라우팅)
  static const String _linkBase = 'https://labrary.app/challenge';

  Future<void> init(BuildContext context) async {
    // 앱이 꺼진 상태에서 링크로 진입
    final pending = await FirebaseDynamicLinks.instance.getInitialLink();
    if (pending?.link != null) _handleUri(context, pending!.link);

    // 실행 중에 링크 수신
    FirebaseDynamicLinks.instance.onLink.listen(
          (data) => _handleUri(context, data.link),
      onError: (e) => debugPrint('🔗 onLink error: $e'),
    );
  }

  Future<Uri> createChallengeLink({
    required String challengeId,
    String? title,
    String? imageUrl,
  }) async {
    final deepLink = Uri.parse('$_linkBase?id=$challengeId');

    final params = DynamicLinkParameters(
      uriPrefix: _prefix,
      link: deepLink,
      androidParameters: const AndroidParameters(
        packageName: 'com.la_pharos.labrary',
        minimumVersion: 1,
      ),
      iosParameters: const IOSParameters(
        bundleId: 'com.laPharos.labrary', // <- iOS 번들ID로 교체
        appStoreId: '000000000',          // 있으면 넣고, 없으면 뺴도 됨
        minimumVersion: '1',
      ),
      socialMetaTagParameters: SocialMetaTagParameters(
        title: title ?? '챌린지',
        description: 'Labrary 챌린지에 참여해보세요!',
        imageUrl: (imageUrl?.isNotEmpty ?? false) ? Uri.tryParse(imageUrl!) : null,
      ),
    );

    final short = await FirebaseDynamicLinks.instance.buildShortLink(params);
    return short.shortUrl; // 짧은 주소 반환
  }

  void _handleUri(BuildContext context, Uri uri) {
    try {
      if (uri.path.contains('/challenge')) {
        final id = uri.queryParameters['id'];
        if (id == null || id.isEmpty) return;

        final prov = context.read<ChallengeProvider>();
        final found = prov.findChallengeById(id);

        if (found != null) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ChallengeDetailScreen(challenge: found)),
          );
        } else {
          // 🔁 없으면 Firestore에서 로드해보거나, “없는 챌린지” 안내
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('해당 챌린지를 찾을 수 없어요.')),
          );
        }
      }
    } catch (e) {
      debugPrint('🔗 handleUri error: $e');
    }
  }
}