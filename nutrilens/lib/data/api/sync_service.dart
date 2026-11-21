import 'dart:async';

import 'package:flutter/foundation.dart';

import '../account.dart';
import '../local_store.dart';
import 'api_client.dart';

/// Offline-first sync with the backend.
///
/// * Writes go to the device first (instant UI), then into a persisted
///   outbox that's sent to the server in order. Nothing is lost when the
///   app is offline or closed.
/// * Ops with the same `key` replace each other, so dragging a slider
///   sends one `PATCH`, not fifty.
/// * [pull] downloads the user's server state into the device store.
class SyncService {
  SyncService(
    this._api,
    this._store, {
    this.debounce = const Duration(milliseconds: 600),
  });

  final ApiClient _api;
  final LocalStore _store;
  final Duration debounce;
  Timer? _timer;
  Future<void>? _flushing;

  int get pending => _store.outbox.length;

  /// Queue a write. [key] coalesces repeated updates to the same thing.
  Future<void> enqueue(
    String method,
    String path, {
    Object? body,
    String? key,
  }) async {
    final ops = [..._store.outbox];
    if (key != null) ops.removeWhere((o) => o['key'] == key);
    ops.add({'method': method, 'path': path, 'body': body, 'key': key});
    await _store.saveOutbox(ops);
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(flush()));
  }

  /// Send queued writes. Safe to call any time; runs one flush at a time.
  Future<void> flush() =>
      _flushing ??= _flush().whenComplete(() => _flushing = null);

  Future<void> _flush() async {
    while (true) {
      final ops = _store.outbox;
      if (ops.isEmpty) return;
      final op = ops.first;
      try {
        await _send(op);
      } on SessionExpired {
        return; // Stop; the app will route to sign-in.
      } on ApiException catch (e) {
        // Offline/server issue: retry later and keep the order.
        if (e.isTransient) return;
        // Permanent rejection (validation, not found): drop it so the queue moves.
        debugPrint(
          'Dropping rejected sync op ${op['method']} ${op['path']}: ${e.message}',
        );
      }
      // Remove exactly the op we sent (another may have been queued meanwhile).
      final rest = [..._store.outbox];
      final i = rest.indexWhere(
        (o) =>
            o['path'] == op['path'] &&
            o['method'] == op['method'] &&
            o['key'] == op['key'],
      );
      if (i >= 0) rest.removeAt(i);
      await _store.saveOutbox(rest);
    }
  }

  Future<void> _send(Map<String, Object?> op) {
    final path = op['path']! as String;
    final body = op['body'];
    return switch (op['method']) {
      'PUT' => _api.put(path, body),
      'PATCH' => _api.patch(path, body),
      'DELETE' => _api.delete(path),
      _ => _api.post(path, body),
    };
  }

  /// Push pending writes, then replace device data with the server's.
  /// Returns the server's account fields for [AccountNotifier].
  Future<Account> pull(Account local) async {
    await flush();
    if (pending > 0) {
      // Still offline: keep local data rather than overwrite unsynced edits.
      throw const ApiException(
        0,
        'Offline — showing data saved on this device.',
      );
    }
    final json = (await _api.get('/v1/me/bootstrap')).asMap;
    final user = json['user'].asMap;

    final profile = user['profile'];
    if (profile is Map<String, Object?>) {
      await _store.saveProfileJson(profile);
    }
    final targets = user['customTargets'];
    await _store.saveCustomTargetsJson(
      targets is Map<String, Object?> ? targets : null,
    );
    final reminders = user['reminders'];
    if (reminders is List<Object?>) await _store.saveRemindersJson(reminders);

    await _store.saveMealsJson(json['meals'].asList);
    final weights = [
      for (final w in json['weights'].asList)
        if (w is Map<String, Object?> && w['kg'] is num)
          (w['kg']! as num).toDouble(),
    ];
    if (weights.isNotEmpty) await _store.saveWeights(weights);
    await _store.saveNoticesJson(json['notices'].asList);
    final premium = user['isPremium'] == true;
    final scans = user['freeScansLeft'];
    final until = user['premiumUntil'];
    await _store.savePremiumUntil(
      until is String ? DateTime.tryParse(until) : null,
    );
    await _store.savePremiumAndScans(
      premium: premium,
      freeScans: scans is int ? scans : null,
    );

    final account = local.copyWith(
      name: user['name'] as String? ?? local.name,
      email: user['email'] as String? ?? local.email,
      onboarded: user['onboarded'] == true || local.onboarded,
    );
    await _store.saveAccount(account);
    return account;
  }

  Future<void> clear() async {
    _timer?.cancel();
    await _store.saveOutbox(const []);
  }
}
