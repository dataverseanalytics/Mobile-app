import 'package:flutter/material.dart';

/// Brand palette. Only the theme files reference these raw values.
abstract final class Palette {
  // Neutrals — warm, paper-like.
  static const paper = Color(0xFFF7F5F0);
  static const white = Color(0xFFFFFFFF);
  static const sand = Color(0xFFEFECE4);
  static const line = Color(0xFFE6E2D8);
  static const ink = Color(0xFF14140F);
  static const inkSoft = Color(0xFF2A2A24);
  static const stone = Color(0xFF6B6A62);
  static const stoneLight = Color(0xFF9B9A91);

  // Dark neutrals.
  static const night = Color(0xFF0E0E0C);
  static const night1 = Color(0xFF171714);
  static const night2 = Color(0xFF1F1F1B);
  static const night3 = Color(0xFF282823);
  static const nightLine = Color(0xFF33332D);
  static const mist = Color(0xFFF4F3EE);
  static const mistMuted = Color(0xFFA6A59C);

  // Signature accent — electric lime.
  static const lime = Color(0xFFD4F25A);
  static const limeDeep = Color(0xFF9DBF1F);

  // Macros.
  static const protein = Color(0xFFFF6B4A);
  static const carbs = Color(0xFFF5A623);
  static const fat = Color(0xFF4C8DFF);

  // Status.
  static const success = Color(0xFF22A06B);
  static const warning = Color(0xFFE8920C);
  static const danger = Color(0xFFE5484D);
}

/// Tokens the Material [ColorScheme] does not cover.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.accent,
    required this.onAccent,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.success,
    required this.warning,
    required this.ringTrack,
    required this.card,
    required this.scrim,
  });

  /// The lime highlight. Use sparingly: key signals and the scan button ring.
  final Color accent;
  final Color onAccent;
  final Color protein;
  final Color carbs;
  final Color fat;
  final Color success;
  final Color warning;
  final Color ringTrack;

  /// Raised card fill (white on paper in light mode).
  final Color card;

  /// Dark gradient used over photos so overlaid text keeps contrast.
  final Color scrim;

  static const light = AppColors(
    accent: Palette.lime,
    onAccent: Palette.ink,
    protein: Palette.protein,
    carbs: Palette.carbs,
    fat: Palette.fat,
    success: Palette.success,
    warning: Palette.warning,
    ringTrack: Palette.sand,
    card: Palette.white,
    scrim: Color(0xCC0E0E0C),
  );

  static const dark = AppColors(
    accent: Palette.lime,
    onAccent: Palette.ink,
    protein: Color(0xFFFF8166),
    carbs: Color(0xFFFFB84D),
    fat: Color(0xFF6FA3FF),
    success: Color(0xFF3CC48A),
    warning: Color(0xFFFFB84D),
    ringTrack: Palette.night3,
    card: Palette.night1,
    scrim: Color(0xDD000000),
  );

  @override
  AppColors copyWith({
    Color? accent,
    Color? onAccent,
    Color? protein,
    Color? carbs,
    Color? fat,
    Color? success,
    Color? warning,
    Color? ringTrack,
    Color? card,
    Color? scrim,
  }) => AppColors(
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    protein: protein ?? this.protein,
    carbs: carbs ?? this.carbs,
    fat: fat ?? this.fat,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    ringTrack: ringTrack ?? this.ringTrack,
    card: card ?? this.card,
    scrim: scrim ?? this.scrim,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return AppColors(
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      protein: l(protein, other.protein),
      carbs: l(carbs, other.carbs),
      fat: l(fat, other.fat),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      ringTrack: l(ringTrack, other.ringTrack),
      card: l(card, other.card),
      scrim: l(scrim, other.scrim),
    );
  }
}
