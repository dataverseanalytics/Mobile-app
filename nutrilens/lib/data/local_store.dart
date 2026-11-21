import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'account.dart';
import 'models.dart';
import 'serialization.dart';

/// On-device persistence. Everything a signed-in user creates survives an
/// app restart. Swap for a synced backend (Firestore/Supabase) later
/// without touching the UI — notifiers only call these methods.
class LocalStore {
  LocalStore(this._prefs);
  final SharedPreferences _prefs;

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  // Keys that belong to the signed-in user (wiped on sign-out).
  static const _account = 'account';
  static const _profile = 'profile';
  static const _diary = 'diary';
  static const _premium = 'premium';
  static const _premiumUntil = 'premiumUntil';
  static const _freeScans = 'freeScans';
  static const _customTargets = 'customTargets';
  static const _reminders = 'reminders';
  static const _weights = 'weights';
  static const _notices = 'notices';
  static const _outbox = 'outbox';
  static const _userKeys = [
    _account,
    _profile,
    _diary,
    _premium,
    _premiumUntil,
    _freeScans,
    _customTargets,
    _reminders,
    _weights,
    _notices,
    _outbox,
  ];

  // Device preference (kept across accounts).
  static const _theme = 'theme';

  /// Typed read that never throws: a value of the wrong type (corrupt or
  /// written by an older version) is treated as missing.
  T? _get<T>(String key) {
    try {
      final v = _prefs.get(key);
      return v is T ? v : null;
    } on Object {
      return null;
    }
  }

  Object? _read(String key) {
    final raw = _get<String>(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  Future<void> _write(String key, Object? value) =>
      _prefs.setString(key, jsonEncode(value));

  T? _safe<T>(T Function() parse) {
    try {
      return parse();
    } on Object {
      return null; // Corrupt or outdated data: fall back to defaults.
    }
  }

  Account? get account {
    final j = _read(_account);
    return j == null
        ? null
        : _safe(() => Account.fromJson(j as Map<String, Object?>));
  }

  Future<void> saveAccount(Account a) => _write(_account, a.toJson());

  UserProfile? get profile {
    final j = _read(_profile);
    return j == null ? null : _safe(() => Json.toProfile(j));
  }

  Future<void> saveProfile(UserProfile p) => _write(_profile, Json.profile(p));

  List<Meal> get meals {
    final j = _read(_diary);
    if (j is! List<Object?>) return const [];
    return _safe(() => [for (final m in j) Json.toMeal(m)]) ?? const [];
  }

  Future<void> saveMeals(List<Meal> meals) =>
      _write(_diary, [for (final m in meals) Json.meal(m)]);

  bool get premium => _get<bool>(_premium) ?? false;

  DateTime? get premiumUntil {
    final v = _get<String>(_premiumUntil);
    return v == null ? null : DateTime.tryParse(v)?.toLocal();
  }

  Future<void> savePremiumUntil(DateTime? until) => until == null
      ? _prefs.remove(_premiumUntil)
      : _prefs.setString(_premiumUntil, until.toUtc().toIso8601String());
  Future<void> savePremium(bool v) => _prefs.setBool(_premium, v);

  int? get freeScans => _get<int>(_freeScans);
  Future<void> saveFreeScans(int v) => _prefs.setInt(_freeScans, v);

  DailyTargets? get customTargets {
    final j = _read(_customTargets);
    return j == null ? null : _safe(() => Json.toTargets(j));
  }

  Future<void> saveCustomTargets(DailyTargets? t) => t == null
      ? _prefs.remove(_customTargets)
      : _write(_customTargets, Json.targets(t));

  List<Reminder>? get reminders {
    final j = _read(_reminders);
    if (j is! List<Object?>) return null;
    return _safe(
      () => [for (final r in j) Reminder.fromJson(r as Map<String, Object?>)],
    );
  }

  Future<void> saveReminders(List<Reminder> r) =>
      _write(_reminders, [for (final x in r) x.toJson()]);

  List<double>? get weights {
    final j = _read(_weights);
    if (j is! List<Object?>) return null;
    return _safe(() => [for (final w in j) (w as num).toDouble()]);
  }

  Future<void> saveWeights(List<double> w) => _write(_weights, w);

  List<AppNotice> get notices {
    final j = _read(_notices);
    if (j is! List<Object?>) return const [];
    return _safe(
          () => [
            for (final n in j) AppNotice.fromJson(n as Map<String, Object?>),
          ],
        ) ??
        const [];
  }

  Future<void> saveNotices(List<AppNotice> n) =>
      _write(_notices, [for (final x in n) x.toJson()]);

  // Raw JSON writes for server payloads: the API uses the same JSON shapes
  // as this store, so data from `/v1/me/bootstrap` is cached as-is.
  Future<void> saveProfileJson(Map<String, Object?> j) => _write(_profile, j);
  Future<void> saveCustomTargetsJson(Map<String, Object?>? j) =>
      j == null ? _prefs.remove(_customTargets) : _write(_customTargets, j);
  Future<void> saveRemindersJson(List<Object?> j) => _write(_reminders, j);
  Future<void> saveMealsJson(List<Object?> j) => _write(_diary, j);
  Future<void> saveNoticesJson(List<Object?> j) => _write(_notices, j);

  /// Pending server writes (offline queue), oldest first.
  List<Map<String, Object?>> get outbox {
    final j = _read(_outbox);
    if (j is! List<Object?>) return const [];
    return [
      for (final o in j)
        if (o is Map<String, Object?>) o,
    ];
  }

  Future<void> saveOutbox(List<Map<String, Object?>> ops) =>
      _write(_outbox, ops);

  Future<void> savePremiumAndScans({
    required bool premium,
    required int? freeScans,
  }) async {
    await savePremium(premium);
    if (freeScans != null) await saveFreeScans(freeScans);
  }

  String? get theme => _get<String>(_theme);
  Future<void> saveTheme(String v) => _prefs.setString(_theme, v);

  /// Sign-out / account deletion: remove everything tied to the user.
  Future<void> clearUser() async {
    for (final k in _userKeys) {
      await _prefs.remove(k);
    }
  }
}
