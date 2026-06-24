import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/api_base_url.dart';
import '../theme/app_design_system.dart';

String profileInitialsFromName(String displayName) {
  final trimmed = displayName.trim();
  if (trimmed.isEmpty) return '?';
  return String.fromCharCode(trimmed.runes.first);
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.user,
    this.size = 72,
    this.onTap,
    this.showEditBadge = false,
  });

  final AppUser? user;
  final double size;
  final VoidCallback? onTap;
  final bool showEditBadge;

  @override
  Widget build(BuildContext context) {
    final name = user?.displayName ?? '';
    final imageUrl = resolveProfileImageUrl(null, user?.profileImageUrl);
    final initials = profileInitialsFromName(name);

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.12),
        border: Border.all(
          color: AppColors.borderStrong,
          width: 1.5,
        ),
        image: imageUrl != null
            ? DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: imageUrl == null
          ? Text(
              initials,
              style: TextStyle(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            )
          : null,
    );

    if (onTap != null) {
      avatar = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: avatar,
        ),
      );
    }

    if (!showEditBadge) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 2),
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              size: 12,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

String? resolveProfileImageUrl(String? baseUrl, String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http')) return path;
  final root = (baseUrl ?? resolveApiBaseUrl()).replaceAll(RegExp(r'/$'), '');
  final normalized = path.startsWith('/') ? path : '/$path';
  return '$root$normalized';
}

class LinkedStudentAvatar extends StatelessWidget {
  const LinkedStudentAvatar({
    super.key,
    required this.student,
    this.size = 36,
    this.apiBaseUrl,
  });

  final LinkedStudent student;
  final double size;
  final String? apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final name = student.labelForGuardian;
    final imageUrl = resolveProfileImageUrl(apiBaseUrl, student.profileImageUrl);
    final initials = profileInitialsFromName(name);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.success.withValues(alpha: 0.15),
        border: Border.all(color: AppColors.borderStrong),
        image: imageUrl != null
            ? DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: imageUrl == null
          ? Text(
              initials,
              style: TextStyle(
                fontSize: size * 0.38,
                fontWeight: FontWeight.w800,
                color: AppColors.success,
              ),
            )
          : null,
    );
  }
}
