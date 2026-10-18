import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 우열 design tokens — see `/DESIGN.md` (app-icon brand).
abstract final class AppFonts {
  /// Bundled SUIT Variable (`assets/fonts/SUIT-Variable.ttf`).
  static const family = 'SUIT';

  /// Bundled IBM Plex Sans KR Bold — brand / display titles.
  static const display = 'IBM Plex Sans KR';
}

TextStyle _appTextStyle({
  Color? color,
  FontWeight? fontWeight,
  double? fontSize,
  double? height,
  String? fontFamily,
}) {
  return TextStyle(
    fontFamily: fontFamily ?? AppFonts.family,
    color: color,
    fontWeight: fontWeight,
    fontSize: fontSize,
    height: height,
  );
}

abstract final class AppColors {
  /// Pale mist canvas — blue only on CTA / active.
  static const background = Color(0xFFEEF3F8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceElevated = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFE8F1F8);

  static const primary = Color(0xFF2A72E5);
  static const primarySoft = Color(0xFFE8F1FC);
  static const primaryDark = Color(0xFF1E46AA);
  static const sky = Color(0xFF5EB7EB);
  static const spark = Color(0xFFFEB231);
  static const onPrimarySoft = Color(0xFF1E46AA);

  static const accent = Color(0xFFFF8C00);
  static const success = Color(0xFF2ECC40);
  static const warning = Color(0xFFB8860B);
  static const teacher = Color(0xFF9370DB);
  static const magenta = Color(0xFFE0119D);
  static const orange = Color(0xFFFF8C00);

  static const categoryBlue = primary;
  static const categoryGold = warning;
  static const categoryGreen = success;

  static const text = Color(0xFF111111);
  static const textSub = Color(0xFF494C4F);
  static const textMuted = Color(0xFF999999);

  static const border = Color(0xFFEFEFF1);
  static const borderStrong = Color(0xFFE0E0E4);

  static const glassFill = Color(0x38FFFFFF);
  static const glassStroke = Color(0xE8FFFFFF);
  static const glassShadow = Color(0x2E000000);
}

abstract final class AppShadows {
  static const raised = [
    BoxShadow(
      color: Color(0xFFC2CAD6),
      offset: Offset(10, 10),
      blurRadius: 20,
    ),
    BoxShadow(
      color: Color(0xFFFFFFFF),
      offset: Offset(-8, -8),
      blurRadius: 16,
    ),
  ];

  static const sunken = [
    BoxShadow(
      color: Color(0xFFC2CAD6),
      offset: Offset(7, 7),
      blurRadius: 14,
      blurStyle: BlurStyle.inner,
    ),
    BoxShadow(
      color: Color(0xFFFFFFFF),
      offset: Offset(-6, -6),
      blurRadius: 12,
      blurStyle: BlurStyle.inner,
    ),
  ];

  static const gel = [
    BoxShadow(
      color: Color(0xFFC2CAD6),
      offset: Offset(10, 10),
      blurRadius: 20,
    ),
    BoxShadow(
      color: Color(0xFFFFFFFF),
      offset: Offset(-7, -7),
      blurRadius: 14,
    ),
    BoxShadow(
      color: Color(0x382A72E5),
      offset: Offset(0, 10),
      blurRadius: 18,
    ),
    BoxShadow(
      color: Color(0x14000000),
      offset: Offset(0, 2),
      blurRadius: 6,
    ),
  ];
}

/// 홈 파란 무대 배경 — 165° 하늘색에서 코발트로.
abstract final class AppGradients {
  static const stage = LinearGradient(
    begin: Alignment(-0.27, -1),
    end: Alignment(0.27, 1),
    colors: [
      AppColors.sky,
      AppColors.primary,
      AppColors.primaryDark,
    ],
  );
}

/// 유리 프리셋 — 맑은 유리 / 무대용 유리 / 파란 유리.
enum GlassPreset { clear, onBlue, prominent }

