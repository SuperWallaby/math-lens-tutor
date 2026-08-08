import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 우열 design tokens — see `/DESIGN.md` (Flat Design Educacional Vibrante).
abstract final class AppFonts {
  /// [pubspec.yaml]에 번들된 Noto Sans KR Variable.
  static const family = 'Noto Sans KR';
}

TextStyle _appTextStyle({
  Color? color,
  FontWeight? fontWeight,
  double? fontSize,
  double? height,
}) {
  return TextStyle(
    fontFamily: AppFonts.family,
    color: color,
    fontWeight: fontWeight,
    fontSize: fontSize,
    height: height,
  );
}
abstract final class AppColors {
  static const background = Color(0xFFF5F5F5);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceElevated = Color(0xFFFAFAFA);
  static const surfaceMuted = Color(0xFFEEEEEE);

  static const primary = Color(0xFF007BFF);
  static const primaryDark = Color(0xFF0062CC);

  static const accent = Color(0xFFFF8C00);
  static const success = Color(0xFF2ECC40);
  static const warning = Color(0xFFB8860B);
  static const teacher = Color(0xFF9370DB);
  static const magenta = Color(0xFFFF00CC);
  static const orange = Color(0xFFFF8C00);

  /// Category / progress wayfinding (Educacional hue mapping).
  static const categoryBlue = primary;
  static const categoryGold = warning;
  static const categoryGreen = success;

  static const text = Color(0xFF1A1A2E);
  static const textSub = Color(0xFF5A6278);
  static const textMuted = Color(0xFF949BB0);

  static const border = Color(0x14000000);
  static const borderStrong = Color(0x1F000000);
}

abstract final class AppRadii {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 16.0;
  static const pill = 999.0;
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const section = 32.0;
}

/// Component sizes — see `/DESIGN.md` components section.
abstract final class AppSizes {
  static const buttonHeight = 52.0;
  /// Primary CTA on hero / onboarding screens (+20% per DESIGN.md).
  static const buttonHeightKeyAction = 62.0;
}

/// Button label typography — key action uses 17/w700 to match 62px height.
abstract final class AppTypography {
  static const button = 16.0;
  static const buttonWeight = FontWeight.w600;
  static const buttonKeyAction = 17.0;
  static const buttonKeyActionWeight = FontWeight.w700;
}

abstract final class AppButtonStyles {
  static ButtonStyle filled({
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return FilledButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: 0,
      minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      textStyle: _appTextStyle(
        fontSize: AppTypography.button,
        fontWeight: AppTypography.buttonWeight,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    );
  }

  static ButtonStyle filledKeyAction({
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return FilledButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: 0,
      minimumSize: const Size.fromHeight(AppSizes.buttonHeightKeyAction),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      textStyle: _appTextStyle(
        fontSize: AppTypography.buttonKeyAction,
        fontWeight: AppTypography.buttonKeyActionWeight,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    );
  }
}

@immutable
class AppDesignColors extends ThemeExtension<AppDesignColors> {
  const AppDesignColors({
    required this.surface,
    required this.surfaceElevated,
    required this.accent,
    required this.success,
    required this.warning,
    required this.teacher,
    required this.textSub,
    required this.textMuted,
    required this.border,
    required this.borderStrong,
  });

  final Color surface;
  final Color surfaceElevated;
  final Color accent;
  final Color success;
  final Color warning;
  final Color teacher;
  final Color textSub;
  final Color textMuted;
  final Color border;
  final Color borderStrong;

  static const standard = AppDesignColors(
    surface: AppColors.surface,
    surfaceElevated: AppColors.surfaceElevated,
    accent: AppColors.accent,
    success: AppColors.success,
    warning: AppColors.warning,
    teacher: AppColors.teacher,
    textSub: AppColors.textSub,
    textMuted: AppColors.textMuted,
    border: AppColors.border,
    borderStrong: AppColors.borderStrong,
  );

  Color tint(Color color, [double opacity = 0.12]) =>
      color.withValues(alpha: opacity);

  @override
  AppDesignColors copyWith({
    Color? surface,
    Color? surfaceElevated,
    Color? accent,
    Color? success,
    Color? warning,
    Color? teacher,
    Color? textSub,
    Color? textMuted,
    Color? border,
    Color? borderStrong,
  }) {
    return AppDesignColors(
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      teacher: teacher ?? this.teacher,
      textSub: textSub ?? this.textSub,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
    );
  }

  @override
  AppDesignColors lerp(ThemeExtension<AppDesignColors>? other, double t) {
    if (other is! AppDesignColors) return this;
    return AppDesignColors(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      teacher: Color.lerp(teacher, other.teacher, t)!,
      textSub: Color.lerp(textSub, other.textSub, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
    );
  }
}

extension AppDesignContext on BuildContext {
  AppDesignColors get appDesign =>
      Theme.of(this).extension<AppDesignColors>() ?? AppDesignColors.standard;
}

ThemeData buildAppTheme() {
  const colorScheme = ColorScheme.light(
    surface: AppColors.surface,
    onSurface: AppColors.text,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.accent,
    onSecondary: Colors.white,
    error: AppColors.accent,
    onError: Colors.white,
    outline: AppColors.borderStrong,
  );

  final textTheme = Typography.material2021().black.apply(
    fontFamily: AppFonts.family,
    bodyColor: AppColors.text,
    displayColor: AppColors.text,
  ).copyWith(
    headlineLarge: _appTextStyle(
      color: AppColors.text,
      fontWeight: FontWeight.w800,
    ),
    titleLarge: _appTextStyle(
      color: AppColors.text,
      fontWeight: FontWeight.w700,
    ),
    bodyLarge: _appTextStyle(
      color: AppColors.text,
      fontWeight: FontWeight.w400,
      height: 1.6,
    ),
    bodyMedium: _appTextStyle(
      color: AppColors.textSub,
      fontWeight: FontWeight.w400,
      height: 1.6,
    ),
    labelLarge: _appTextStyle(
      color: AppColors.text,
      fontWeight: FontWeight.w600,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: AppFonts.family,
    brightness: Brightness.light,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    dividerColor: AppColors.border,
    extensions: const [AppDesignColors.standard],
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      iconTheme: const IconThemeData(color: AppColors.text),
      actionsIconTheme: const IconThemeData(color: AppColors.text),
      titleTextStyle: _appTextStyle(
        color: AppColors.text,
        fontWeight: FontWeight.w700,
        fontSize: 18,
      ),
      toolbarTextStyle: _appTextStyle(
        color: AppColors.text,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: AppButtonStyles.filled(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.borderStrong),
        elevation: 0,
        minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        textStyle: _appTextStyle(
          fontSize: AppTypography.button,
          fontWeight: AppTypography.buttonWeight,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      hintStyle: _appTextStyle(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w400,
        fontSize: 16,
      ),
    ),
    textTheme: textTheme,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.text,
      contentTextStyle: _appTextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.surfaceMuted,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      indicatorColor: AppColors.primary.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: AppFonts.family,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: selected ? AppColors.primary : AppColors.textMuted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.primary : AppColors.textMuted,
        );
      }),
    ),
  );
}
