import 'package:flutter/material.dart';

class UserDataProvider extends ChangeNotifier {
  bool _isLoaded = false; // 사용자 데이터 로딩 완료 여부
  bool _isSubscribed = false; // ✅ 구독 여부

  bool get isLoaded => _isLoaded;
  bool get isSubscribed => _isSubscribed;

  /// 로딩 완료 시 호출
  void markAsLoaded() {
    _isLoaded = true;
    notifyListeners();
  }

  /// 로그아웃 등으로 상태 초기화할 때 사용
  void reset() {
    _isLoaded = false;
    _isSubscribed = false; // ✅ 구독 상태도 초기화
    notifyListeners();
  }

  /// ✅ 구독 여부 설정
  void setSubscribed(bool value) {
    _isSubscribed = value;
    notifyListeners();
  }
}
