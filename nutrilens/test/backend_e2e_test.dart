// End-to-end: the app's real API client ↔ FastAPI ↔ PostgreSQL.
//
// Skipped unless a backend is running and NUTRILENS_E2E_API is set:
//   NUTRILENS_E2E_API=http://localhost:8001 flutter test test/backend_e2e_test.dart
// Uses the backend's OTP test number (+15005550006 → code 123456, see
// OTP_TEST_NUMBERS in backend/.env) and deletes the account afterwards.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/data/account.dart';
import 'package:nutrilens/data/api/api_client.dart';
import 'package:nutrilens/data/api/sync_service.dart';
import 'package:nutrilens/data/auth/api_auth_repository.dart';
import 'package:nutrilens/data/auth/auth_repository.dart';
import 'package:nutrilens/data/models.dart';
import 'package:nutrilens/data/serialization.dart';

import 'helpers.dart';

final _base = Platform.environment['NUTRILENS_E2E_API'] ?? '';

void main() {
  test(
    'sign in, sync, scan, search and pull against the live backend',
    () async {
      final tokens = MemoryTokenStore();
      final api = ApiClient(baseUrl: _base, tokens: tokens);
      final auth = ApiAuthRepository(api);

      // 1. Phone OTP sign-in.
      final sent = await auth.sendCode('+15005550006') as CodeSent;
      final user = await auth.verifyCode(sent.session, '123456');
      expect(tokens.access, isNotNull);

      final store = await makeStore(
        account: Account(
          uid: user.uid,
          phone: user.phone,
          createdAt: DateTime.now(),
        ),
      );
      final sync = SyncService(api, store, debounce: Duration.zero);

      try {
        // 2. Offline-first writes reach the server.
        await sync.enqueue(
          'PATCH',
          '/v1/me',
          body: {'name': 'E2E Tester', 'onboarded': true},
        );
        final meal = Meal(
          id: 'e2e-meal-1',
          name: 'Dal & rice',
          loggedAt: DateTime.now().toUtc(),
          type: MealType.lunch,
          healthScore: 7.5,
          items: const [
            FoodItem(
              id: 'a',
              name: 'Dal tadka',
              unit: '1 bowl',
              macros: Macros(protein: 12, carbs: 28, fat: 8),
            ),
          ],
        );
        await sync.enqueue(
          'PUT',
          '/v1/meals/${meal.id}',
          body: Json.meal(meal),
        );
        await sync.flush();
        expect(sync.pending, 0);

        // 3. AI scan with a real photo upload.
        final bytes = await File('assets/images/tofu_poke_bowl.jpg')
            .readAsBytes();
        final scan = (await api.uploadImage(
          '/v1/scan',
          field: 'photo',
          bytes: bytes,
          filename: 'tofu_poke_bowl.jpg',
          contentType: 'image/jpeg',
        )).asMap;
        expect(Json.toMeal(scan['meal']).name, 'Tofu poke bowl');
        expect(scan['scansLeft'], 2);

        // 4. Food search from the admin-managed database.
        final foods = (await api.get('/v1/foods', query: {'q': 'dal'})).asList;
        expect(foods, isNotEmpty);

        // 5. Pull the server state back into a fresh device store.
        final account = await sync.pull(store.account!);
        expect(account.name, 'E2E Tester');
        expect(account.onboarded, isTrue);
        expect(store.meals.map((m) => m.id), contains('e2e-meal-1'));
        expect(store.notices.length, greaterThanOrEqualTo(2)); // welcome + tip
      } finally {
        // 6. Leave no trace in the database.
        await auth.deleteAccount();
      }
      expect(tokens.access, isNull);
    },
    skip: _base.isEmpty
        ? 'Set NUTRILENS_E2E_API to run against a live backend'
        : false,
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
