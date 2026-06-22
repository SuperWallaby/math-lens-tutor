import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';

class HeroIcon3d extends StatelessWidget {
  const HeroIcon3d({
    super.key,
    required this.asset,
    this.size = 112,
    this.iconSize = 72,
    this.tint = AppColors.primary,
  });

  final String asset;
  final double size;
  final double iconSize;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Image.asset(asset, width: iconSize, height: iconSize),
    );
  }
}
