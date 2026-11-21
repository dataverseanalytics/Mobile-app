import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_repository.dart';
import '../data/account.dart';
import '../data/api/api_client.dart';
import '../data/api/sync_service.dart';
import '../data/auth/auth_repository.dart';
import '../data/local_store.dart';
import '../data/models.dart';
import '../data/payments/payments.dart';
import '../data/nutrition.dart';
import '../data/scan_repository.dart';
import '../data/serialization.dart';

DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

// ── Infrastructure (overridden in main / tests) ─────────────────────────────

final localStoreProvider = Provider<LocalStore>(
  (ref) => throw UnimplementedError('Override localStoreProvider in main()'),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) =>
      throw UnimplementedError('Override authRepositoryProvider in main()'),
);

/// Backend client; `null` when the app runs on-device only (no API_URL).
final apiClientProvider = Provider<ApiClient?>((ref) => null);

final syncServiceProvider = Provider<SyncService?>((ref) {
  final api = ref.watch(apiClientProvider);
  return api == null ? null : SyncService(api, ref.watch(localStoreProvider));
});

final scanRepositoryProvider = Provider<ScanRepository>(
  (ref) => ScanRepository(api: ref.watch(apiClientProvider)),
);

/// Razorpay on mobile; overridden with a fake in tests.
final aiRepositoryProvider = Provider<AiRepository>(
  (ref) => AiRepository(api: ref.watch(apiClientProvider)),
);

/// What's left of today's budget, rounded so small changes reuse the result.
typedef SuggestionKey = ({
  int kcal,
  int protein,
  int carbs,
  int fat,
  MealType meal,
});

final aiSuggestionsProvider = FutureProvider.autoDispose
    .family<List<AiSuggestion>, SuggestionKey>(
      (ref, k) => ref
          .watch(aiRepositoryProvider)
          .suggestions(
            remainingKcal: k.kcal.toDouble(),
            remaining: Macros(
              protein: k.protein.toDouble(),
              carbs: k.carbs.toDouble(),
              fat: k.fat.toDouble(),
            ),
            mealType: k.meal,
          ),
    );

final paymentGatewayProvider = Provider<PaymentGateway>(
  (ref) => defaultPaymentGateway(),
);

final paymentsRepositoryProvider = Provider<PaymentsRepository>(
  (ref) => PaymentsRepository(
    api: ref.watch(apiClientProvider),
    gateway: ref.watch(paymentGatewayProvider),
  ),
);

/// Pro plans with server-decided prices (falls back to bundled values).
final proPlansProvider = FutureProvider<List<ProPlan>>(
  (ref) => ref.watch(paymentsRepositoryProvider).plans(),
);

/// Queue a server write when a backend is connected; no-op otherwise.
/// The device store is always written first, so the UI never waits.
void _sync(Ref ref, String method, String path, {Object? body, String? key}) {
  final sync = ref.read(syncServiceProvider);
  if (sync != null) {
    unawaited(sync.enqueue(method, path, body: body, key: key));
  }
}

// ── Account / session ───────────────────────────────────────────────────────

class AccountNotifier extends Notifier<Account?> {
  LocalStore get _store => ref.read(localStoreProvider);
  AuthRepository get _auth => ref.read(authRepositoryProvider);

  @override
  Account? build() => _store.account;

  Future<void> _save(Account a) async {
    state = a;
    await _store.saveAccount(a);
  }

  /// Called after a successful OTP. Returning users keep their data.
  Future<void> signedIn(AuthUser user) async {
    final existing = _store.account;
    if (existing != null && existing.uid == user.uid) {
      state = existing;
      return;
    }
    // A different person on this device: start clean.
    await _store.clearUser();
    _invalidateUserData();
    final account = Account(
      uid: user.uid,
      phone: user.phone,
      name: user.displayName ?? '',
      createdAt: DateTime.now(),
    );
    await _save(account);
    if (ref.read(syncServiceProvider) == null) {
      await ref.read(noticesProvider.notifier).welcome();
    } else {
      await refreshFromServer(); // the server creates welcome notices itself
    }
  }

