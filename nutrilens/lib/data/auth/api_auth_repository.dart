import '../api/api_client.dart';
import 'auth_repository.dart';

/// Phone OTP through the NutriLens backend (`/v1/auth/*`).
/// The server sends the SMS (Twilio in production) and issues our own
/// access/refresh tokens, stored securely by [ApiClient.tokens].
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api);

  final ApiClient _api;
  AuthUser? _user;

  @override
  bool get isDemo => false;

  @override
  AuthUser? get currentUser => _user;

  AuthFailure _failure(ApiException e) => switch (e.status) {
    0 => const NetworkFailure(),
    429 => UnknownAuthFailure(e.message), // "Please wait 20s…" is specific
    _ => UnknownAuthFailure(e.message),
  };

  @override
  Future<SendCodeResult> sendCode(String phoneE164, {int? resendToken}) async {
    try {
      final json = (await _api.postPublic('/v1/auth/otp/request', {
        'phone': phoneE164,
      })).asMap;
      final phone = json['phone'] as String? ?? phoneE164;
      return CodeSent(
        OtpSession(
          phone: phone,
          verificationId: phone,
          devCode: json['devCode'] as String?,
        ),
      );
    } on ApiException catch (e) {
      throw _failure(e);
    }
  }

  @override
  Future<AuthUser> verifyCode(OtpSession session, String code) async {
    try {
      final json = (await _api.postPublic('/v1/auth/otp/verify', {
        'phone': session.phone,
        'code': code,
      })).asMap;
      final access = json['accessToken'];
      final refresh = json['refreshToken'];
      final user = json['user'].asMap;
      if (access is! String || refresh is! String) {
        throw const UnknownAuthFailure();
      }
      await _api.tokens.save(access: access, refresh: refresh);
      final name = user['name'] as String? ?? '';
      return _user = AuthUser(
        uid: user['id'] as String,
        phone: user['phone'] as String,
        displayName: name.isEmpty ? null : name,
      );
    } on ApiException catch (e) {
      if (e.status == 400 && e.message.contains("isn't right")) {
        throw const InvalidCodeFailure();
      }
      if (e.status == 400 && e.message.contains('expired')) {
        throw const CodeExpiredFailure();
      }
      throw _failure(e);
    }
  }

  /// Name changes sync through `PATCH /v1/me` (see SyncService).
  @override
  Future<void> updateDisplayName(String name) async {}

  @override
  Future<void> signOut() async {
    final refresh = (await _api.tokens.read()).refresh;
    if (refresh != null) {
      try {
        await _api.postPublic('/v1/auth/logout', {'refreshToken': refresh});
      } on ApiException {
        // Offline sign-out still clears the device session.
      }
    }
    await _api.tokens.clear();
    _user = null;
  }

  @override
  Future<void> deleteAccount() async {
    await _api.delete(
      '/v1/me',
    ); // throws if offline — deletion must reach the server
    await _api.tokens.clear();
    _user = null;
  }
}
