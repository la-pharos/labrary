import 'package:flutter/services.dart';

class TextRecognitionService {
  static const MethodChannel _channel =
  MethodChannel(
    'com.la_pharos.labrary/text_recognition',
  );

  static const String _recognizeTextMethod =
      'recognizeText';

  /// 이미지 파일에서 텍스트를 추출한다.
  ///
  /// iOS:
  /// Apple Vision Framework를 호출한다.
  ///
  /// Android:
  /// Google ML Kit를 호출한다.
  Future<String> recognizeText({
    required String imagePath,
  }) async {
    final normalizedPath = imagePath.trim();

    if (normalizedPath.isEmpty) {
      throw const TextRecognitionException(
        code: 'invalid_image_path',
        message: '이미지 경로가 비어 있습니다.',
      );
    }

    try {
      final result =
      await _channel.invokeMethod<String>(
        _recognizeTextMethod,
        <String, dynamic>{
          'imagePath': normalizedPath,
          'languages': <String>[
            'ko-KR',
            'en-US',
          ],
        },
      );

      return _cleanText(result ?? '');
    } on PlatformException catch (e) {
      throw TextRecognitionException(
        code: e.code,
        message:
        e.message ??
            '텍스트를 추출하지 못했습니다.',
        details: e.details,
      );
    } on MissingPluginException {
      throw const TextRecognitionException(
        code: 'plugin_not_registered',
        message:
        '텍스트 추출 기능이 현재 플랫폼에 연결되지 않았습니다.',
      );
    } catch (e) {
      throw TextRecognitionException(
        code: 'unknown_error',
        message:
        '텍스트 추출 중 알 수 없는 오류가 발생했습니다.',
        details: e.toString(),
      );
    }
  }

  String _cleanText(String text) {
    if (text.trim().isEmpty) {
      return '';
    }

    return text
        .replaceAll(
      RegExp(r'[ \t]+'),
      ' ',
    )
        .replaceAll(
      RegExp(r' *\n *'),
      '\n',
    )
        .replaceAll(
      RegExp(r'\n{3,}'),
      '\n\n',
    )
        .trim();
  }
}

class TextRecognitionException
    implements Exception {
  final String code;
  final String message;
  final Object? details;

  const TextRecognitionException({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() {
    return 'TextRecognitionException'
        '(code: $code, '
        'message: $message, '
        'details: $details)';
  }
}