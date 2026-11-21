import 'package:flutter/foundation.dart';

import 'api/api_client.dart';
import 'mock_data.dart';
import 'models.dart';
import 'serialization.dart';

/// An AI "what to eat next" idea that fits the rest of today's budget.
@immutable
class AiSuggestion {
  const AiSuggestion({
    required this.title,
    required this.why,
    required this.portion,
    required this.macros,
    required this.vegetarian,
  });

  final String title;
  final String why;
  final String portion;
  final Macros macros;
  final bool vegetarian;

  static AiSuggestion fromJson(Map<String, Object?> j) => AiSuggestion(
    title: j['title']! as String,
    why: j['why']! as String,
    portion: j['portion']! as String,
    macros: Json.toMacros(j['macros']),
    vegetarian: j['vegetarian'] == true,
  );
}

class AiFailure implements Exception {
  const AiFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// AI features beyond the photo scan. All AI runs on the server (the key
/// never ships in the app); without a backend, simple offline versions keep
/// demo mode working.
class AiRepository {
  AiRepository({this.api});

  final ApiClient? api;

  /// "2 rotis, dal and a salad" → a meal to review before logging.
  Future<Meal> describeMeal(String text) async {
    final client = api;
    if (client == null) return _describeOffline(text);
    try {
      final json = (await client.post('/v1/ai/parse-meal', {
        'text': text,
      })).asMap;
      final meal = Json.toMeal(json['meal']);
      return Meal(
        id: meal.id,
        name: meal.name,
        loggedAt: meal.loggedAt.toLocal(),
        type: meal.type,
        items: meal.items,
        healthScore: meal.healthScore,
      );
    } on ApiException catch (e) {
      throw AiFailure(e.message);
    }
  }

  Future<List<AiSuggestion>> suggestions({
    required Macros remaining,
    required double remainingKcal,
    required MealType mealType,
  }) async {
    final client = api;
    if (client == null) return _offlineSuggestions(remainingKcal);
    try {
      final list = (await client.post('/v1/ai/suggestions', {
        'remainingKcal': remainingKcal.clamp(0, 10000),
        'remainingProtein': remaining.protein.clamp(0, 1000),
        'remainingCarbs': remaining.carbs.clamp(0, 2000),
        'remainingFat': remaining.fat.clamp(0, 1000),
        'mealType': mealType.name,
      })).asList;
      return [for (final s in list) AiSuggestion.fromJson(s.asMap)];
    } on ApiException catch (e) {
      throw AiFailure(e.message);
    }
  }

  // ── Offline demo versions ──────────────────────────────────────────────────

  static final _split = RegExp(
    r',|\band\b|\bwith\b|\+|&',
    caseSensitive: false,
  );

  Meal _describeOffline(String text) {
    final parts = text
        .split(_split)
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);
    final items = <FoodItem>[];
    var i = 0;
    for (final part in parts) {
      final count = RegExp(r'^(\d+)\s+').firstMatch(part);
      final servings = count == null ? 1.0 : double.parse(count.group(1)!);
      final name = count == null ? part : part.substring(count.end);
      final lower = name.toLowerCase().replaceAll(RegExp(r's$'), '');
      final match = MockData.foodDatabase
          .where((f) => f.name.toLowerCase().contains(lower))
          .firstOrNull;
      items.add(
        FoodItem(
          id: 'offline-${i++}',
          name: match?.name ?? name,
          unit: match?.unit ?? '1 serving',
          macros: match?.macros ?? const Macros(protein: 8, carbs: 25, fat: 6),
          servings: servings,
          confidence: match == null ? 0.6 : 0.95,
        ),
      );
    }
    if (items.isEmpty) {
      throw const AiFailure('Describe what you ate, e.g. “2 rotis and dal”.');
    }
    final now = DateTime.now();
    return Meal(
      id: 'meal-${now.microsecondsSinceEpoch}',
      name: items.length == 1 ? items.first.name : '${items.first.name} & more',
      loggedAt: now,
      type: MealType.forTime(now),
      items: items,
    );
  }

  List<AiSuggestion> _offlineSuggestions(double remainingKcal) => [
    for (final s in MockData.suggestions)
      if (s.macros.kcal <= remainingKcal + 150)
        AiSuggestion(
          title: s.title,
          why: s.why,
          portion: '1 plate',
          macros: s.macros,
          vegetarian: true,
        ),
  ];
}
