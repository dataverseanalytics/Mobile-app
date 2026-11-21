import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutrilens/data/api/api_client.dart';
import 'package:nutrilens/data/api/sync_service.dart';
import 'package:nutrilens/data/auth/api_auth_repository.dart';
import 'package:nutrilens/data/auth/auth_repository.dart';

import 'helpers.dart';

http.Response json(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('ApiClient', () {
    test('refreshes an expired token once and retries', () async {
      final tokens = MemoryTokenStore()
        ..access = 'old'
        ..refresh = 'r1';
      var refreshes = 0;
      final client = ApiClient(
        baseUrl: 'http://api',
        tokens: tokens,
        httpClient: MockClient((req) async {
          if (req.url.path == '/v1/auth/refresh') {
            refreshes++;
            return json({'accessToken': 'new', 'refreshToken': 'r2'});
          }
          return req.headers['authorization'] == 'Bearer new'
              ? json({'ok': true})
              : json({'detail': 'Session expired'}, 401);
        }),
      );

      // Two concurrent 401s share one refresh.
      final results = await Future.wait([
        client.get('/v1/me'),
        client.get('/v1/me'),
      ]);
      expect(results, everyElement({'ok': true}));
      expect(refreshes, 1);
      expect(tokens.access, 'new');
      expect(tokens.refresh, 'r2');
    });

    test('a rejected refresh ends the session', () async {
      final tokens = MemoryTokenStore()
        ..access = 'old'
        ..refresh = 'bad';
      var expired = false;
      final client = ApiClient(
        baseUrl: 'http://api',
        tokens: tokens,
        httpClient: MockClient((_) async => json({'detail': 'nope'}, 401)),
      )..onSessionExpired = () => expired = true;

      await expectLater(client.get('/v1/me'), throwsA(isA<SessionExpired>()));
      expect(expired, isTrue);
      expect(tokens.access, isNull);
    });

    test('surfaces the server message and flags transient errors', () async {
      final client = ApiClient(
        baseUrl: 'http://api',
        tokens: MemoryTokenStore(),
        httpClient: MockClient(
          (_) async => json({
            'detail': [
              {'msg': 'Enter a valid email'},
            ],
          }, 422),
        ),
      );
      final e = await client
          .patch('/v1/me', {})
          .then<ApiException?>(
            (_) => null,
            onError: (Object e) => e as ApiException,
          );
      expect(e?.message, 'Enter a valid email');
      expect(e?.isTransient, isFalse);
      expect(const ApiException(503, 'x').isTransient, isTrue);
      expect(const ApiException(0, 'x').isTransient, isTrue);
    });
  });

  group('SyncService', () {
    test('coalesces updates with the same key and sends in order', () async {
      final store = await makeStore();
      final sent = <String>[];
      final api = ApiClient(
        baseUrl: 'http://api',
        tokens: MemoryTokenStore()..access = 't',
        httpClient: MockClient((req) async {
          sent.add('${req.method} ${req.url.path} ${req.body}');
          return json({});
        }),
      );
      final sync = SyncService(api, store, debounce: Duration.zero);

      for (var w = 70; w <= 75; w++) {
        await sync.enqueue(
          'PATCH',
          '/v1/me',
          body: {
            'profile': {'weightKg': w},
          },
          key: 'me.profile',
        );
      }
      await sync.enqueue(
        'PUT',
        '/v1/meals/m1',
        body: {'name': 'Dal'},
        key: 'meal.m1',
      );
      expect(sync.pending, 2); // six profile edits became one
      await sync.flush();

      expect(sent, [
        'PATCH /v1/me {"profile":{"weightKg":75}}',
        'PUT /v1/meals/m1 {"name":"Dal"}',
      ]);
      expect(sync.pending, 0);
    });

    test('keeps the queue while offline and drops rejected writes', () async {
      final store = await makeStore();
      var online = false;
      final api = ApiClient(
        baseUrl: 'http://api',
        tokens: MemoryTokenStore()..access = 't',
        httpClient: MockClient((req) async {
          if (!online) throw http.ClientException('offline');
          if (req.url.path == '/v1/meals/bad') {
            return json({'detail': 'invalid'}, 422);
          }
          return json({});
        }),
      );
      final sync = SyncService(api, store, debounce: const Duration(hours: 1));
      await sync.enqueue('PUT', '/v1/meals/bad', body: {});
      await sync.enqueue('PUT', '/v1/meals/good', body: {});

      await sync.flush();
      expect(sync.pending, 2, reason: 'offline: nothing lost');
      expect(store.outbox.length, 2, reason: 'persisted across restarts');

      online = true;
      await sync.flush();
      expect(sync.pending, 0, reason: '422 dropped, good one sent');
    });

    test('pull replaces device data with the server state', () async {
      final store = await makeStore(
        account: testAccount(name: '', onboarded: false),
      );
      final api = ApiClient(
        baseUrl: 'http://api',
        tokens: MemoryTokenStore()..access = 't',
        httpClient: MockClient(
          (_) async => json({
            'user': {
              'id': 'u1',
              'phone': '+12015550123',
              'name': 'Aarav',
              'email': 'a@x.com',
              'onboarded': true,
              'profile': {'goal': 'gain', 'weightKg': 70},
              'customTargets': null,
              'reminders': null,
              'isPremium': true,
              'freeScansLeft': 1,
            },
            'meals': [
              {
                'id': 'm1',
                'name': 'Dal',
                'photo': null,
                'loggedAt': '2026-11-20T12:00:00Z',
                'type': 'lunch',
                'healthScore': 8,
                'items': [
                  {
                    'id': 'i',
                    'name': 'Dal',
                    'unit': '1 bowl',
                    'macros': {'p': 12, 'c': 28, 'f': 8},
                    'servings': 1,
                    'confidence': 1,
                  },
                ],
              },
            ],
            'weights': [
              {'kg': 71.0, 'loggedAt': '2026-11-01T00:00:00Z'},
              {'kg': 70.0, 'loggedAt': '2026-11-15T00:00:00Z'},
            ],
            'notices': [
              {
                'id': 'n1',
                'kind': 'welcome',
                'title': 'Hi',
                'body': 'Welcome',
                'createdAt': '2026-11-20T10:00:00Z',
                'read': false,
              },
            ],
            'config': {'free_scan_allowance': 3},
          }),
        ),
      );
      final account = await SyncService(api, store).pull(store.account!);

      expect(account.name, 'Aarav');
      expect(account.onboarded, isTrue);
      expect(store.meals.single.name, 'Dal');
      expect(store.meals.single.kcal, closeTo(12 * 4 + 28 * 4 + 8 * 9, 0.01));
      expect(store.weights, [71.0, 70.0]);
      expect(store.notices.single.title, 'Hi');
      expect(store.profile?.weightKg, 70);
      expect(store.premium, isTrue);
    });
  });

  group('ApiAuthRepository', () {
    test('verifies the code, stores tokens and maps errors', () async {
      final tokens = MemoryTokenStore();
      final api = ApiClient(
        baseUrl: 'http://api',
        tokens: tokens,
        httpClient: MockClient((req) async {
          final body = jsonDecode(req.body) as Map<String, Object?>;
          if (req.url.path == '/v1/auth/otp/request') {
            return json({
              'phone': '+919876543210',
              'expiresIn': 300,
              'resendIn': 30,
              'devCode': '424242',
            });
          }
          if (body['code'] != '424242') {
            return json({'detail': "That code isn't right."}, 400);
          }
          return json({
            'accessToken': 'a',
            'refreshToken': 'r',
            'expiresIn': 1800,
            'isNew': true,
            'user': {'id': 'u-1', 'phone': '+919876543210', 'name': ''},
          });
        }),
      );
      final repo = ApiAuthRepository(api);
      final sent = await repo.sendCode('+919876543210') as CodeSent;
      expect(sent.session.devCode, '424242');

      await expectLater(
        repo.verifyCode(sent.session, '000000'),
        throwsA(isA<InvalidCodeFailure>()),
      );
      final user = await repo.verifyCode(sent.session, '424242');
      expect(user.uid, 'u-1');
      expect(tokens.access, 'a');
      expect(tokens.refresh, 'r');
    });
  });
}
