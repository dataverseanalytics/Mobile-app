import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/app/app.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/data/account.dart';
import 'package:nutrilens/data/auth/demo_auth_repository.dart';
import 'package:nutrilens/data/local_store.dart';
import 'package:nutrilens/data/models.dart';
import 'package:nutrilens/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fresh on-device store, optionally pre-filled.
Future<LocalStore> makeStore({
  Account? account,
  List<Meal> meals = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  if (account != null) await store.saveAccount(account);
  if (meals.isNotEmpty) await store.saveMeals(meals);
  return store;
}

Account testAccount({String name = 'Aarav', bool onboarded = true}) => Account(
  uid: 'demo-12015550123',
  phone: '+12015550123',
  name: name,
  onboarded: onboarded,
  createdAt: DateTime(2026, 11),
);

ProviderContainer makeContainer(LocalStore store) => ProviderContainer(
  overrides: [
    localStoreProvider.overrideWithValue(store),
    authRepositoryProvider.overrideWithValue(DemoAuthRepository()),
  ],
);

/// The whole app (router, guards, theme).
Widget fullApp(ProviderContainer c) =>
    UncontrolledProviderScope(container: c, child: const NutriLensApp());

/// A single screen inside a themed MaterialApp.
Widget screen(ProviderContainer c, Widget child) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

void usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// The page's main vertical scroll view (not horizontal carousels).
final mainScroll = find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;
