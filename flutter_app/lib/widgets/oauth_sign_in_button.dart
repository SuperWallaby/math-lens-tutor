import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';
import '../theme/app_icons.dart';

enum OAuthProvider { kakao, google, apple }

/// OAuth 버튼 왼쪽 브랜드 마크 — 모든 제공자 동일 슬롯.
class OAuthProviderIcon extends StatelessWidget {
  const OAuthProviderIcon(this.provider, {super.key, this.color});

  final OAuthProvider provider;
  final Color? color;

  static const double slotSize = 24;
  static const double markSize = 20;
  static const double appleMarkSize = markSize * 1.1;

  static const _googleLogoAsset = 'assets/icons/oauth/google_g.png';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: slotSize,
      height: slotSize,
      child: Center(child: _buildMark()),
    );
  }

  Widget _buildMark() {
    return switch (provider) {
      OAuthProvider.kakao => Icon(
          AppIcons.chat,
          size: 18,
          color: color ?? AppColors.text,
        ),
      OAuthProvider.google => Image.asset(
          _googleLogoAsset,
          width: markSize,
          height: markSize,
          fit: BoxFit.contain,
        ),
      OAuthProvider.apple => Icon(
          AppIcons.apple,
          size: appleMarkSize,
          color: color,
        ),
    };
  }
}

/// 흰 알약 보조 버튼(테마 [OutlinedButton]) 안에 브랜드 마크와 글자를 가운데로.
class OAuthSignInButton extends StatelessWidget {
  const OAuthSignInButton({
    super.key,
    required this.provider,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final OAuthProvider provider;
  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = enabled ? onPressed : null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: OutlinedButton(
        onPressed: effectiveOnPressed,
        // 꺼져도 흰 바탕과 테두리는 그대로 두고, 흐림은 위의 Opacity가 맡는다.
        style: OutlinedButton.styleFrom(
          disabledBackgroundColor: Colors.white,
          disabledForegroundColor: AppColors.text,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OAuthProviderIcon(provider, color: AppColors.text),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
