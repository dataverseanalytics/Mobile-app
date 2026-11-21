import 'package:country_picker/country_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/app/router.dart';
import 'package:nutrilens/data/auth/auth_repository.dart';
import 'package:nutrilens/data/auth/demo_auth_repository.dart';
import 'package:nutrilens/data/local_store.dart';
import 'package:nutrilens/data/mock_data.dart';
import 'package:nutrilens/features/auth/phone_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  group('authRedirect', () {
    test('signed-out users only see public pages', () {
      expect(authRedirect(null, Routes.today), Routes.welcome);
      expect(authRedirect(null, Routes.profile), Routes.welcome);
      expect(authRedirect(null, Routes.welcome), isNull);
      expect(authRedirect(null, Routes.phone), isNull);
      expect(authRedirect(null, Routes.privacy), isNull);
      expect(authRedirect(null, Routes.splash), isNull);
    });

    test('new accounts must finish profile setup, then onboarding', () {
      final noName = testAccount(name: '', onboarded: false);
      expect(authRedirect(noName, Routes.today), Routes.profileSetup);
      expect(authRedirect(noName, Routes.profileSetup), isNull);

      final named = testAccount(onboarded: false);
      expect(authRedirect(named, Routes.today), Routes.onboarding);
      expect(authRedirect(named, Routes.onboarding), isNull);
      expect(authRedirect(named, Routes.paywall), isNull);
    });

    test('ready accounts skip sign-in screens', () {
      final ready = testAccount();
      expect(authRedirect(ready, Routes.welcome), Routes.today);
      expect(authRedirect(ready, Routes.otp), Routes.today);
      expect(authRedirect(ready, Routes.profileSetup), Routes.today);
      expect(authRedirect(ready, Routes.today), isNull);
      expect(authRedirect(ready, Routes.onboarding), isNull); // recalculate
    });
  });

  group('PhoneUtils (worldwide)', () {
    final countries = {
      for (final c in CountryService().getAll()) c.countryCode: c,
    };
    Country c(String code) => countries[code]!;

    test('covers 200+ countries', () {
      expect(countries.length, greaterThan(200));
    });

    test('validates and normalises numbers per country', () {
      expect(PhoneUtils.toE164(c('IN'), '98765 43210'), '+919876543210');
      expect(PhoneUtils.toE164(c('US'), '(201) 555-0123'), '+12015550123');
      expect(PhoneUtils.toE164(c('GB'), '07400 123456'), '+447400123456');
      expect(PhoneUtils.toE164(c('AE'), '050 123 4567'), '+971501234567');
      expect(PhoneUtils.toE164(c('IN'), '12345'), isNull);
    });

    test('accepts a full international number in any country field', () {
      expect(PhoneUtils.toE164(c('US'), '+91 98765 43210'), '+919876543210');
    });

    test('pretty-prints for display', () {
      expect(PhoneUtils.pretty('+919876543210'), startsWith('+91 '));
    });
  });

  group('DemoAuthRepository', () {
    test('only accepts the demo code', () async {
      final repo = DemoAuthRepository();
      final sent = await repo.sendCode('+919876543210');
      final session = (sent as CodeSent).session;
      await expectLater(
        repo.verifyCode(session, '000000'),
        throwsA(isA<InvalidCodeFailure>()),
      );
      final user = await repo.verifyCode(session, DemoAuthRepository.code);
      expect(user.phone, '+919876543210');
    });
  });

  group('LocalStore', () {
    test('round-trips account and meals', () async {
      final meals = MockData.seedDiary(DateTime.now());
      final store = await makeStore(account: testAccount(), meals: meals);
      expect(store.account?.name, 'Aarav');
      expect(store.meals.length, meals.length);
      expect(store.meals.first.kcal, closeTo(meals.first.kcal, 0.001));

      await store.clearUser();
      expect(store.account, isNull);
      expect(store.meals, isEmpty);
    });

    test('ignores corrupt or wrongly-typed saved values', () async {
      SharedPreferences.setMockInitialValues({
        'account': 42, // wrong type
        'diary': 'not json',
        'premium': 'yes', // wrong type
      });
      final store = await LocalStore.open();
      expect(store.account, isNull);
      expect(store.meals, isEmpty);
      expect(store.premium, isFalse);
    });
  });
}
