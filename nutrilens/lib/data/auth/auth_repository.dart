import 'package:flutter/foundation.dart';

@immutable
class AuthUser {
  const AuthUser({required this.uid, required this.phone, this.displayName});
  final String uid;
  final String phone;
  final String? displayName;
}

/// Result of asking for a code.
sealed class SendCodeResult {
  const SendCodeResult();
}

/// An SMS is on its way; verify with [OtpSession].
final class CodeSent extends SendCodeResult {
  const CodeSent(this.session);
  final OtpSession session;
}

/// Android read the SMS automatically — already signed in.
final class AutoVerified extends SendCodeResult {
  const AutoVerified(this.user);
  final AuthUser user;
}

@immutable
class OtpSession {
  const OtpSession({
    required this.phone,
    required this.verificationId,
    this.resendToken,
    this.devCode,
  });

  /// E.164 number the code was sent to.
  final String phone;
  final String verificationId;
  final int? resendToken;

  /// Only from a development backend (console SMS) — shown on screen.
  final String? devCode;
}

sealed class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

final class InvalidPhoneFailure extends AuthFailure {
  const InvalidPhoneFailure()
    : super(
        "That number doesn't look right. Check the country code and digits.",
      );
}

final class InvalidCodeFailure extends AuthFailure {
  const InvalidCodeFailure()
    : super("That code isn't right. Check the SMS and try again.");
}

final class CodeExpiredFailure extends AuthFailure {
  const CodeExpiredFailure()
    : super('This code has expired. Tap “Resend code” for a new one.');
}

final class TooManyRequestsFailure extends AuthFailure {
  const TooManyRequestsFailure()
    : super('Too many attempts. Please wait a few minutes and try again.');
}

final class NetworkFailure extends AuthFailure {
  const NetworkFailure()
    : super("You're offline. Check your connection and try again.");
}

final class UnknownAuthFailure extends AuthFailure {
  const UnknownAuthFailure([
    super.message = 'Something went wrong. Please try again.',
  ]);
}

/// Phone-number OTP sign-in. One flow for new and returning users.
abstract interface class AuthRepository {
  /// True when SMS is simulated (no Firebase project configured yet).
  bool get isDemo;

  AuthUser? get currentUser;

  Future<SendCodeResult> sendCode(String phoneE164, {int? resendToken});

  Future<AuthUser> verifyCode(OtpSession session, String code);

  Future<void> updateDisplayName(String name);

  Future<void> signOut();

  Future<void> deleteAccount();
}
