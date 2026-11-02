import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserDataProvider extends ChangeNotifier {
  bool _isLoaded = false;

  bool _storeActive = false;
  DateTime? _storeExpiresAt;

  bool _manualActive = false;
  DateTime? _manualExpiresAt;
  String? _manualReason;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _subscriptionListener;

  bool get isLoaded => _isLoaded;

  bool get storeActive => _storeActive;
  DateTime? get storeExpiresAt => _storeExpiresAt;

  bool get manualActive => _manualActive;
  DateTime? get manualExpiresAt => _manualExpiresAt;
  String? get manualReason => _manualReason;

  // 런칭 프리미엄 이벤트 종료
  static const bool kLaunchEventPremiumEnabled = false;

  static final DateTime kLaunchEventEnd =
  DateTime(2026, 7, 31, 23, 59, 59);

  bool get isAnonymousUser {
    final user = FirebaseAuth.instance.currentUser;
    return user == null || user.isAnonymous;
  }

  bool get isStorePremiumActive {
    if (!_storeActive) return false;

    if (_storeExpiresAt == null) {
      return true;
    }

    return _storeExpiresAt!.isAfter(DateTime.now());
  }

  bool get isManualPremiumActive {
    if (!_manualActive) return false;

    if (_manualExpiresAt == null) {
      return true;
    }

    return _manualExpiresAt!.isAfter(DateTime.now());
  }

  bool get isPremiumActive {
    if (isStorePremiumActive) {
      return true;
    }

    if (!isAnonymousUser && isManualPremiumActive) {
      return true;
    }

    return false;
  }

  // 기존 코드 호환용
  bool get isSubscribed => isPremiumActive;

  DateTime? get premiumUntil {
    if (!isAnonymousUser && isManualPremiumActive) {
      return _manualExpiresAt;
    }

    if (isStorePremiumActive) {
      return _storeExpiresAt;
    }

    return null;
  }

  Future<void> startSubscriptionListener() async {
    await _subscriptionListener?.cancel();
    _subscriptionListener = null;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _clearSubscriptionState();
      _isLoaded = true;
      notifyListeners();
      return;
    }

    final subscriptionRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('subscription')
        .doc('status');

    _subscriptionListener = subscriptionRef.snapshots().listen(
          (snapshot) {
        final data = snapshot.data();

        if (!snapshot.exists || data == null) {
          _clearSubscriptionState();
        } else {
          _storeActive = data['storeActive'] == true;
          _manualActive = data['manualActive'] == true;

          _storeExpiresAt = _timestampToDateTime(
            data['storeExpiresAt'],
          );

          _manualExpiresAt = _timestampToDateTime(
            data['manualExpiresAt'],
          );

          _manualReason = data['manualReason'] as String?;
        }

        _isLoaded = true;
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('❌ 구독 상태 불러오기 실패: $error');

        _clearSubscriptionState();
        _isLoaded = true;
        notifyListeners();
      },
    );
  }

  DateTime? _timestampToDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }

  void markAsLoaded() {
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> reset() async {
    await _subscriptionListener?.cancel();
    _subscriptionListener = null;

    _isLoaded = false;
    _clearSubscriptionState();

    notifyListeners();
  }

  void _clearSubscriptionState() {
    _storeActive = false;
    _storeExpiresAt = null;

    _manualActive = false;
    _manualExpiresAt = null;
    _manualReason = null;
  }

  @override
  void dispose() {
    _subscriptionListener?.cancel();
    super.dispose();
  }
}
