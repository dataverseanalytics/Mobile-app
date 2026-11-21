import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'data/api/api_client.dart';
import 'data/auth/api_auth_repository.dart';
import 'data/auth/auth_repository.dart';
import 'data/auth/demo_auth_repository.dart';
import 'data/auth/firebase_auth_repository.dart';
import 'data/local_store.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final store = await LocalStore.open();
  final api = apiUrl.isEmpty
      ? null
      : ApiClient(baseUrl: apiUrl, tokens: SecureTokenStore());
  final auth = api != null ? ApiAuthRepository(api) : await _localAuth();

  final container = ProviderContainer(
    overrides: [
      localStoreProvider.overrideWithValue(store),
      authRepositoryProvider.overrideWithValue(auth),
      apiClientProvider.overrideWithValue(api),
    ],
  );

  // A rejected refresh token means the session is over: sign out locally.
  api?.onSessionExpired = () =>
      unawaited(container.read(accountProvider.notifier).signOut());

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const NutriLensApp(),
    ),
  );

  // Bring the device up to date with the server without blocking start-up.
  if (api != null && store.account != null) {
    unawaited(container.read(accountProvider.notifier).refreshFromServer());
  }
}

/// No backend configured: real Firebase phone auth if the project is set
/// up (google-services.json / GoogleService-Info.plist), otherwise a
/// clearly-labelled on-device demo.
Future<AuthRepository> _localAuth() async {
  try {
    await Firebase.initializeApp();
    return FirebaseAuthRepository();
  } on Object catch (e) {
    debugPrint('No backend or Firebase configured — demo OTP (123456). $e');
    return DemoAuthRepository();
  }
}
