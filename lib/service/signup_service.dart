import 'package:cloud_functions/cloud_functions.dart';

class SignupService {
  SignupService._();

  static final SignupService instance = SignupService._();

  final FirebaseFunctions _functions =
  FirebaseFunctions.instanceFor(
    region: 'asia-northeast3',
  );

  Future<bool> checkEmailAvailability(String email) async {
    final callable =
    _functions.httpsCallable('checkEmailAvailability');

    final result = await callable.call({
      'email': email.trim().toLowerCase(),
    });

    return result.data['available'] == true;
  }

  Future<bool> checkNicknameAvailability(
      String nickname,
      ) async {
    final callable =
    _functions.httpsCallable('checkNicknameAvailability');

    final result = await callable.call({
      'nickname': nickname.trim(),
    });

    return result.data['available'] == true;
  }

  Future<String> claimNickname(String nickname) async {
    final callable =
    _functions.httpsCallable('claimNickname');

    final result = await callable.call({
      'nickname': nickname.trim(),
    });

    final normalizedNickname =
    result.data['normalizedNickname'];

    if (normalizedNickname is! String ||
        normalizedNickname.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'invalid-response',
        message: '닉네임 등록 결과가 올바르지 않습니다.',
      );
    }

    return normalizedNickname;
  }

  Future<String> changeNickname(String nickname) async {
    final callable =
    _functions.httpsCallable('changeNickname');

    final result = await callable.call({
      'nickname': nickname.trim(),
    });

    final normalizedNickname =
    result.data['normalizedNickname'];

    if (normalizedNickname is! String ||
        normalizedNickname.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'invalid-response',
        message: '닉네임 변경 결과가 올바르지 않습니다.',
      );
    }

    return normalizedNickname;
  }
}
