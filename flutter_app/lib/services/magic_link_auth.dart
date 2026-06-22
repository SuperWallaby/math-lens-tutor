import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// 이메일 매직 링크 `wooyeol://auth/magic?token=...` 수신.
class MagicLinkAuth {
  MagicLinkAuth._();

  static final MagicLinkAuth instance = MagicLinkAuth._();

  final AppLinks _appLinks = AppLinks();
  final StreamController<String> _tokens = StreamController<String>.broadcast();
  StreamSubscription<Uri>? _linkSub;
  bool _initialized = false;

  Stream<String> get tokens => _tokens.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb) {
      _emitFromUri(Uri.base);
      return;
    }

    try {
      final initial = await _appLinks.getInitialLink();
      _emitFromUri(initial);
      _linkSub = _appLinks.uriLinkStream.listen(_emitFromUri);
    } catch (error, stack) {
      debugPrint('[MagicLinkAuth] init failed: $error\n$stack');
    }
  }

  void _emitFromUri(Uri? uri) {
    final token = extractMagicLinkToken(uri);
    if (token == null || token.isEmpty) return;
    _tokens.add(token);
  }

  static String? extractMagicLinkToken(Uri? uri) {
    if (uri == null) return null;

    if (uri.scheme == 'wooyeol' &&
        uri.host == 'auth' &&
        uri.path == '/magic') {
      return uri.queryParameters['token']?.trim();
    }

    if (uri.path == '/auth/magic' || uri.path.endsWith('/auth/magic')) {
      return uri.queryParameters['token']?.trim();
    }

    return null;
  }

  void dispose() {
    _linkSub?.cancel();
    _tokens.close();
  }
}

Future<void> initializeMagicLinkAuth() {
  return MagicLinkAuth.instance.initialize();
}

String? readWebMagicLinkToken() {
  if (!kIsWeb) return null;
  return MagicLinkAuth.extractMagicLinkToken(Uri.base);
}
