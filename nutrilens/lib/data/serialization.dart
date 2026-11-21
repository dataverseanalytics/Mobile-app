import 'models.dart';

/// JSON for on-device persistence. Kept out of the models so they stay
/// plain and readable.
abstract final class Json {
  static double _d(Object? v) => (v as num?)?.toDouble() ?? 0;

  static Map<String, Object?> macros(Macros m) => {
    'p': m.protein,
    'c': m.carbs,
    'f': m.fat,
  };

  static Macros toMacros(Object? j) {
    final m = j as Map<String, Object?>;
    return Macros(protein: _d(m['p']), carbs: _d(m['c']), fat: _d(m['f']));
  }

  static Map<String, Object?> item(FoodItem i) => {
    'id': i.id,
    'name': i.name,
    'unit': i.unit,
    'macros': macros(i.macros),
    'servings': i.servings,
    'confidence': i.confidence,
  };

  static FoodItem toItem(Object? j) {
    final m = j as Map<String, Object?>;
    return FoodItem(
      id: m['id'] as String,
      name: m['name'] as String,
      unit: m['unit'] as String,
      macros: toMacros(m['macros']),
      servings: _d(m['servings']),
      confidence: _d(m['confidence']),
    );
  }

  static Map<String, Object?> meal(Meal meal) => {
    'id': meal.id,
    'name': meal.name,
    'photo': meal.photo,
    'loggedAt': meal.loggedAt.toIso8601String(),
    'type': meal.type.name,
    'healthScore': meal.healthScore,
    'items': [for (final i in meal.items) item(i)],
  };

  static Meal toMeal(Object? j) {
    final m = j as Map<String, Object?>;
    return Meal(
      id: m['id'] as String,
      name: m['name'] as String,
      photo: m['photo'] as String?,
      loggedAt: DateTime.parse(m['loggedAt'] as String),
      type: MealType.values.asNameMap()[m['type']] ?? MealType.snack,
      healthScore: _d(m['healthScore']),
      items: [for (final i in m['items'] as List<Object?>) toItem(i)],
    );
  }

  static Map<String, Object?> profile(UserProfile p) => {
    'goal': p.goal.name,
    'sex': p.sex.name,
    'age': p.age,
    'heightCm': p.heightCm,
    'weightKg': p.weightKg,
    'targetWeightKg': p.targetWeightKg,
    'activity': p.activity.name,
    'pace': p.paceKgPerWeek,
  };

  static UserProfile toProfile(Object? j) {
    final m = j as Map<String, Object?>;
    const d = UserProfile();
    return UserProfile(
      goal: Goal.values.asNameMap()[m['goal']] ?? d.goal,
      sex: Sex.values.asNameMap()[m['sex']] ?? d.sex,
      age: (m['age'] as num?)?.toInt() ?? d.age,
      heightCm: _d(m['heightCm']),
      weightKg: _d(m['weightKg']),
      targetWeightKg: _d(m['targetWeightKg']),
      activity: Activity.values.asNameMap()[m['activity']] ?? d.activity,
      paceKgPerWeek: _d(m['pace']),
    );
  }

  static Map<String, Object?> targets(DailyTargets t) => {
    'kcal': t.kcal,
    'macros': macros(t.macros),
  };

  static DailyTargets toTargets(Object? j) {
    final m = j as Map<String, Object?>;
    return DailyTargets(kcal: _d(m['kcal']), macros: toMacros(m['macros']));
  }
}
