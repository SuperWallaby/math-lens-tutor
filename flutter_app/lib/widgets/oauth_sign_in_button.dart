import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';

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
          Icons.chat_bubble_rounded,
          size: 18,
          color: color ?? const Color(0xFF191919),
        ),
      OAuthProvider.google => Image.asset(
          _googleLogoAsset,
          width: markSize,
          height: markSize,
          fit: BoxFit.contain,
        ),
      OAuthProvider.apple => Icon(
          Icons.apple,
          size: appleMarkSize,
          color: color,
        ),
    };
  }
}

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
    final labelStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: _labelColor,
    );

    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        OAuthProviderIcon(provider, color: _iconColor),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            style: labelStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    final minHeight = const Size.fromHeight(AppSizes.buttonHeight);

    if (provider == OAuthProvider.kakao) {
      return FilledButton(
        onPressed: effectiveOnPressed,
        style: FilledButton.styleFrom(
          minimumSize: minHeight,
          backgroundColor: const Color(0xFFFEE500),
          foregroundColor: const Color(0xFF191919),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
        child: content,
      );
    }

    return OutlinedButton(
      onPressed: effectiveOnPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: minHeight,
        foregroundColor: AppColors.text,
        backgroundColor: AppColors.surface,
        disabledBackgroundColor: AppColors.surfaceMuted,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),
      child: content,
    );
  }

  Color? get _iconColor {
    return switch (provider) {
      OAuthProvider.kakao => const Color(0xFF191919),
      OAuthProvider.google => null,
      OAuthProvider.apple => AppColors.text,
    };
  }

  Color get _labelColor {
    return switch (provider) {
      OAuthProvider.kakao => const Color(0xFF191919),
      OAuthProvider.google => AppColors.text,
      OAuthProvider.apple => AppColors.text,
    };
  }
}
