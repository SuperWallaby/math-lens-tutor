import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';
import 'glass.dart';

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
          color: color ?? AppColors.text,
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
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: effectiveOnPressed,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: GlassPanel(
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: SizedBox(
              height: AppSizes.buttonHeight,
              child: Row(
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
          ),
        ),
      ),
    );
  }
}
