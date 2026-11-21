import '../core/assets.dart';
import 'models.dart';

/// Demo content until the AI backend is connected. Values are realistic
/// estimates so the UI is designed against true-to-life numbers.
abstract final class MockData {
  static FoodItem _i(
    String id,
    String name,
    String unit,
    double p,
    double c,
    double f, {
    double servings = 1,
    double conf = 0.94,
  }) => FoodItem(
    id: id,
    name: name,
    unit: unit,
    macros: Macros(protein: p, carbs: c, fat: f),
    servings: servings,
    confidence: conf,
  );

  /// What the "AI" returns for each demo photo.
  static List<Meal> scanSamples(DateTime now) => [
    Meal(
      id: 'scan-tofu',
      name: 'Tofu poke bowl',
      photo: Photos.tofuPokeBowl,
      loggedAt: now,
      type: MealType.forTime(now),
      healthScore: 8.8,
      items: [
        _i('s1', 'Seared tofu', '150 g', 18, 4, 11, conf: 0.95),
        _i('s2', 'Edamame', '½ cup (75 g)', 8.5, 7, 4, conf: 0.92),
        _i('s3', 'Boiled egg', '1 egg (50 g)', 6, 0.6, 5, conf: 0.97),
        _i('s4', 'Sweetcorn', '3 tbsp (40 g)', 1.3, 8, 0.6, conf: 0.9),
        _i('s5', 'Cherry tomatoes', '80 g', 0.7, 3, 0.2, conf: 0.88),
        _i('s6', 'Greens, cabbage & cucumber', '120 g', 2, 7, 0.3, conf: 0.76),
      ],
    ),
    Meal(
      id: 'scan-biryani',
      name: 'Chicken biryani',
      photo: Photos.chickenBiryani,
      loggedAt: now,
      type: MealType.forTime(now),
      healthScore: 6.1,
      items: [
        _i(
          'b1',
          'Basmati rice (biryani)',
          '1.5 cups (240 g)',
          7,
          68,
          9,
          conf: 0.93,
        ),
        _i('b2', 'Chicken pieces', '130 g', 32, 2, 11, conf: 0.9),
        _i('b3', 'Fried onions', '2 tbsp (15 g)', 0.4, 5, 4.5, conf: 0.81),
        _i('b4', 'Raita', '½ cup (100 g)', 3.5, 5, 3, conf: 0.72),
      ],
    ),
    Meal(
      id: 'scan-burger',
      name: 'Double cheeseburger',
      photo: Photos.cheeseburger,
      loggedAt: now,
      type: MealType.forTime(now),
      healthScore: 3.8,
      items: [
        _i('c1', 'Beef patties', '2 × 90 g', 38, 0, 30, conf: 0.95),
        _i('c2', 'Brioche bun', '1 bun (75 g)', 7, 38, 6, conf: 0.93),
        _i('c3', 'Cheddar slices', '2 slices (40 g)', 10, 0.5, 13, conf: 0.9),
        _i('c4', 'Burger sauce', '1 tbsp (15 g)', 0.2, 2, 7, conf: 0.76),
        _i('c5', 'Lettuce, tomato & onion', '50 g', 0.6, 3, 0.1, conf: 0.88),
      ],
    ),
  ];

