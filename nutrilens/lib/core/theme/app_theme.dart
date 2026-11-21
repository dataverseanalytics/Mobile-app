import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'tokens.dart';

abstract final class AppFonts {
  /// Interface text.
  static const sans = 'Inter';

  /// Headlines, screen titles and big numbers.
  static const display = 'Sora';
}

abstract final class AppTheme {
  static ThemeData light() => _build(_lightScheme, AppColors.light);
  static ThemeData dark() => _build(_darkScheme, AppColors.dark);

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Palette.ink,
    onPrimary: Palette.white,
    primaryContainer: Palette.lime,
    onPrimaryContainer: Palette.ink,
    secondary: Palette.inkSoft,
    onSecondary: Palette.white,
    tertiary: Palette.limeDeep,
    onTertiary: Palette.ink,
    error: Palette.danger,
    onError: Palette.white,
    surface: Palette.paper,
    onSurface: Palette.ink,
    onSurfaceVariant: Palette.stone,
    surfaceContainerLowest: Palette.white,
    surfaceContainerLow: Palette.white,
    surfaceContainer: Color(0xFFF2EFE8),
    surfaceContainerHigh: Palette.sand,
    surfaceContainerHighest: Color(0xFFE8E4DA),
    outline: Palette.stoneLight,
    outlineVariant: Palette.line,
    inverseSurface: Palette.ink,
    onInverseSurface: Palette.mist,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Palette.lime,
    onPrimary: Palette.ink,
    primaryContainer: Palette.lime,
    onPrimaryContainer: Palette.ink,
    secondary: Palette.mist,
    onSecondary: Palette.ink,
    tertiary: Palette.lime,
    onTertiary: Palette.ink,
    error: Color(0xFFFF6369),
    onError: Palette.ink,
    surface: Palette.night,
    onSurface: Palette.mist,
    onSurfaceVariant: Palette.mistMuted,
    surfaceContainerLowest: Palette.night,
    surfaceContainerLow: Palette.night1,
    surfaceContainer: Palette.night2,
    surfaceContainerHigh: Palette.night2,
    surfaceContainerHighest: Palette.night3,
    outline: Color(0xFF5C5B54),
    outlineVariant: Palette.nightLine,
    inverseSurface: Palette.mist,
    onInverseSurface: Palette.ink,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static TextTheme _textTheme(Color ink) {
    const tabular = [FontFeature.tabularFigures()];
    TextStyle font(
      String family,
      double size,
      FontWeight w,
      double height, [
      double ls = 0,
    ]) => TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: w,
      height: height,
      letterSpacing: ls,
      color: ink,
    );
    const d = AppFonts.display;
    const s = AppFonts.sans;

    return TextTheme(
      // Sora — hero headlines (welcome, onboarding, paywall).
      displayLarge: font(d, 44, FontWeight.w700, 1.08, -1.6),
      displayMedium: font(d, 36, FontWeight.w700, 1.1, -1.2),
      displaySmall: font(d, 28, FontWeight.w700, 1.15, -0.8),
      // Sora — big numbers and screen titles.
      headlineLarge: font(
        d,
        34,
        FontWeight.w700,
        1.1,
        -1.2,
      ).copyWith(fontFeatures: tabular),
      headlineMedium: font(d, 26, FontWeight.w700, 1.15, -0.8),
      headlineSmall: font(d, 22, FontWeight.w700, 1.2, -0.5),
      titleLarge: font(d, 19, FontWeight.w600, 1.25, -0.3),
      // Inter — everything people read and tap.
      titleMedium: font(s, 16, FontWeight.w600, 1.3, -0.2),
      titleSmall: font(s, 14, FontWeight.w600, 1.3, -0.1),
      bodyLarge: font(s, 16, FontWeight.w400, 1.5, -0.1),
      bodyMedium: font(s, 14, FontWeight.w400, 1.45, -0.05),
      bodySmall: font(s, 12.5, FontWeight.w500, 1.4),
      labelLarge: font(s, 15, FontWeight.w600, 1.2),
      labelMedium: font(s, 13, FontWeight.w600, 1.2),
      labelSmall: font(s, 11, FontWeight.w600, 1.2, 0.5),
    );
  }

  static ThemeData _build(ColorScheme scheme, AppColors brand) {
    final text = _textTheme(scheme.onSurface);
    final isDark = scheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      fontFamily: AppFonts.sans,
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      extensions: [brand],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: brand.card,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, Sizes.buttonHeight),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          shape: const StadiumBorder(),
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, Sizes.buttonHeight),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant, width: 1.5),
          shape: const StadiumBorder(),
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(48, Sizes.minTap),
          textStyle: text.labelLarge,
          shape: const StadiumBorder(),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(Sizes.minTap, Sizes.minTap),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brand.card,
        hintStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: Radii.pillAll,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.pillAll,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.pillAll,
          borderSide: BorderSide(color: scheme.onSurface, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: brand.card,
        selectedColor: scheme.onSurface,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: text.labelMedium,
        secondaryLabelStyle: text.labelMedium?.copyWith(color: scheme.surface),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: Space.sm),
        showCheckmark: false,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.onSurface,
        inactiveTrackColor: brand.ringTrack,
        thumbColor: scheme.onSurface,
        overlayColor: scheme.onSurface.withValues(alpha: 0.08),
        trackHeight: 6,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? brand.onAccent
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? brand.accent
              : scheme.surfaceContainerHigh,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: brand.accent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.onSurface,
        linearTrackColor: brand.ringTrack,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
