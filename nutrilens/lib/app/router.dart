import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/common.dart';
import '../data/account.dart';
import '../features/auth/otp_screen.dart';
import '../features/auth/phone_screen.dart';
import '../features/auth/profile_setup_screen.dart';
import '../features/diary/diary_screen.dart';
import '../features/meal/meal_detail_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/onboarding/onboarding_flow.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/paywall/paywall_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/scan/analyzing_screen.dart';
import '../features/scan/camera_screen.dart';
import '../features/scan/scan_result_screen.dart';
import '../features/search/food_search_screen.dart';
import '../features/settings/about_screen.dart';
import '../features/settings/account_screen.dart';
import '../features/settings/goals_screen.dart';
import '../features/settings/help_screen.dart';
import '../features/settings/legal_screen.dart';
import '../features/settings/reminders_screen.dart';
import '../features/settings/subscription_screen.dart';
import '../features/share/share_card_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/splash/splash_screen.dart';
import '../features/today/today_screen.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const welcome = '/welcome';
  static const phone = '/auth/phone';
  static const otp = '/auth/otp';
  static const profileSetup = '/auth/profile';
  static const onboarding = '/onboarding';
  static const paywall = '/paywall';
  static const today = '/today';
  static const diary = '/diary';
  static const progress = '/progress';
  static const profile = '/profile';
  static const scan = '/scan';
  static const analyzing = '/scan/analyzing';
  static const result = '/scan/result';
  static const search = '/search';
  static const notifications = '/notifications';
  static const editProfile = '/settings/profile';
  static const goals = '/settings/goals';
  static const reminders = '/settings/reminders';
  static const subscription = '/settings/subscription';
  static const account = '/settings/account';
  static const help = '/help';
  static const about = '/about';
  static const terms = '/legal/terms';
  static const privacy = '/legal/privacy';
  static String meal(String id) => '/meal/$id';
  static String share(String id) => '/share/$id';

  /// Reachable without signing in.
  static const public = {splash, welcome, phone, otp, terms, privacy};

  /// Sign-in steps a signed-in user should never land on again.
  static const authOnly = {welcome, phone, otp};
}

/// Where a user belongs, given their account state. Pure — unit tested.
String? authRedirect(Account? account, String location) {
  if (location == Routes.splash) return null;
  if (account == null) {
    return Routes.public.contains(location) ? null : Routes.welcome;
  }
  const legal = {Routes.terms, Routes.privacy};
  if (!account.hasProfile) {
    return location == Routes.profileSetup || legal.contains(location)
        ? null
        : Routes.profileSetup;
  }
  if (!account.onboarded) {
    const allowed = {Routes.onboarding, Routes.paywall, ...legal};
    return allowed.contains(location) ? null : Routes.onboarding;
  }
  if (Routes.authOnly.contains(location) || location == Routes.profileSetup) {
    return Routes.today;
  }
  return null;
}

final _rootKey = GlobalKey<NavigatorState>();

/// Slide-up modal transition for the capture flow.
CustomTransitionPage<void> _modal(GoRouterState s, Widget child) =>
    CustomTransitionPage<void>(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (context, a, _, child) {
        final curved = CurvedAnimation(
          parent: a,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );

GoRoute _page(String path, Widget Function(GoRouterState s) build) => GoRoute(
  path: path,
  parentNavigatorKey: _rootKey,
  builder: (_, s) => build(s),
);

GoRouter buildRouter({
  required Account? Function() account,
  required Listenable refresh,
}) => GoRouter(
  navigatorKey: _rootKey,
  initialLocation: Routes.splash,
  refreshListenable: refresh,
  redirect: (_, state) => authRedirect(account(), state.matchedLocation),
  errorBuilder: (context, state) {
    debugPrint('Router error at ${state.uri}: ${state.error}');
    return Scaffold(
      body: Center(
        child: EmptyState(
          icon: Icons.explore_off_rounded,
          title: 'This page wandered off',
          message: "The link may be old or mistyped. Let's get you back.",
          actionLabel: 'Go to today',
          onAction: () => context.go(Routes.today),
        ),
      ),
    );
  },
  routes: [
    GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
    GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
    GoRoute(path: Routes.phone, builder: (_, _) => const PhoneScreen()),
    GoRoute(path: Routes.otp, builder: (_, _) => const OtpScreen()),
    GoRoute(
      path: Routes.profileSetup,
      builder: (_, _) => const ProfileSetupScreen(),
    ),
    GoRoute(path: Routes.onboarding, builder: (_, _) => const OnboardingFlow()),
    GoRoute(
      path: Routes.paywall,
      parentNavigatorKey: _rootKey,
      pageBuilder: (_, s) => _modal(
        s,
        PaywallScreen(
          fromOnboarding: s.uri.queryParameters['from'] == 'onboarding',
        ),
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: Routes.today, builder: (_, _) => const TodayScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: Routes.diary, builder: (_, _) => const DiaryScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.progress,
              builder: (_, _) => const ProgressScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.profile,
              builder: (_, _) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: Routes.scan,
      parentNavigatorKey: _rootKey,
      pageBuilder: (_, s) => _modal(
        s,
        CameraScreen(barcode: s.uri.queryParameters['mode'] == 'barcode'),
      ),
      routes: [
        GoRoute(
          path: 'analyzing',
          parentNavigatorKey: _rootKey,
          pageBuilder: (_, s) => NoTransitionPage(
            key: s.pageKey,
            child: AnalyzingScreen(photo: s.uri.queryParameters['photo'] ?? ''),
          ),
        ),
        GoRoute(
          path: 'result',
          parentNavigatorKey: _rootKey,
          builder: (_, _) => const ScanResultScreen(),
        ),
      ],
    ),
    GoRoute(
      path: Routes.search,
      parentNavigatorKey: _rootKey,
      pageBuilder: (_, s) => _modal(s, const FoodSearchScreen()),
    ),
    _page(
      '/meal/:id',
      (s) => MealDetailScreen(mealId: s.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/share/:id',
      parentNavigatorKey: _rootKey,
      pageBuilder: (_, s) =>
          _modal(s, ShareCardScreen(mealId: s.pathParameters['id'] ?? '')),
    ),
    _page(Routes.notifications, (_) => const NotificationsScreen()),
    _page(Routes.editProfile, (_) => const ProfileSetupScreen(editing: true)),
    _page(Routes.goals, (_) => const GoalsScreen()),
    _page(Routes.reminders, (_) => const RemindersScreen()),
    _page(Routes.subscription, (_) => const SubscriptionScreen()),
    _page(Routes.account, (_) => const AccountScreen()),
    _page(Routes.help, (_) => const HelpScreen()),
    _page(Routes.about, (_) => const AboutScreen()),
    _page(Routes.terms, (_) => const LegalScreen(doc: LegalDoc.terms)),
    _page(Routes.privacy, (_) => const LegalScreen(doc: LegalDoc.privacy)),
  ],
);