  static List<Meal> seedDiary(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    DateTime at(int daysAgo, int h, [int m = 0]) => today
        .subtract(Duration(days: daysAgo))
        .add(Duration(hours: h, minutes: m));

    final meals = <Meal>[
      Meal(
        id: 'm-today-1',
        name: 'Avocado & egg toast',
        photo: Photos.avocadoEggToast,
        loggedAt: at(0, 8, 40),
        type: MealType.breakfast,
        healthScore: 8.2,
        items: [
          _i('t1', 'Sourdough toast', '2 slices (80 g)', 7, 40, 1.5),
          _i('t2', 'Avocado', '½ fruit (70 g)', 1.4, 6, 10),
          _i('t3', 'Boiled eggs', '2 eggs', 12, 1.2, 10),
        ],
      ),
      Meal(
        id: 'm-today-2',
        name: 'Paneer curry with rice',
        photo: Photos.paneerCurryRice,
        loggedAt: at(0, 13, 15),
        type: MealType.lunch,
        healthScore: 6.8,
        items: [
          _i('t4', 'Paneer curry', '1 bowl (200 g)', 18, 12, 24),
          _i('t5', 'Steamed basmati rice', '1 cup (160 g)', 4, 45, 0.5),
        ],
      ),
    ];

    // Six previous days so Diary, streaks and Progress have history.
    final history = <(String, String, MealType, int, List<FoodItem>, double)>[
      (
        'Berry yogurt bowl',
        Photos.berryYogurtBowl,
        MealType.breakfast,
        8,
        [_i('h1', 'Greek yogurt bowl with berries', '1 bowl', 18, 42, 9)],
        8.8,
      ),
      (
        'Quinoa & veg plate',
        Photos.quinoaPlate,
        MealType.lunch,
        13,
        [_i('h2', 'Quinoa, beans & roast veg', '1 plate', 16, 58, 14)],
        8.9,
      ),
      (
        'Chicken biryani',
        Photos.chickenBiryani,
        MealType.dinner,
        20,
        [_i('h3', 'Chicken biryani', '1 plate', 36, 80, 24)],
        6.1,
      ),
      (
        'Samosa',
        Photos.samosa,
        MealType.snack,
        17,
        [_i('h4', 'Vegetable samosa', '2 pieces', 6, 48, 22)],
        3.9,
      ),
      (
        'Garden salad',
        Photos.gardenSalad,
        MealType.lunch,
        13,
        [_i('h5', 'Garden salad with feta', '1 bowl', 9, 14, 16)],
        9.1,
      ),
      (
        'Steak & greens',
        Photos.steakPlate,
        MealType.dinner,
        20,
        [_i('h6', 'Sirloin steak with greens', '1 plate', 46, 10, 26)],
        7.6,
      ),
      (
        'Pancake stack',
        Photos.pancakeStack,
        MealType.breakfast,
        9,
        [_i('h7', 'Pancakes with syrup', '3 pancakes', 11, 86, 16)],
        4.2,
      ),
      (
        'Buddha bowl',
        Photos.buddhaBowl,
        MealType.lunch,
        13,
        [_i('h8', 'Chickpea buddha bowl', '1 bowl', 19, 62, 18)],
        9.0,
      ),
      (
        'Margherita pizza',
        Photos.margheritaPizza,
        MealType.dinner,
        21,
        [_i('h9', 'Margherita pizza', '3 slices', 30, 96, 30)],
        4.6,
      ),
      (
        'Grill platter',
        Photos.grillPlatter,
        MealType.dinner,
        20,
        [_i('h10', 'Mixed grill', '1 plate', 52, 22, 34)],
        6.9,
      ),
      (
        'Breakfast plate',
        Photos.breakfastPlate,
        MealType.breakfast,
        8,
        [_i('h11', 'Eggs, greens & avocado', '1 plate', 20, 18, 24)],
        8.7,
      ),
      (
        'Pasta salad',
        Photos.pastaSalad,
        MealType.lunch,
        13,
        [_i('h12', 'Pesto pasta salad', '1 bowl', 14, 64, 20)],
        6.4,
      ),
    ];

    for (var day = 1; day <= 6; day++) {
      for (var k = 0; k < 3; k++) {
        final h = history[(day * 3 + k) % history.length];
        meals.add(
          Meal(
            id: 'm-$day-$k',
            name: h.$1,
            photo: h.$2,
            loggedAt: at(day, h.$4),
            type: h.$3,
            items: h.$5,
            healthScore: h.$6,
          ),
        );
      }
    }
    return meals;
  }

  /// Weight log for the Progress chart (oldest first).
  static const weightTrend = [
    80.4,
    80.1,
    79.9,
    79.6,
    79.7,
    79.1,
    78.9,
    78.6,
    78.4,
    78.0,
  ];

