import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _productionUrl = 'https://study-hazel-six.vercel.app';
/// `write-dev-port.sh` 가 갱신하는 `dev/local-defines.json` 의 기본값.
const _localPort = 3737;

int? _debugPortFromAsset;
String? _debugBaseUrlFromAsset;

/// `--dart-define=API_BASE_URL=...` 가 있으면 항상 우선.
/// 릴리스 빌드: 프로덕션. 디버그/프로파일: 로컬 Next (`npm run dev:next`).
String resolveApiBaseUrl() {
  const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  final trimmed = fromEnv.trim();
  if (trimmed.isNotEmpty) {
    return trimmed.replaceAll(RegExp(r'/$'), '');
  }

  if (kReleaseMode) {
    return _productionUrl;
  }

  final fromAsset = _debugBaseUrlFromAsset?.trim();
  if (fromAsset != null && fromAsset.isNotEmpty) {
    return fromAsset.replaceAll(RegExp(r'/$'), '');
  }

  return _localDevBaseUrl();
}

/// `dev/local-defines.json` (에셋)에서 로컬 API 주소/포트를 읽습니다.
/// `npm run dev:next` 가 포트를 바꾼 뒤에는 앱을 한 번 재시작해야 반영됩니다.
/// 실기기(아이폰 등)는 `API_BASE_URL`에 PC LAN 주소를 넣으면 됩니다.
Future<void> loadDebugApiConfigFromAsset() async {
  if (kReleaseMode) return;

  try {
    final raw = await rootBundle.loadString('dev/local-defines.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;

    final url = map['API_BASE_URL']?.toString().trim();
    if (url != null && url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
        _debugBaseUrlFromAsset = url.replaceAll(RegExp(r'/$'), '');
        if (uri.hasPort && uri.port > 0) {
          _debugPortFromAsset = uri.port;
        }
        return;
      }
    }

    final port = map['port'];
    if (port is int && port > 0) {
      _debugPortFromAsset = port;
    }
  } catch (_) {
    _debugPortFromAsset = null;
    _debugBaseUrlFromAsset = null;
  }
}

String _localDevBaseUrl() {
  const hostOverride = String.fromEnvironment('DEV_HOST', defaultValue: '');
  final host = hostOverride.trim().isNotEmpty ? hostOverride.trim() : _defaultDevHost();
  final port = _debugPortFromAsset ?? _localPort;

  return 'http://$host:$port';
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
