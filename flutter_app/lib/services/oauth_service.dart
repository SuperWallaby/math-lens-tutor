import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class OAuthCredentialBundle {
  OAuthCredentialBundle({
    required this.provider,
    this.idToken,
    this.accessToken,
    this.displayName,
  });

  final String provider;
  final String? idToken;
  final String? accessToken;
  final String? displayName;
}

class OAuthService {
  OAuthService({GoogleSignIn? googleSignIn})
    : _googleSignInOverride = googleSignIn;

  final GoogleSignIn? _googleSignInOverride;
  GoogleSignIn? _googleSignIn;

  GoogleSignIn get _google {
    final override = _googleSignInOverride;
    if (override != null) return override;
    final webClientId = _resolveGoogleWebClientId();
    _googleSignIn ??= GoogleSignIn(
      scopes: const ['email', 'profile'],
      clientId: resolveGoogleClientIdForPlatform(),
      serverClientId: webClientId.isEmpty ? null : webClientId,
    );
    return _googleSignIn!;
  }

  Future<OAuthCredentialBundle> signInWithKakao() async {
    OAuthToken token;
    if (await isKakaoTalkInstalled()) {
      token = await UserApi.instance.loginWithKakaoTalk();
    } else {
      token = await UserApi.instance.loginWithKakaoAccount();
    }

    String? displayName;
    try {
      final me = await UserApi.instance.me();
      final nickname = me.kakaoAccount?.profile?.nickname?.trim();
      if (nickname != null && nickname.isNotEmpty) {
        displayName = nickname;
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[OAuth] Kakao profile fetch failed: $error');
      }
    }

    return OAuthCredentialBundle(
      provider: 'kakao',
      accessToken: token.accessToken,
      displayName: displayName,
    );
  }

  Future<OAuthCredentialBundle> signInWithGoogle() async {
    if (!isGoogleSignInConfigured) {
      throw OAuthException('Google 로그인은 Client ID 설정 후 사용할 수 있습니다.');
    }

    final account = await _google.signIn();
    if (account == null) {
      throw OAuthException('Google 가입이 취소되었습니다.');
    }

    final auth = await account.authentication;
    if (auth.idToken == null || auth.idToken!.isEmpty) {
      throw OAuthException('Google 토큰을 받지 못했습니다.');
    }

    return OAuthCredentialBundle(
      provider: 'google',
      idToken: auth.idToken,
      displayName: account.displayName,
    );
  }

  Future<OAuthCredentialBundle> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    if (credential.identityToken == null || credential.identityToken!.isEmpty) {
      throw OAuthException('Apple 토큰을 받지 못했습니다.');
    }

    final given = credential.givenName?.trim() ?? '';
    final family = credential.familyName?.trim() ?? '';
    final displayName = [
      family,
      given,
    ].where((part) => part.isNotEmpty).join(' ');

    return OAuthCredentialBundle(
      provider: 'apple',
      idToken: credential.identityToken,
      displayName: displayName.isEmpty ? null : displayName,
    );
  }
}

class OAuthException implements Exception {
  OAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

String resolveKakaoNativeAppKey() {
  return const String.fromEnvironment('KAKAO_NATIVE_APP_KEY', defaultValue: '');
}

String _resolveGoogleWebClientId() {
  return const String.fromEnvironment('GOOGLE_CLIENT_ID_WEB', defaultValue: '');
}

String _resolveGoogleIosClientId() {
  return const String.fromEnvironment('GOOGLE_CLIENT_ID_IOS', defaultValue: '');
}

String _resolveGoogleMacosClientId() {
  return const String.fromEnvironment(
    'GOOGLE_CLIENT_ID_MACOS',
    defaultValue: '',
  );
}

String resolveGoogleClientIdForPlatform() {
  if (kIsWeb) return _resolveGoogleWebClientId();

  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return _resolveGoogleIosClientId();
    case TargetPlatform.macOS:
      return _resolveGoogleMacosClientId();
    default:
      return '';
  }
}

bool get isGoogleSignInConfigured {
  if (kIsWeb) return _resolveGoogleWebClientId().isNotEmpty;

  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return _resolveGoogleIosClientId().isNotEmpty;
    case TargetPlatform.macOS:
      return _resolveGoogleMacosClientId().isNotEmpty;
    default:
      return true;
  }
}

bool get isAppleSignInAvailable {
  if (kIsWeb) return false;

  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return true;
    default:
      return false;
  }
}

Future<void> initializeOAuthSdk() async {
  final kakaoKey = resolveKakaoNativeAppKey();
  if (kakaoKey.isNotEmpty) {
    KakaoSdk.init(nativeAppKey: kakaoKey);
  } else if (kDebugMode) {
    debugPrint('[OAuth] KAKAO_NATIVE_APP_KEY not set — Kakao login disabled.');
  }
}
