import 'auth_repository.dart';

/// Used until a Firebase project is connected. Behaves like the real thing
/// (delays, wrong-code errors, resend) so every screen state can be tested.
/// The code is always [code].
class DemoAuthRepository implements AuthRepository {
  static const code = '123456';

  AuthUser? _user;

  @override
  bool get isDemo => true;

  @override
  AuthUser? get currentUser => _user;

  @override
  Future<SendCodeResult> sendCode(String phoneE164, {int? resendToken}) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return CodeSent(
      OtpSession(
        phone: phoneE164,
        verificationId: 'demo-${DateTime.now().millisecondsSinceEpoch}',
        resendToken: (resendToken ?? 0) + 1,
      ),
    );
  }

  @override
  Future<AuthUser> verifyCode(OtpSession session, String smsCode) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (smsCode != code) throw const InvalidCodeFailure();
    final digits = session.phone.replaceAll(RegExp(r'\D'), '');
    return _user = AuthUser(uid: 'demo-$digits', phone: session.phone);
  }

  @override
  Future<void> updateDisplayName(String name) async {
    final u = _user;
    if (u != null) {
      _user = AuthUser(uid: u.uid, phone: u.phone, displayName: name);
    }
  }

  @override
  Future<void> signOut() async => _user = null;

  @override
  Future<void> deleteAccount() async => _user = null;
}
