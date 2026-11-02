import 'dart:io';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

enum UpdateRequirement {
  none,
  optional,
  force,
}

class AppUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String minSupportedVersion;
  final bool forceUpdate;
  final String title;
  final String message;
  final UpdateRequirement requirement;

  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.minSupportedVersion,
    required this.forceUpdate,
    required this.title,
    required this.message,
    required this.requirement,
  });
}

class AppUpdateService {
  AppUpdateService._();

  static final FirebaseRemoteConfig _remoteConfig =
      FirebaseRemoteConfig.instance;

  static const String _kLatestVersion =
      'latest_version';

  static const String _kMinSupportedVersion =
      'min_supported_version';

  static const String _kForceUpdate =
      'force_update';

  static const String _kUpdateTitle =
      'update_title';

  static const String _kUpdateMessage =
      'update_message';

  /// 중복 초기화 방지
  static Future<void>? _initializeFuture;

  /// Remote Config 초기화
  ///
  /// 여러 곳에서 호출돼도 실제 초기화는 한 번만 실행한다.
  static Future<void> initialize() {
    return _initializeFuture ??=
        _initializeInternal();
  }

  static Future<void> _initializeInternal() async {
    await _remoteConfig.setDefaults(
      const {
        _kLatestVersion: '1.0.0',
        _kMinSupportedVersion: '1.0.0',
        _kForceUpdate: false,
        _kUpdateTitle: '새 버전이 나왔어요',
        _kUpdateMessage:
        '더 안정적인 사용을 위해 최신 버전으로 업데이트해주세요.',
      },
    );

    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout:
        const Duration(seconds: 10),
        minimumFetchInterval:
        const Duration(hours: 1),
      ),
    );

    try {
      await _remoteConfig.fetchAndActivate();
    } catch (_) {
      // 네트워크 실패 시
      // 기본값 또는 기존 캐시값 사용
    }
  }

  static Future<AppUpdateInfo>
  checkForUpdate() async {
    /// initialize가 이미 실행 중이면 같은 Future를 기다리고,
    /// 아직 시작하지 않았다면 여기서 시작한다.
    await initialize();

    final packageInfo =
    await PackageInfo.fromPlatform();

    final currentVersion =
        '${packageInfo.version}+'
        '${packageInfo.buildNumber}';

    final latestVersion =
    _remoteConfig
        .getString(_kLatestVersion)
        .trim();

    final minSupportedVersion =
    _remoteConfig
        .getString(_kMinSupportedVersion)
        .trim();

    final forceUpdate =
    _remoteConfig
        .getBool(_kForceUpdate);

    final title =
    _remoteConfig
        .getString(_kUpdateTitle)
        .trim();

    final message =
    _remoteConfig
        .getString(_kUpdateMessage)
        .trim();

    final isBelowMinimum =
        _compareVersions(
          currentVersion,
          minSupportedVersion,
        ) <
            0;

    final isBelowLatest =
        _compareVersions(
          currentVersion,
          latestVersion,
        ) <
            0;

    UpdateRequirement requirement =
        UpdateRequirement.none;

    if (isBelowMinimum) {
      requirement =
          UpdateRequirement.force;
    } else if (isBelowLatest) {
      requirement = forceUpdate
          ? UpdateRequirement.force
          : UpdateRequirement.optional;
    }

    return AppUpdateInfo(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      minSupportedVersion:
      minSupportedVersion,
      forceUpdate: forceUpdate,
      title: title.isEmpty
          ? '새 버전이 나왔어요'
          : title,
      message: message.isEmpty
          ? '더 안정적인 사용을 위해 최신 버전으로 업데이트해주세요.'
          : message,
      requirement: requirement,
    );
  }

  static int _compareVersions(
      String a,
      String b,
      ) {
    List<int> parseVersion(
        String version,
        ) {
      final clean =
      version.trim();

      final splitBuild =
      clean.split('+');

      final versionName =
      splitBuild[0];

      final buildNumber =
      splitBuild.length > 1
          ? int.tryParse(
        splitBuild[1],
      ) ??
          0
          : 0;

      final parts = versionName
          .split('.')
          .map(
            (e) =>
        int.tryParse(e) ?? 0,
      )
          .toList();

      while (parts.length < 3) {
        parts.add(0);
      }

      return [
        parts[0],
        parts[1],
        parts[2],
        buildNumber,
      ];
    }

    final aParts =
    parseVersion(a);

    final bParts =
    parseVersion(b);

    for (
    int i = 0;
    i < aParts.length;
    i++
    ) {
      if (aParts[i] > bParts[i]) {
        return 1;
      }

      if (aParts[i] < bParts[i]) {
        return -1;
      }
    }

    return 0;
  }

  static Future<void> openStore() async {
    final Uri uri;

    if (Platform.isIOS) {
      uri = Uri.parse(
        'itms-apps://itunes.apple.com/app/id6758513187',
      );
    } else if (Platform.isAndroid) {
      uri = Uri.parse(
        'https://play.google.com/store/apps/details?id=com.lapharos.labrary',
      );
    } else {
      return;
    }

    await launchUrl(
      uri,
      mode:
      LaunchMode.externalApplication,
    );
  }
}