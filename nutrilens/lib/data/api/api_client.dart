import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Backend URL, set at build time:
///   flutter run --dart-define=API_URL=http://10.0.2.2:8001
/// Empty → the app runs fully on-device (demo mode).
const apiUrl = String.fromEnvironment('API_URL');

class ApiException implements Exception {
  const ApiException(this.status, this.message);

  /// HTTP status, or 0 for network failures.
  final int status;
  final String message;

  bool get isNetwork => status == 0;

  /// Worth retrying later (offline, timeout, server hiccup, rate limit).
  bool get isTransient =>
      status == 0 || status == 408 || status == 429 || status >= 500;

  @override
  String toString() => 'ApiException($status): $message';
}

/// The session expired and couldn't be refreshed — sign in again.
class SessionExpired extends ApiException {
  const SessionExpired()
    : super(401, 'Your session expired. Please sign in again.');
}

/// Where access/refresh tokens live.
abstract interface class TokenStore {
  Future<({String? access, String? refresh})> read();
  Future<void> save({required String access, required String refresh});
  Future<void> clear();
}

/// Keychain (iOS) / Keystore-backed storage (Android).
class SecureTokenStore implements TokenStore {
  static const _storage = FlutterSecureStorage();

  @override
  Future<({String? access, String? refresh})> read() async => (
    access: await _storage.read(key: 'access_token'),
    refresh: await _storage.read(key: 'refresh_token'),
  );

  @override
  Future<void> save({required String access, required String refresh}) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }
}

/// In-memory store for tests.
class MemoryTokenStore implements TokenStore {
  String? access;
  String? refresh;

  @override
  Future<({String? access, String? refresh})> read() async =>
      (access: access, refresh: refresh);

  @override
  Future<void> save({required String access, required String refresh}) async {
    this.access = access;
    this.refresh = refresh;
  }

  @override
  Future<void> clear() async => access = refresh = null;
}

/// Thin JSON client for the NutriLens API.
///
/// Adds the bearer token, refreshes it once on 401 (concurrent requests
/// share one refresh), maps errors to [ApiException] with the server's
/// human-readable message.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.tokens,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 20),
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final TokenStore tokens;
  final Duration timeout;
  final http.Client _http;
  Future<bool>? _refreshing;

  /// Called when the session can't be recovered (refresh token rejected).
  VoidCallback? onSessionExpired;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<Object?> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);
  Future<Object?> post(String path, [Object? body]) =>
      _send('POST', path, body: body);
  Future<Object?> put(String path, Object? body) =>
      _send('PUT', path, body: body);
  Future<Object?> patch(String path, Object? body) =>
      _send('PATCH', path, body: body);
  Future<Object?> delete(String path) => _send('DELETE', path);

  /// Unauthenticated JSON call (sign-in endpoints).
  Future<Object?> postPublic(String path, Object? body) =>
      _send('POST', path, body: body, auth: false);

  Future<Object?> uploadImage(
    String path, {
    required String field,
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    Future<http.BaseRequest> build() async {
      final req = http.MultipartRequest('POST', _uri(path))
        ..files.add(
          http.MultipartFile.fromBytes(
            field,
            bytes,
            filename: filename,
            contentType: http.MediaType.parse(contentType),
          ),
        );
      final access = (await tokens.read()).access;
      if (access != null) req.headers['authorization'] = 'Bearer $access';
      return req;
    }

    return _execute(build, auth: true);
  }

  Future<Object?> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool auth = true,
  }) {
    Future<http.BaseRequest> build() async {
      final req = http.Request(method, _uri(path, query))
        ..headers['accept'] = 'application/json';
      if (body != null) {
        req.headers['content-type'] = 'application/json';
        req.body = jsonEncode(body);
      }
      if (auth) {
        final access = (await tokens.read()).access;
        if (access != null) req.headers['authorization'] = 'Bearer $access';
      }
      return req;
    }

    return _execute(build, auth: auth);
  }

  Future<Object?> _execute(
    Future<http.BaseRequest> Function() build, {
    required bool auth,
  }) async {
    var res = await _roundTrip(await build());
    if (res.statusCode == 401 && auth) {
      if (await _refresh()) {
        res = await _roundTrip(await build());
      }
      if (res.statusCode == 401) {
        await tokens.clear();
        onSessionExpired?.call();
        throw const SessionExpired();
      }
    }
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, _message(res));
    }
    if (res.statusCode == 204 || res.body.isEmpty) return null;
    try {
      return jsonDecode(res.body);
    } on FormatException {
      throw ApiException(
        res.statusCode,
        'Unexpected response from the server.',
      );
    }
  }

  Future<http.Response> _roundTrip(http.BaseRequest req) async {
    try {
      final streamed = await _http.send(req).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        0,
        'The server took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw const ApiException(
        0,
        "You're offline. Check your connection and try again.",
      );
    } on Exception catch (e) {
      // SocketException etc. (not referenced directly so web builds compile).
      debugPrint('Network error: $e');
      throw const ApiException(
        0,
        "You're offline. Check your connection and try again.",
      );
    }
  }

  /// One refresh at a time; concurrent 401s wait for the same result.
  Future<bool> _refresh() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<bool> _doRefresh() async {
    final refresh = (await tokens.read()).refresh;
    if (refresh == null) return false;
    try {
      final res = await _roundTrip(
        http.Request('POST', _uri('/v1/auth/refresh'))
          ..headers['content-type'] = 'application/json'
          ..body = jsonEncode({'refreshToken': refresh}),
      );
      if (res.statusCode != 200) return false;
      final json = jsonDecode(res.body);
      if (json is! Map<String, Object?>) return false;
      final access = json['accessToken'];
      final newRefresh = json['refreshToken'];
      if (access is! String || newRefresh is! String) return false;
      await tokens.save(access: access, refresh: newRefresh);
      return true;
    } on ApiException {
      return false;
    }
  }

  String _message(http.Response res) {
    try {
      final json = jsonDecode(res.body);
      if (json is Map<String, Object?>) {
        final d = json['detail'];
        if (d is String) return d;
        if (d is List && d.isNotEmpty) {
          final first = d.first;
          if (first is Map<String, Object?> && first['msg'] is String) {
            return first['msg']! as String;
          }
        }
      }
    } on FormatException {
      // Fall through.
    }
    return res.statusCode >= 500
        ? 'Something went wrong on our side. Please try again.'
        : 'Request failed (${res.statusCode}).';
  }
}

/// Small typed accessors for decoded JSON.
extension JsonMap on Object? {
  Map<String, Object?> get asMap {
    final v = this;
    if (v is Map<String, Object?>) return v;
    throw const ApiException(200, 'Unexpected response from the server.');
  }

  List<Object?> get asList {
    final v = this;
    if (v is List<Object?>) return v;
    throw const ApiException(200, 'Unexpected response from the server.');
  }
}
