import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'auth_repository.dart';

/// Real SMS OTP via Firebase Authentication — works in 200+ countries.
///
/// Mobile uses `verifyPhoneNumber` (with Android SMS auto-retrieval and
/// resend tokens). Web uses `signInWithPhoneNumber` with an invisible
/// reCAPTCHA, which Firebase requires in browsers.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository([FirebaseAuth? auth])
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  ConfirmationResult? _webConfirmation;

  @override
  bool get isDemo => false;

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  AuthUser? _map(User? u) => u == null
      ? null
      : AuthUser(
          uid: u.uid,
          phone: u.phoneNumber ?? '',
          displayName: u.displayName,
        );

  @override
  Future<SendCodeResult> sendCode(String phoneE164, {int? resendToken}) async {
    if (kIsWeb) {
      try {
        _webConfirmation = await _auth.signInWithPhoneNumber(phoneE164);
        return CodeSent(
          OtpSession(
            phone: phoneE164,
            verificationId: _webConfirmation!.verificationId,
          ),
        );
      } on FirebaseAuthException catch (e) {
        throw _failure(e);
      }
    }

    final result = Completer<SendCodeResult>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        // Android instant verification / SMS auto-retrieval.
        try {
          final cred = await _auth.signInWithCredential(credential);
          final user = _map(cred.user);
          if (user != null && !result.isCompleted) {
            result.complete(AutoVerified(user));
          }
        } on FirebaseAuthException catch (e) {
          if (!result.isCompleted) result.completeError(_failure(e));
        }
      },
      verificationFailed: (e) {
        if (!result.isCompleted) result.completeError(_failure(e));
      },
      codeSent: (verificationId, token) {
        if (!result.isCompleted) {
          result.complete(
            CodeSent(
              OtpSession(
                phone: phoneE164,
                verificationId: verificationId,
                resendToken: token,
              ),
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return result.future;
  }

  @override
  Future<AuthUser> verifyCode(OtpSession session, String code) async {
    try {
      final UserCredential cred;
      if (kIsWeb && _webConfirmation != null) {
        cred = await _webConfirmation!.confirm(code);
      } else {
        cred = await _auth.signInWithCredential(
          PhoneAuthProvider.credential(
            verificationId: session.verificationId,
            smsCode: code,
          ),
        );
      }
      final user = _map(cred.user);
      if (user == null) throw const UnknownAuthFailure();
      return user;
    } on FirebaseAuthException catch (e) {
      throw _failure(e);
    }
  }

  @override
  Future<void> updateDisplayName(String name) async =>
      _auth.currentUser?.updateDisplayName(name);

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      // Deleting needs a recent sign-in; signing out still removes local data.
      if (e.code != 'requires-recent-login') throw _failure(e);
      await _auth.signOut();
    }
  }

  AuthFailure _failure(FirebaseAuthException e) => switch (e.code) {
    'invalid-phone-number' ||
    'missing-phone-number' => const InvalidPhoneFailure(),
    'invalid-verification-code' ||
    'missing-verification-code' => const InvalidCodeFailure(),
    'session-expired' || 'code-expired' => const CodeExpiredFailure(),
    'too-many-requests' || 'quota-exceeded' => const TooManyRequestsFailure(),
    'network-request-failed' => const NetworkFailure(),
    _ => UnknownAuthFailure(e.message ?? 'Sign-in failed. Please try again.'),
  };
}
