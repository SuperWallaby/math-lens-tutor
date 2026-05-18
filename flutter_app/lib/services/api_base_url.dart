import 'package:flutter/foundation.dart';

const _productionUrl = 'https://study-alpha-rosy.vercel.app';
const _localPort = 3000;

/// `--dart-define=API_BASE_URL=...` 가 있으면 항상 우선.
/// 릴리스 빌드: 프로덕션. 디버그/프로파일: 로컬 Next (`npm run dev`).
String resolveApiBaseUrl() {
  const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  final trimmed = fromEnv.trim();
  if (trimmed.isNotEmpty) {
    return trimmed.replaceAll(RegExp(r'/$'), '');
  }

  if (kReleaseMode) {
    return _productionUrl;
  }

  return _localDevBaseUrl();
}

String _localDevBaseUrl() {
  const hostOverride = String.fromEnvironment('DEV_HOST', defaultValue: '');
  final host = hostOverride.trim().isNotEmpty ? hostOverride.trim() : _defaultDevHost();

  return 'http://$host:$_localPort';
}

/// 플랫폼별 로컬 호스트 (실기기는 `--dart-define=DEV_HOST=<맥 IP>` 권장).
String _defaultDevHost() {
  if (kIsWeb) return 'localhost';

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      // 에뮬레이터 → 호스트 PC의 localhost
      return '10.0.2.2';
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return 'localhost';
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return 'localhost';
    default:
      return 'localhost';
  }
}