  /// Pull the user's data from the backend (sign-in, app start).
  /// Offline or failing: keep what's on the device.
  Future<void> refreshFromServer() async {
    final sync = ref.read(syncServiceProvider);
    final local = state;
    if (sync == null || local == null) return;
    try {
      final remote = await sync.pull(local);
      _invalidateSyncedData();
      state = remote;
    } on ApiException catch (e) {
      debugPrint('Sync skipped: ${e.message}');
    }
  }

  Future<void> saveProfile({
    required String name,
    required String email,
  }) async {
    final a = state;
    if (a == null) return;
    await _save(a.copyWith(name: name.trim(), email: email.trim()));
    await _auth.updateDisplayName(name.trim());
    _sync(
      ref,
      'PATCH',
      '/v1/me',
      body: {'name': name.trim(), 'email': email.trim()},
      key: 'me.name',
    );
  }

  Future<void> completeOnboarding() async {
    final a = state;
    if (a == null || a.onboarded) return;
    await _save(a.copyWith(onboarded: true));
    _sync(
      ref,
      'PATCH',
      '/v1/me',
      // Send the whole plan too: someone who accepts every default never
      // triggers a profile edit, and their plan must survive a new phone.
      body: {
        'onboarded': true,
        'profile': Json.profile(ref.read(profileProvider)),
      },
      key: 'me.onboarded',
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _wipe();
  }

  Future<void> deleteAccount() async {
    await _auth.deleteAccount();
    await _wipe();
  }

  Future<void> _wipe() async {
    await ref.read(syncServiceProvider)?.clear();
    await _store.clearUser();
    _invalidateUserData();
    state = null;
  }

  void _invalidateUserData() {
    _invalidateSyncedData();
    ref.invalidate(scanDraftProvider);
  }

  void _invalidateSyncedData() {
    ref
      ..invalidate(profileProvider)
      ..invalidate(diaryProvider)
      ..invalidate(premiumProvider)
      ..invalidate(premiumUntilProvider)
      ..invalidate(freeScansProvider)
      ..invalidate(customTargetsProvider)
      ..invalidate(remindersProvider)
      ..invalidate(weightLogProvider)
      ..invalidate(noticesProvider);
  }
}

final accountProvider = NotifierProvider<AccountNotifier, Account?>(
  AccountNotifier.new,
);

// ── Settings ────────────────────────────────────────────────────────────────

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() =>
      ThemeMode.values.asNameMap()[ref.read(localStoreProvider).theme] ??
      ThemeMode.system;

