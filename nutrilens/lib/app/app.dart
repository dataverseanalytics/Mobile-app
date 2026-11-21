import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../state/providers.dart';
import 'router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects whenever the session changes (sign in/out, setup).
  final refresh = ValueNotifier<int>(0);
  ref.listen(accountProvider, (_, _) => refresh.value++);
  final router = buildRouter(
    account: () => ref.read(accountProvider),
    refresh: refresh,
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class NutriLensApp extends ConsumerWidget {
  const NutriLensApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'NutriLens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