/// 유리 한 장의 채움·흐림·테두리·그림자 값.
@immutable
class GlassSpec {
  const GlassSpec({
    required this.fill,
    required this.blur,
    required this.rim,
    required this.shadows,
    required this.topHighlight,
  });

  final Color fill;
  final double blur;
  final Color rim;
  final List<BoxShadow> shadows;

  /// 위쪽 안쪽 하이라이트를 그릴지 여부.
  final bool topHighlight;

  static const _clear = GlassSpec(
    fill: Color(0x4DFFFFFF),
    blur: 14,
    rim: Color(0xA8FFFFFF),
    shadows: [
      BoxShadow(
        color: Color(0x24112850),
        offset: Offset(0, 8),
        blurRadius: 24,
      ),
    ],
    topHighlight: true,
  );

  static const _onBlue = GlassSpec(
    fill: Color(0x24FFFFFF),
    blur: 16,
    rim: Color(0x61FFFFFF),
    shadows: [
      BoxShadow(
        color: Color(0x380A1E5A),
        offset: Offset(0, 10),
        blurRadius: 26,
      ),
    ],
    topHighlight: false,
  );

  static const _prominent = GlassSpec(
    fill: Color(0xE02A72E5),
    blur: 10,
    rim: Color(0x47FFFFFF),
    shadows: [
      BoxShadow(
        color: Color(0x522A72E5),
        offset: Offset(0, 8),
        blurRadius: 18,
      ),
    ],
    topHighlight: true,
  );

  static GlassSpec of(GlassPreset preset) {
    return switch (preset) {
      GlassPreset.clear => _clear,
      GlassPreset.onBlue => _onBlue,
      GlassPreset.prominent => _prominent,
    };
  }
}

abstract final class AppRadii {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 26.0;
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

/// Button / role typography — key action uses 17/w700 to match 62px height.
abstract final class AppTypography {
  static const button = 16.0;
  static const buttonWeight = FontWeight.w600;
  static const buttonKeyAction = 17.0;
  static const buttonKeyActionWeight = FontWeight.w700;

  static const display = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.1,
    color: AppColors.text,
  );

  static const title = TextStyle(
    fontFamily: AppFonts.family,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.22,
    color: AppColors.text,
  );

  static const headline = TextStyle(
    fontFamily: AppFonts.family,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.22,
    color: AppColors.text,
  );
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
      shape: const StadiumBorder(),
    );
  }

  /// 연파랑 주 버튼 — 탭 화면 본문.
  static ButtonStyle soft() => filled(
    backgroundColor: AppColors.primarySoft,
    foregroundColor: AppColors.primaryDark,
  );

  /// 흰 주 버튼 — 홈 파란 무대 위에서만.
  static ButtonStyle white() => filled(
    backgroundColor: Colors.white,
    foregroundColor: AppColors.primary,
  );

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
      shape: const StadiumBorder(),
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
      fontWeight: FontWeight.w700,
      fontFamily: AppFonts.display,
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
      backgroundColor: Colors.transparent,
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
      color: AppColors.surfaceElevated,
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
        side: const BorderSide(color: AppColors.glassStroke),
        backgroundColor: const Color(0x66FFFFFF),
        elevation: 0,
        minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        textStyle: _appTextStyle(
          fontSize: AppTypography.button,
          fontWeight: AppTypography.buttonWeight,
        ),
        shape: const StadiumBorder(),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0x66FFFFFF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        borderSide: const BorderSide(color: AppColors.glassStroke),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        borderSide: const BorderSide(color: AppColors.glassStroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
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
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.55),
      selectedColor: AppColors.primarySoft,
      labelStyle: _appTextStyle(
        color: AppColors.text,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      side: const BorderSide(color: AppColors.glassStroke),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? AppColors.primary
            : Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? AppColors.primarySoft
            : const Color(0x66FFFFFF);
      }),
      trackOutlineColor: WidgetStateProperty.all(AppColors.glassStroke),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      indicatorColor: AppColors.primarySoft,
      indicatorShape: const StadiumBorder(),
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
