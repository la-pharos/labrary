import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class ChallengeShareService {
  static const String baseUrl =
      'https://la-pharos.web.app/challenge';

  static Future<void> shareChallenge({
    required BuildContext context,
    required String challengeId,
    required String challengeTitle,
    required String challengeDescription,
  }) async {
    final Uri url = Uri.parse(
      '$baseUrl/${Uri.encodeComponent(challengeId)}',
    );

    final box = context.findRenderObject() as RenderBox?;

    await SharePlus.instance.share(
      ShareParams(
        // iOS가 URL의 링크 메타데이터를 읽도록 전달
        uri: url,

        title: '$challengeTitle | Labrary',
        subject: challengeTitle,

        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }
}