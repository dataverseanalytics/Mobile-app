import 'package:flutter/foundation.dart';

enum MealType {
  breakfast('Breakfast'),
  lunch('Lunch'),
  dinner('Dinner'),
  snack('Snack');

  const MealType(this.label);
  final String label;

  static MealType forTime(DateTime t) => switch (t.hour) {
    < 11 => MealType.breakfast,
    < 16 => MealType.lunch,
    < 18 => MealType.snack,
    _ => MealType.dinner,
  };
}

/// Grams of each macronutrient.
@immutable
class Macros {
  const Macros({required this.protein, required this.carbs, required this.fat});

  static const zero = Macros(protein: 0, carbs: 0, fat: 0);

  final double protein;
  final double carbs;
  final double fat;

  double get kcal => protein * 4 + carbs * 4 + fat * 9;

  Macros operator +(Macros o) => Macros(
    protein: protein + o.protein,
    carbs: carbs + o.carbs,
    fat: fat + o.fat,
  );

  Macros operator *(double f) =>
      Macros(protein: protein * f, carbs: carbs * f, fat: fat * f);
}

/// One recognised food inside a meal. [macros] is per one [unit].
@immutable
class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.macros,
    this.servings = 1,
    this.confidence = 1,
  });

  final String id;
  final String name;

  /// Human portion label, e.g. "1 cup (150 g)".
  final String unit;
  final Macros macros;
  final double servings;

  /// AI confidence 0–1. Manually added items are 1.
  final double confidence;

  Macros get total => macros * servings;
  double get kcal => total.kcal;

  FoodItem copyWith({double? servings}) => FoodItem(
    id: id,
    name: name,
    unit: unit,
    macros: macros,
    servings: servings ?? this.servings,
    confidence: confidence,
  );
}

@immutable
class Meal {
  const Meal({
    required this.id,
    required this.name,
    required this.loggedAt,
    required this.type,
    required this.items,
    this.photo,
    this.healthScore = 7,
  });

  final String id;
  final String name;
  final String? photo;
  final DateTime loggedAt;
  final MealType type;
  final List<FoodItem> items;

  /// 0–10, higher is better balanced.
  final double healthScore;

  Macros get macros => items.fold(Macros.zero, (a, i) => a + i.total);
  double get kcal => macros.kcal;

  double get confidence => items.isEmpty
      ? 0
      : items.map((i) => i.confidence).reduce((a, b) => a + b) / items.length;

  Meal copyWith({
    String? id,
    List<FoodItem>? items,
    MealType? type,
    DateTime? loggedAt,
  }) => Meal(
    id: id ?? this.id,
    name: name,
    photo: photo,
    loggedAt: loggedAt ?? this.loggedAt,
    type: type ?? this.type,
    items: items ?? this.items,
    healthScore: healthScore,
  );
}

enum Goal {
  lose('Lose weight', 'Burn fat, keep muscle'),
  maintain('Maintain', 'Stay balanced and energised'),
  gain('Build muscle', 'Lean gains, more strength');

  const Goal(this.label, this.subtitle);
  final String label;
  final String subtitle;
}

enum Sex { female, male }

enum Activity {
  sedentary('Mostly sitting', 'Desk job, little exercise', 1.2),
  light('Lightly active', 'Walks, 1–3 workouts a week', 1.375),
  moderate('Active', '3–5 workouts a week', 1.55),
  high('Very active', 'Daily training or physical job', 1.725);

  const Activity(this.label, this.subtitle, this.factor);
  final String label;
  final String subtitle;
  final double factor;
}

@immutable
class UserProfile {
  const UserProfile({
    this.goal = Goal.lose,
    this.sex = Sex.male,
    this.age = 30,
    this.heightCm = 175,
    this.weightKg = 78,
    this.targetWeightKg = 72,
    this.activity = Activity.light,
    this.paceKgPerWeek = 0.5,
  });

  final Goal goal;
  final Sex sex;
  final int age;
  final double heightCm;
  final double weightKg;
  final double targetWeightKg;
  final Activity activity;
  final double paceKgPerWeek;

  UserProfile copyWith({
    Goal? goal,
    Sex? sex,
    int? age,
    double? heightCm,
    double? weightKg,
    double? targetWeightKg,
    Activity? activity,
    double? paceKgPerWeek,
  }) => UserProfile(
    goal: goal ?? this.goal,
    sex: sex ?? this.sex,
    age: age ?? this.age,
    heightCm: heightCm ?? this.heightCm,
    weightKg: weightKg ?? this.weightKg,
    targetWeightKg: targetWeightKg ?? this.targetWeightKg,
    activity: activity ?? this.activity,
    paceKgPerWeek: paceKgPerWeek ?? this.paceKgPerWeek,
  );
}

/// Daily targets derived from a [UserProfile].
@immutable
class DailyTargets {
  const DailyTargets({required this.kcal, required this.macros});
  final double kcal;
  final Macros macros;
}

/// A searchable database food.
@immutable
class FoodEntry {
  const FoodEntry({
    required this.name,
    required this.unit,
    required this.macros,
    this.photo,
    this.brand,
    this.aiEstimated = false,
  });
  final String name;
  final String unit;
  final Macros macros;
  final String? photo;
  final String? brand;

  /// Added by the AI from a meal description and not yet checked by the team.
  final bool aiEstimated;
}
