// Explicit profile values keep the expected maths readable.
// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/format.dart';
import 'package:nutrilens/data/models.dart';
import 'package:nutrilens/data/nutrition.dart';

void main() {
  group('Nutrition', () {
    const female = UserProfile(
      sex: Sex.female,
      age: 30,
      heightCm: 165,
      weightKg: 70,
      targetWeightKg: 62,
      activity: Activity.moderate,
      paceKgPerWeek: 0.5,
    );

    test('Mifflin–St Jeor BMR', () {
      // 10*70 + 6.25*165 - 5*30 - 161 = 1420.25
      expect(Nutrition.bmr(female), closeTo(1420.25, 0.01));
      expect(
        Nutrition.bmr(female.copyWith(sex: Sex.male)),
        closeTo(1586.25, 0.01),
      );
    });

    test('losing weight creates a deficit, gaining a surplus', () {
      final tdee = Nutrition.tdee(female);
      final lose = Nutrition.targets(female).kcal;
      final gain = Nutrition.targets(female.copyWith(goal: Goal.gain)).kcal;
      final keep = Nutrition.targets(female.copyWith(goal: Goal.maintain)).kcal;
      expect(lose, lessThan(tdee));
      expect(gain, greaterThan(tdee));
      expect(keep, closeTo(tdee, 10));
    });

    test('never goes below a safe calorie floor', () {
      final tiny = female.copyWith(
        weightKg: 40,
        heightCm: 140,
        age: 80,
        activity: Activity.sedentary,
        paceKgPerWeek: 1,
      );
      expect(Nutrition.targets(tiny).kcal, greaterThanOrEqualTo(1200));
    });

    test('macros add up to the calorie target', () {
      final t = Nutrition.targets(female);
      expect(t.macros.kcal, closeTo(t.kcal, 15));
      expect(t.macros.protein, closeTo(70 * 1.8, 0.01));
    });

    test('weeks to goal', () {
      expect(Nutrition.weeksToGoal(female), 16); // 8 kg at 0.5 kg/week
      expect(Nutrition.weeksToGoal(female.copyWith(goal: Goal.maintain)), 0);
    });
  });

  group('Meal maths', () {
    test('servings scale macros and calories', () {
      const item = FoodItem(
        id: '1',
        name: 'Rice',
        unit: '1 cup',
        macros: Macros(protein: 4, carbs: 45, fat: 0.5),
      );
      expect(item.kcal, closeTo(200.5, 0.01));
      expect(item.copyWith(servings: 2).kcal, closeTo(401, 0.01));
    });
  });

  group('Fmt', () {
    test('thousands separators', () {
      expect(Fmt.thousands(950), '950');
      expect(Fmt.thousands(1240), '1,240');
      expect(Fmt.thousands(1234567), '1,234,567');
      expect(Fmt.thousands(-1500), '-1,500');
    });

    test('servings', () {
      expect(Fmt.servings(1), '1');
      expect(Fmt.servings(1.5), '1.5');
      expect(Fmt.servings(0.25), '0.25');
      expect(Fmt.servings(10), '10');
    });
  });
}
