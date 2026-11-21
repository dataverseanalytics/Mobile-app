import 'dart:math' as math;

import 'models.dart';

/// Nutrition maths. Pure functions — unit tested.
abstract final class Nutrition {
  /// Mifflin–St Jeor basal metabolic rate (kcal/day).
  static double bmr(UserProfile p) {
    final base = 10 * p.weightKg + 6.25 * p.heightCm - 5 * p.age;
    return p.sex == Sex.male ? base + 5 : base - 161;
  }

  static double tdee(UserProfile p) => bmr(p) * p.activity.factor;

  /// ~7,700 kcal per kg of body weight.
  static double dailyAdjustment(UserProfile p) {
    final delta = p.paceKgPerWeek * 7700 / 7;
    return switch (p.goal) {
      Goal.lose => -delta,
      Goal.maintain => 0,
      Goal.gain => delta * 0.6, // lean bulk: smaller surplus
    };
  }

  static DailyTargets targets(UserProfile p) {
    final floor = p.sex == Sex.male ? 1500.0 : 1200.0;
    final kcal = math.max(floor, tdee(p) + dailyAdjustment(p));
    final proteinPerKg = p.goal == Goal.maintain ? 1.6 : 1.8;
    final protein = p.weightKg * proteinPerKg;
    final fat = kcal * 0.28 / 9;
    final carbs = math.max(0.0, (kcal - protein * 4 - fat * 9) / 4);
    return DailyTargets(
      kcal: (kcal / 10).roundToDouble() * 10,
      macros: Macros(protein: protein, carbs: carbs, fat: fat),
    );
  }

  /// Weeks to reach the target weight at the chosen pace.
  static int weeksToGoal(UserProfile p) {
    if (p.goal == Goal.maintain || p.paceKgPerWeek <= 0) return 0;
    final diff = (p.weightKg - p.targetWeightKg).abs();
    return (diff / p.paceKgPerWeek).ceil();
  }
}
