import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../state/providers.dart';

/// Brief branded moment on cold start, then the router decides where the
/// user belongs (welcome, setup, onboarding or Today).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      context.go(
        ref.read(accountProvider) == null ? Routes.welcome : Routes.today,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: reduce ? 1 : 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Motion.emphasized,
          builder: (_, t, child) => Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LogoMark(size: 72),
              const SizedBox(height: Space.lg),
              Text(
                'NutriLens',
                style: context.text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: Space.xs),
              Text(
                'Snap your plate. Know your food.',
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
