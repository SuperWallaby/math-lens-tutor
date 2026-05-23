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
  OAuthService({
    GoogleSignIn? googleSignIn,
  }) : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: const ['email', 'profile'],
            );

  final GoogleSignIn _googleSignIn;

  Future<OAuthCredentialBundle> signInWithKakao() async {
    OAuthToken token;
    if (await isKakaoTalkInstalled()) {
      token = await UserApi.instance.loginWithKakaoTalk();
    } else {
      token = await UserApi.instance.loginWithKakaoAccount();
    }

    return OAuthCredentialBundle(
      provider: 'kakao',
      accessToken: token.accessToken,
    );
  }

  Future<OAuthCredentialBundle> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
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

    if (credential.identityToken == null ||
        credential.identityToken!.isEmpty) {
      throw OAuthException('Apple 토큰을 받지 못했습니다.');
    }

    final given = credential.givenName?.trim() ?? '';
    final family = credential.familyName?.trim() ?? '';
    final displayName = [family, given].where((part) => part.isNotEmpty).join(' ');

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
  return const String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
    defaultValue: '',
  );
}

Future<void> initializeOAuthSdk() async {
  final kakaoKey = resolveKakaoNativeAppKey();
  if (kakaoKey.isNotEmpty) {
    KakaoSdk.init(nativeAppKey: kakaoKey);
  } else if (kDebugMode) {
    debugPrint('[OAuth] KAKAO_NATIVE_APP_KEY not set — Kakao login disabled.');
  }
}
