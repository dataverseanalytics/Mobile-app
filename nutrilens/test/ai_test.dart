import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutrilens/data/ai_repository.dart';
import 'package:nutrilens/data/api/api_client.dart';
import 'package:nutrilens/data/models.dart';

http.Response json(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

ApiClient server(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
      baseUrl: 'http://api',
      tokens: MemoryTokenStore()..access = 't',
      httpClient: MockClient(handler),
    );

void main() {
  test('describeMeal sends the text and returns a meal to review', () async {
    final repo = AiRepository(
      api: server((req) async {
        expect(req.url.path, '/v1/ai/parse-meal');
        expect(jsonDecode(req.body), {'text': '2 rotis and dal'});
        return json({
          'meal': {
            'id': 'm1',
            'name': 'Roti & dal',
            'loggedAt': '2026-11-21T08:00:00Z',
            'type': 'lunch',
            'healthScore': 7,
            'items': [
              {
                'id': 'db1-0',
                'name': 'Roti',
                'unit': '1 roti',
                'macros': {'p': 3, 'c': 18, 'f': 3},
                'servings': 2,
                'confidence': 0.97,
              },
            ],
          },
          'newFoods': <String>[],
        });
      }),
    );
    final meal = await repo.describeMeal('2 rotis and dal');
    expect(meal.name, 'Roti & dal');
    expect(meal.items.single.servings, 2);
    expect(meal.loggedAt.isUtc, isFalse);
  });

  test('daily limit message is passed through', () async {
    final repo = AiRepository(
      api: server(
        (_) async => json({
          'detail':
              "You've used today's 20 AI requests — upgrade to Pro for more.",
        }, 429),
      ),
    );
    expect(
      repo.describeMeal('dal'),
      throwsA(
        isA<AiFailure>().having((e) => e.message, 'message', contains('Pro')),
      ),
    );
  });

  test('suggestions send the remaining budget', () async {
    final repo = AiRepository(
      api: server((req) async {
        expect(req.url.path, '/v1/ai/suggestions');
        final body = jsonDecode(req.body) as Map<String, Object?>;
        expect(body['remainingKcal'], 600);
        expect(body['mealType'], 'dinner');
        return json([
          {
            'title': 'Paneer tikka',
            'why': 'High protein for what is left',
            'portion': '150 g',
            'macros': {'p': 28, 'c': 8, 'f': 20},
            'vegetarian': true,
          },
        ]);
      }),
    );
    final ideas = await repo.suggestions(
      remainingKcal: 600,
      remaining: const Macros(protein: 40, carbs: 50, fat: 20),
      mealType: MealType.dinner,
    );
    expect(ideas.single.title, 'Paneer tikka');
    expect(ideas.single.vegetarian, isTrue);
  });

  test('offline demo splits a description into items', () async {
    final meal = await AiRepository().describeMeal('2 eggs and toast');
    expect(meal.items, hasLength(2));
    expect(meal.items.first.servings, 2);
  });
}
