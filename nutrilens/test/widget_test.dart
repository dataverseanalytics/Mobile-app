import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/data/mock_data.dart';
import 'package:nutrilens/features/scan/scan_result_screen.dart';
import 'package:nutrilens/features/today/today_screen.dart';
import 'package:nutrilens/state/providers.dart';

import 'helpers.dart';

void main() {
  testWidgets('new user signs in with phone OTP and reaches onboarding', (
    tester,
  ) async {
    usePhoneSize(tester);
    final c = makeContainer(await makeStore());
    addTearDown(c.dispose);

    await tester.pumpWidget(fullApp(c));
    await tester.pump(const Duration(seconds: 2)); // splash
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your phone number'), findsOneWidget);

    // Test locale is en_US → +1. Incomplete number first.
    await tester.enterText(find.byType(TextField).first, '201555');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
      reason: 'Send code stays disabled until the number is complete',
    );

    await tester.enterText(find.byType(TextField).first, '201 555 0123');
    await tester.pump();
    await tester.tap(find.text('Send code'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Enter the code'), findsOneWidget);
    expect(find.textContaining('Demo mode'), findsOneWidget);

    // Wrong code → error, stays on screen.
    await tester.enterText(find.byKey(const Key('otp-input')), '000000');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining("That code isn't right"), findsOneWidget);

    // Right code → profile setup.
    await tester.enterText(find.byKey(const Key('otp-input')), '123456');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('What should we call you?'), findsOneWidget);
    expect(c.read(accountProvider)?.phone, '+12015550123');

    await tester.enterText(find.byType(TextFormField).first, 'Aarav Shah');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text("What's your goal?"), findsOneWidget);
    expect(c.read(accountProvider)?.name, 'Aarav Shah');
    // Welcome notifications are created for new accounts.
    expect(c.read(unreadNoticesProvider), 2);
  });

  testWidgets('onboarding walks through to a calculated plan', (tester) async {
    usePhoneSize(tester);
    final c = makeContainer(
      await makeStore(account: testAccount(onboarded: false)),
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(fullApp(c));
    await tester.pump(const Duration(seconds: 2)); // splash → guard
    await tester.pumpAndSettle();

    for (final title in [
      "What's your goal?",
      'A little about you',
      'Height & weight',
      'Your target weight',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    expect(find.text('How active are you?'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump(); // starts the page animation
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Building your plan'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Your plan is ready'), findsOneWidget);

    await tester.tap(find.text('Start my plan'));
    await tester.pumpAndSettle();
    expect(c.read(accountProvider)?.onboarded, isTrue);
    expect(find.text('Get Pro · ₹2,499'), findsOneWidget);
  });

  testWidgets('signed-in user goes straight to Today and is greeted by name', (
    tester,
  ) async {
    usePhoneSize(tester);
    final c = makeContainer(
      await makeStore(
        account: testAccount(),
        meals: MockData.seedDiary(DateTime.now()),
      ),
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(fullApp(c));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Hi, Aarav'), findsOneWidget);
    expect(find.text('Calories left'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Avocado & egg toast'),
      300,
      scrollable: mainScroll,
    );
    expect(find.text('Avocado & egg toast'), findsOneWidget);
  });

  testWidgets('today shows a designed empty state with no meals', (
    tester,
  ) async {
    usePhoneSize(tester);
    final c = makeContainer(await makeStore(account: testAccount()));
    addTearDown(c.dispose);

    await tester.pumpWidget(screen(c, const TodayScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('No meals yet today'),
      300,
      scrollable: mainScroll,
    );
    expect(find.text('No meals yet today'), findsOneWidget);
  });

  testWidgets('scan result lists items and logging saves the meal', (
    tester,
  ) async {
    usePhoneSize(tester);
    final store = await makeStore(account: testAccount());
    final c = makeContainer(store);
    addTearDown(c.dispose);
    final meal = MockData.scanSamples(DateTime.now()).first;
    c.read(scanDraftProvider.notifier).set(meal);

    await tester.pumpWidget(screen(c, const ScanResultScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Tofu poke bowl'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Seared tofu'),
      300,
      scrollable: mainScroll,
    );
    expect(find.text('Seared tofu'), findsOneWidget);

    c.read(scanDraftProvider.notifier).removeItem('s1');
    await tester.pumpAndSettle();
    expect(find.text('Seared tofu'), findsNothing);

    // Logging persists to the device store.
    c.read(diaryProvider.notifier).add(c.read(scanDraftProvider)!);
    expect(store.meals.single.items.length, meal.items.length - 1);
  });

  testWidgets('sign out clears the session and returns to welcome', (
    tester,
  ) async {
    usePhoneSize(tester);
    final store = await makeStore(
      account: testAccount(),
      meals: MockData.seedDiary(DateTime.now()),
    );
    final c = makeContainer(store);
    addTearDown(c.dispose);

    await tester.pumpWidget(fullApp(c));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await c.read(accountProvider.notifier).signOut();
    await tester.pumpAndSettle();

    expect(find.text('Get started'), findsOneWidget);
    expect(store.account, isNull);
    expect(store.meals, isEmpty);
    expect(c.read(diaryProvider), isEmpty);
  });
}