  static const foodDatabase = <FoodEntry>[
    FoodEntry(
      name: 'Masala dosa',
      unit: '1 dosa (180 g)',
      macros: Macros(protein: 7, carbs: 52, fat: 14),
    ),
    FoodEntry(
      name: 'Dal tadka',
      unit: '1 bowl (200 g)',
      macros: Macros(protein: 12, carbs: 28, fat: 8),
    ),
    FoodEntry(
      name: 'Chicken biryani',
      unit: '1 plate (350 g)',
      macros: Macros(protein: 36, carbs: 80, fat: 24),
      photo: Photos.chickenBiryani,
    ),
    FoodEntry(
      name: 'Paneer butter masala',
      unit: '1 bowl (200 g)',
      macros: Macros(protein: 18, carbs: 14, fat: 30),
      photo: Photos.paneerCurryRice,
    ),
    FoodEntry(
      name: 'Roti (whole wheat)',
      unit: '1 roti (40 g)',
      macros: Macros(protein: 3, carbs: 18, fat: 3.5),
    ),
    FoodEntry(
      name: 'Idli with sambar',
      unit: '3 idli + 1 bowl',
      macros: Macros(protein: 10, carbs: 58, fat: 4),
    ),
    FoodEntry(
      name: 'Poha',
      unit: '1 plate (180 g)',
      macros: Macros(protein: 5, carbs: 46, fat: 9),
    ),
    FoodEntry(
      name: 'Vegetable samosa',
      unit: '1 piece (80 g)',
      macros: Macros(protein: 3, carbs: 24, fat: 11),
      photo: Photos.samosa,
    ),
    FoodEntry(
      name: 'Rajma chawal',
      unit: '1 plate (350 g)',
      macros: Macros(protein: 15, carbs: 78, fat: 9),
    ),
    FoodEntry(
      name: 'Greek yogurt, plain',
      unit: '1 cup (170 g)',
      macros: Macros(protein: 17, carbs: 6, fat: 4),
      brand: 'Packaged',
    ),
    FoodEntry(
      name: 'Banana',
      unit: '1 medium (118 g)',
      macros: Macros(protein: 1.3, carbs: 27, fat: 0.4),
    ),
    FoodEntry(
      name: 'Boiled egg',
      unit: '1 large (50 g)',
      macros: Macros(protein: 6, carbs: 0.6, fat: 5),
    ),
    FoodEntry(
      name: 'Oats with milk',
      unit: '1 bowl (250 g)',
      macros: Macros(protein: 11, carbs: 44, fat: 7),
    ),
    FoodEntry(
      name: 'Grilled chicken breast',
      unit: '150 g',
      macros: Macros(protein: 46, carbs: 0, fat: 5),
    ),
    FoodEntry(
      name: 'Tofu poke bowl',
      unit: '1 bowl (500 g)',
      macros: Macros(protein: 37, carbs: 30, fat: 21),
      photo: Photos.tofuPokeBowl,
    ),
    FoodEntry(
      name: 'Margherita pizza',
      unit: '1 slice (110 g)',
      macros: Macros(protein: 10, carbs: 32, fat: 10),
      photo: Photos.margheritaPizza,
    ),
    FoodEntry(
      name: 'Cheeseburger',
      unit: '1 burger (220 g)',
      macros: Macros(protein: 30, carbs: 40, fat: 28),
      photo: Photos.cheeseburger,
    ),
    FoodEntry(
      name: 'Avocado toast',
      unit: '1 slice',
      macros: Macros(protein: 5, carbs: 22, fat: 12),
      photo: Photos.avocadoEggToast,
    ),
    FoodEntry(
      name: 'Whey protein shake',
      unit: '1 scoop + water',
      macros: Macros(protein: 24, carbs: 3, fat: 1.5),
      brand: 'Packaged',
    ),
    FoodEntry(
      name: 'Masala chai',
      unit: '1 cup (150 ml)',
      macros: Macros(protein: 2.5, carbs: 12, fat: 3),
    ),
    FoodEntry(
      name: 'Almonds',
      unit: '20 g (~15 nuts)',
      macros: Macros(protein: 4.2, carbs: 4.3, fat: 10),
    ),
    FoodEntry(
      name: 'Apple',
      unit: '1 medium (180 g)',
      macros: Macros(protein: 0.5, carbs: 25, fat: 0.3),
    ),
  ];

  /// Barcode demo product.
  static const barcodeProduct = FoodEntry(
    name: 'High-protein Greek yogurt',
    unit: '1 cup (170 g)',
    brand: 'Scanned barcode',
    macros: Macros(protein: 15, carbs: 7, fat: 2.5),
    photo: Photos.berryYogurtBowl,
  );

  static const suggestions = [
    (
      title: 'Quinoa & roast veg plate',
      photo: Photos.quinoaPlate,
      macros: Macros(protein: 22, carbs: 58, fat: 14),
      why: 'High protein and fibre — keeps you full',
    ),
    (
      title: 'Chickpea buddha bowl',
      photo: Photos.buddhaBowl,
      macros: Macros(protein: 19, carbs: 62, fat: 18),
      why: 'Fibre-rich and keeps you full till bedtime',
    ),
    (
      title: 'Greens, eggs & avocado',
      photo: Photos.breakfastPlate,
      macros: Macros(protein: 20, carbs: 18, fat: 24),
      why: 'Low-carb way to close your protein gap',
    ),
  ];
}