  void set(ThemeMode mode) {
    state = mode;
    ref.read(localStoreProvider).saveTheme(mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

// ── Profile & targets ───────────────────────────────────────────────────────

class ProfileNotifier extends Notifier<UserProfile> {
  @override
  UserProfile build() =>
      ref.read(localStoreProvider).profile ?? const UserProfile();

  void update(UserProfile Function(UserProfile p) f) {
    state = f(state);
    ref.read(localStoreProvider).saveProfile(state);
    _sync(
      ref,
      'PATCH',
      '/v1/me',
      body: {'profile': Json.profile(state)},
      key: 'me.profile',
    );
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, UserProfile>(
  ProfileNotifier.new,
);

/// User-chosen targets. `null` means "calculate automatically".
class CustomTargetsNotifier extends Notifier<DailyTargets?> {
  @override
  DailyTargets? build() => ref.read(localStoreProvider).customTargets;

  void set(DailyTargets? t) {
    state = t;
    ref.read(localStoreProvider).saveCustomTargets(t);
    _sync(
      ref,
      'PATCH',
      '/v1/me',
      body: {'customTargets': t == null ? null : Json.targets(t)},
      key: 'me.targets',
    );
  }
}

final customTargetsProvider =
    NotifierProvider<CustomTargetsNotifier, DailyTargets?>(
      CustomTargetsNotifier.new,
    );

final autoTargetsProvider = Provider<DailyTargets>(
  (ref) => Nutrition.targets(ref.watch(profileProvider)),
);

final targetsProvider = Provider<DailyTargets>(
  (ref) => ref.watch(customTargetsProvider) ?? ref.watch(autoTargetsProvider),
);

// ── Subscription ────────────────────────────────────────────────────────────

class PremiumNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(localStoreProvider).premium;

  void activate() => set(true);

  void set(bool value) {
    state = value;
    ref.read(localStoreProvider).savePremium(value);
  }

  /// After a successful purchase.
  void activateUntil(DateTime? until) {
    set(true);
    ref.read(premiumUntilProvider.notifier).set(until);
  }
}

final premiumProvider = NotifierProvider<PremiumNotifier, bool>(
  PremiumNotifier.new,
);

/// When the current Pro pass ends (passes don't auto-renew).
class PremiumUntilNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => ref.read(localStoreProvider).premiumUntil;

  void set(DateTime? until) {
    state = until;
    ref.read(localStoreProvider).savePremiumUntil(until);
  }
}

final premiumUntilProvider = NotifierProvider<PremiumUntilNotifier, DateTime?>(
  PremiumUntilNotifier.new,
);

/// Free AI scans remaining before the paywall.
class FreeScansNotifier extends Notifier<int> {
  static const allowance = 3;

  @override
  int build() => ref.read(localStoreProvider).freeScans ?? allowance;

  void consume() => set(state - 1);

  /// The server is authoritative when connected (scan responses carry it).
  void set(int value) {
    state = value.clamp(0, 1000);
    ref.read(localStoreProvider).saveFreeScans(state);
  }
}

final freeScansProvider = NotifierProvider<FreeScansNotifier, int>(
  FreeScansNotifier.new,
);

final canScanProvider = Provider<bool>(
  (ref) => ref.watch(premiumProvider) || ref.watch(freeScansProvider) > 0,
);

// ── Diary ───────────────────────────────────────────────────────────────────

class DiaryNotifier extends Notifier<List<Meal>> {
  @override
  List<Meal> build() => ref.read(localStoreProvider).meals;

  void _set(List<Meal> meals) {
    state = meals;
    ref.read(localStoreProvider).saveMeals(meals);
  }

  void add(Meal meal) {
    _set([...state, meal]);
    _sync(
      ref,
      'PUT',
      '/v1/meals/${Uri.encodeComponent(meal.id)}',
      body: Json.meal(meal),
      key: 'meal.${meal.id}',
    );
  }

  void remove(String id) {
    _set(state.where((m) => m.id != id).toList());
    _sync(
      ref,
      'DELETE',
      '/v1/meals/${Uri.encodeComponent(id)}',
      key: 'meal.$id',
    );
  }

  void restore(Meal meal) => add(meal);
}

final diaryProvider = NotifierProvider<DiaryNotifier, List<Meal>>(
  DiaryNotifier.new,
);

final mealsForDayProvider = Provider.family<List<Meal>, DateTime>((ref, day) {
  final d = dateOnly(day);
  final meals =
      ref.watch(diaryProvider).where((m) => dateOnly(m.loggedAt) == d).toList()
        ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
  return meals;
});

final dayMacrosProvider = Provider.family<Macros, DateTime>(
  (ref, day) => ref
      .watch(mealsForDayProvider(day))
      .fold(Macros.zero, (a, m) => a + m.macros),
);

final selectedDayProvider = NotifierProvider<SelectedDayNotifier, DateTime>(
  SelectedDayNotifier.new,
);

class SelectedDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => dateOnly(DateTime.now());
  void select(DateTime d) => state = dateOnly(d);
}

/// Consecutive days (ending today or yesterday) with at least one meal.
final streakProvider = Provider<int>((ref) {
  final days = ref
      .watch(diaryProvider)
      .map((m) => dateOnly(m.loggedAt))
      .toSet();
  var cursor = dateOnly(DateTime.now());
  if (!days.contains(cursor)) cursor = cursor.subtract(const Duration(days: 1));
  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
});

// ── Weight log ──────────────────────────────────────────────────────────────

class WeightLogNotifier extends Notifier<List<double>> {
  @override
  List<double> build() =>
      ref.read(localStoreProvider).weights ??
      [ref.read(profileProvider).weightKg];

  void log(double kg) {
    state = [...state, kg];
    _sync(ref, 'POST', '/v1/weights', body: {'kg': kg});
    ref.read(localStoreProvider).saveWeights(state);
    ref.read(profileProvider.notifier).update((p) => p.copyWith(weightKg: kg));
  }
}

final weightLogProvider = NotifierProvider<WeightLogNotifier, List<double>>(
  WeightLogNotifier.new,
);

// ── Reminders ───────────────────────────────────────────────────────────────

class RemindersNotifier extends Notifier<List<Reminder>> {
  @override
  List<Reminder> build() =>
      ref.read(localStoreProvider).reminders ?? Reminder.defaults;

  void update(Reminder r) =>
      _save([for (final x in state) x.id == r.id ? r : x]);

  void setAll(bool enabled) =>
      _save([for (final x in state) x.copyWith(enabled: enabled)]);

  void _save(List<Reminder> reminders) {
    state = reminders;
    ref.read(localStoreProvider).saveReminders(state);
    _sync(
      ref,
      'PATCH',
      '/v1/me',
      body: {
        'reminders': [for (final r in state) r.toJson()],
      },
      key: 'me.reminders',
    );
  }
}

final remindersProvider = NotifierProvider<RemindersNotifier, List<Reminder>>(
  RemindersNotifier.new,
);

// ── In-app notifications ────────────────────────────────────────────────────

class NoticesNotifier extends Notifier<List<AppNotice>> {
  @override
  List<AppNotice> build() => ref.read(localStoreProvider).notices;

  void _set(List<AppNotice> n) {
    state = n;
    ref.read(localStoreProvider).saveNotices(n);
  }

  void add(AppNotice n) => _set([n, ...state]);

  void markAllRead() {
    _set([for (final n in state) n.markRead()]);
    _sync(ref, 'POST', '/v1/notices/read-all', key: 'notices.read-all');
  }

  void markRead(String id) {
    _set([for (final n in state) n.id == id ? n.markRead() : n]);
    _sync(
      ref,
      'POST',
      '/v1/notices/${Uri.encodeComponent(id)}/read',
      key: 'notice.read.$id',
    );
  }

  void dismiss(String id) {
    _set(state.where((n) => n.id != id).toList());
    _sync(
      ref,
      'DELETE',
      '/v1/notices/${Uri.encodeComponent(id)}',
      key: 'notice.del.$id',
    );
  }

  Future<void> welcome() async {
    final now = DateTime.now();
    _set([
      AppNotice(
        id: 'welcome',
        kind: NoticeKind.welcome,
        title: 'Welcome to NutriLens',
        body: 'Snap your first meal — we’ll count calories and macros for you.',
        createdAt: now,
      ),
      AppNotice(
        id: 'tip-light',
        kind: NoticeKind.tip,
        title: 'Tip: better photos, better numbers',
        body: 'Shoot from above in good light and fit the whole plate in the frame.',
        createdAt: now.subtract(const Duration(minutes: 1)),
      ),
    ]);
  }
}

final noticesProvider = NotifierProvider<NoticesNotifier, List<AppNotice>>(
  NoticesNotifier.new,
);

final unreadNoticesProvider = Provider<int>(
  (ref) => ref.watch(noticesProvider).where((n) => !n.read).length,
);

// ── Scan draft (the meal being reviewed before logging) ─────────────────────

class ScanDraftNotifier extends Notifier<Meal?> {
  @override
  Meal? build() => null;

  void set(Meal meal) => state = meal;

  void updateItem(String itemId, double servings) {
    final m = state;
    if (m == null) return;
    state = m.copyWith(
      items: [
        for (final i in m.items)
          i.id == itemId ? i.copyWith(servings: servings) : i,
      ],
    );
  }

  void removeItem(String itemId) {
    final m = state;
    if (m == null) return;
    state = m.copyWith(items: m.items.where((i) => i.id != itemId).toList());
  }

  void addItem(FoodItem item) {
    final m = state;
    if (m == null) return;
    state = m.copyWith(items: [...m.items, item]);
  }

  void setType(MealType type) {
    final m = state;
    if (m == null) return;
    state = m.copyWith(type: type);
  }

  void clear() => state = null;
}

final scanDraftProvider = NotifierProvider<ScanDraftNotifier, Meal?>(
  ScanDraftNotifier.new,
);
