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
  /// C-tone dark + glass
  static const background = Color(0xFF0B0D12);
  static const surface = Color(0xFF171B24);
  static const surfaceElevated = Color(0xFF222734);
  static const surfaceMuted = Color(0xFF2C3240);

  static const primary = Color(0xFF4DA3FF);
  static const primaryDark = Color(0xFF2F7FE0);

  static const accent = Color(0xFFFF9F43);
  static const success = Color(0xFF3DDC97);
  static const warning = Color(0xFFE6B422);
  static const teacher = Color(0xFFB794F6);
  static const magenta = Color(0xFFFF4FD8);
  static const orange = Color(0xFFFF9F43);

  /// Category / progress wayfinding (Educacional hue mapping).
  static const categoryBlue = primary;
  static const categoryGold = warning;
  static const categoryGreen = success;

  static const text = Color(0xFFF2F4F8);
  static const textSub = Color(0xFFB0B6C6);
  static const textMuted = Color(0xFF838AA0);

  static const border = Color(0x28FFFFFF);
  static const borderStrong = Color(0x44FFFFFF);

  static const glassFill = Color(0x28FFFFFF);
  static const glassStroke = Color(0x55FFFFFF);
}

abstract final class AppRadii {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 22.0;
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
  const colorScheme = ColorScheme.dark(
    surface: AppColors.surface,
    onSurface: AppColors.text,
    primary: AppColors.primary,
    onPrimary: Color(0xFF0B0D12),
    secondary: AppColors.accent,
    onSecondary: Color(0xFF0B0D12),
    error: AppColors.accent,
    onError: Color(0xFF0B0D12),
    outline: AppColors.borderStrong,
  );

  final textTheme = Typography.material2021().white.apply(
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
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    dividerColor: AppColors.border,
    extensions: const [AppDesignColors.standard],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
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
        foregroundColor: const Color(0xFF0B0D12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.borderStrong),
        backgroundColor: Colors.white.withValues(alpha: 0.06),
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
      fillColor: Colors.white.withValues(alpha: 0.06),
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
      labelStyle: _appTextStyle(
        color: AppColors.textSub,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
    ),
    textTheme: textTheme,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceElevated,
      contentTextStyle: _appTextStyle(color: AppColors.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.surfaceMuted,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      selectedColor: AppColors.primary.withValues(alpha: 0.22),
      labelStyle: _appTextStyle(
        color: AppColors.text,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xCC12151C),
      elevation: 0,
      shadowColor: Colors.transparent,
      indicatorColor: AppColors.primary.withValues(alpha: 0.22),
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
    dividerTheme: const DividerThemeData(color: AppColors.border),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
    ),
  );
}
