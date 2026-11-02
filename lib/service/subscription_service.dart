import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class SubscriptionVerificationResult {
  final bool success;
  final bool active;
  final String? productId;

  // Apple
  final String? transactionId;
  final String? originalTransactionId;
  final int? status;

  // Google Play
  final String? purchaseToken;
  final String? latestOrderId;
  final String? androidStatus;
  final String? acknowledgementState;

  // 공통
  final DateTime? expiresAt;
  final String? environment;
  final String? message;

  const SubscriptionVerificationResult({
    required this.success,
    required this.active,
    this.productId,
    this.transactionId,
    this.originalTransactionId,
    this.status,
    this.purchaseToken,
    this.latestOrderId,
    this.androidStatus,
    this.acknowledgementState,
    this.expiresAt,
    this.environment,
    this.message,
  });
}

class SubscriptionService {
  SubscriptionService._();

  static final SubscriptionService instance = SubscriptionService._();

  final FirebaseFunctions _functions =
  FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  Future<SubscriptionVerificationResult> verifyIosPurchase(
      PurchaseDetails purchase,
      ) async {
    try {
      final transactionId = purchase.purchaseID;

      debugPrint('🧾 purchaseID: $transactionId');
      debugPrint(
        '🧾 serverVerificationData 길이: '
            '${purchase.verificationData.serverVerificationData.length}',
      );

      if (transactionId == null || transactionId.trim().isEmpty) {
        debugPrint('❌ iOS 거래 ID가 비어 있습니다.');

        return const SubscriptionVerificationResult(
          success: false,
          active: false,
          message: 'iOS 거래 ID가 없습니다.',
        );
      }

      final callable = _functions.httpsCallable(
        'verifySubscriptionPurchase',
      );

      final result = await callable.call(<String, dynamic>{
        'platform': 'ios',
        'productId': purchase.productID,
        'transactionId': transactionId,
      });

      final data = Map<String, dynamic>.from(
        result.data as Map,
      );

      final expiresAtMilliseconds = data['expiresAt'] is num
          ? (data['expiresAt'] as num).toInt()
          : null;

      final status = data['status'] is num
          ? (data['status'] as num).toInt()
          : null;

      final verification = SubscriptionVerificationResult(
        success: data['success'] == true,
        active: data['active'] == true,
        productId: data['productId']?.toString(),
        transactionId: data['transactionId']?.toString(),
        originalTransactionId:
        data['originalTransactionId']?.toString(),
        expiresAt: expiresAtMilliseconds != null
            ? DateTime.fromMillisecondsSinceEpoch(
          expiresAtMilliseconds,
        )
            : null,
        environment: data['environment']?.toString(),
        status: status,
        message: data['message']?.toString(),
      );

      debugPrint('✅ Apple 구독 서버 응답: $data');
      debugPrint('✅ 구독 활성 상태: ${verification.active}');
      debugPrint('✅ 상품 ID: ${verification.productId}');
      debugPrint('✅ 거래 ID: ${verification.transactionId}');
      debugPrint(
        '✅ 원본 거래 ID: ${verification.originalTransactionId}',
      );
      debugPrint('✅ 만료일: ${verification.expiresAt}');
      debugPrint('✅ 환경: ${verification.environment}');
      debugPrint('✅ Apple 상태 코드: ${verification.status}');
      debugPrint('✅ 메시지: ${verification.message}');

      return verification;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ Functions 오류 코드: ${e.code}');
      debugPrint('❌ Functions 오류 메시지: ${e.message}');
      debugPrint('❌ Functions 오류 상세: ${e.details}');

      return SubscriptionVerificationResult(
        success: false,
        active: false,
        message: e.message ?? '구독 검증에 실패했습니다.',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ 구독 검증 호출 실패: $e');
      debugPrint('$stackTrace');

      return const SubscriptionVerificationResult(
        success: false,
        active: false,
        message: '구독 검증 중 오류가 발생했습니다.',
      );
    }
  }

  Future<SubscriptionVerificationResult> verifyAndroidPurchase(
      PurchaseDetails purchase,
      ) async {
    try {
      final purchaseToken =
      purchase.verificationData.serverVerificationData.trim();

      debugPrint('🧾 Android productID: ${purchase.productID}');
      debugPrint('🧾 Android purchaseID: ${purchase.purchaseID}');
      debugPrint(
        '🧾 Android purchaseToken 길이: ${purchaseToken.length}',
      );

      if (purchaseToken.isEmpty) {
        debugPrint('❌ Google Play 구매 토큰이 비어 있습니다.');

        return const SubscriptionVerificationResult(
          success: false,
          active: false,
          message: 'Google Play 구매 토큰이 없습니다.',
        );
      }

      final callable = _functions.httpsCallable(
        'verifyGooglePlaySubscription',
      );

      final result = await callable.call(<String, dynamic>{
        'platform': 'android',
        'productId': purchase.productID,
        'purchaseToken': purchaseToken,
      });

      final data = Map<String, dynamic>.from(
        result.data as Map,
      );

      final expiresAtMilliseconds = data['expiresAt'] is num
          ? (data['expiresAt'] as num).toInt()
          : null;

      final verification = SubscriptionVerificationResult(
        success: data['success'] == true,
        active: data['active'] == true,
        productId: data['productId']?.toString(),
        purchaseToken: data['purchaseToken']?.toString(),
        latestOrderId: data['latestOrderId']?.toString(),
        androidStatus: data['status']?.toString(),
        acknowledgementState:
        data['acknowledgementState']?.toString(),
        expiresAt: expiresAtMilliseconds != null
            ? DateTime.fromMillisecondsSinceEpoch(
          expiresAtMilliseconds,
        )
            : null,
        environment: data['environment']?.toString(),
        message: data['message']?.toString(),
      );

      debugPrint('✅ Google Play 구독 서버 응답: $data');
      debugPrint('✅ 구독 활성 상태: ${verification.active}');
      debugPrint('✅ 상품 ID: ${verification.productId}');
      debugPrint('✅ 주문 ID: ${verification.latestOrderId}');
      debugPrint('✅ 만료일: ${verification.expiresAt}');
      debugPrint('✅ 상태: ${verification.androidStatus}');
      debugPrint(
        '✅ 승인 상태: ${verification.acknowledgementState}',
      );
      debugPrint('✅ 메시지: ${verification.message}');

      return verification;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ Functions 오류 코드: ${e.code}');
      debugPrint('❌ Functions 오류 메시지: ${e.message}');
      debugPrint('❌ Functions 오류 상세: ${e.details}');

      return SubscriptionVerificationResult(
        success: false,
        active: false,
        message: e.message ?? 'Google Play 구독 검증에 실패했습니다.',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Google Play 구독 검증 호출 실패: $e');
      debugPrint('$stackTrace');

      return const SubscriptionVerificationResult(
        success: false,
        active: false,
        message: 'Google Play 구독 검증 중 오류가 발생했습니다.',
      );
    }
  }

  Future<SubscriptionVerificationResult> verifyPurchase(
      PurchaseDetails purchase,
      ) async {
    if (kIsWeb) {
      return const SubscriptionVerificationResult(
        success: false,
        active: false,
        message: '웹 결제는 지원하지 않습니다.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return verifyIosPurchase(purchase);

      case TargetPlatform.android:
        return verifyAndroidPurchase(purchase);

      default:
        return const SubscriptionVerificationResult(
          success: false,
          active: false,
          message: '지원하지 않는 결제 플랫폼입니다.',
        );
    }
  }

}
