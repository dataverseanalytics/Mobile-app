import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/assets.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/food_photo.dart';
import '../../core/widgets/macro_widgets.dart';
import '../../core/widgets/scan_frame.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, c) {
            final photoH = c.maxHeight * 0.6;
            return Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: photoH + Radii.xl,
                  child: const _HeroPhoto(),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  top: photoH,
                  child: const _BottomPanel(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeroPhoto extends StatelessWidget {
  const _HeroPhoto();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Stack(
      fit: StackFit.expand,
      children: [
        FoodPhoto(
          Photos.tofuPokeBowl,
          width: w,
          semanticLabel: 'A tofu poke bowl being scanned',
        ),
        // Top scrim for status bar + logo legibility.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [
                Colors.black.withValues(alpha: 0.55),
                Colors.transparent,
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Space.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Wordmark(color: Colors.white, size: 30),
                Expanded(
                  child: Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.72,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ScanFrame(color: context.brand.accent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Space.huge),
              ],
            ),
          ),
        ),
        const Positioned(
          left: Space.gutter,
          right: Space.gutter,
          bottom: Radii.xl + Space.lg,
          child: _FloatingResult(),
        ),
      ],
    );
  }
}

/// The product in one glance: a result card floating over the photo.
class _FloatingResult extends StatelessWidget {
  const _FloatingResult();

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Motion.enter,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - t)),
          child: child,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.brand.card,
          borderRadius: Radii.xlAll,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: context.brand.accent,
                  borderRadius: Radii.mdAll,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: context.brand.onAccent,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tofu poke bowl',
                      style: context.text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: Space.xs),
                    const Wrap(
                      spacing: Space.md,
                      children: [
                        MacroDot(kind: MacroKind.protein, grams: 37),
                        MacroDot(kind: MacroKind.carbs, grams: 30),
                        MacroDot(kind: MacroKind.fat, grams: 21),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('454', style: context.text.titleLarge),
                  Text(
                    'kcal',
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel();

  @override
  Widget build(BuildContext context) {
    final display = context.text.displayMedium;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.xl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.xxl,
            Space.gutter,
            Space.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'Snap your plate.\n'),
                              TextSpan(
                                text: 'Know your food.',
                                style: display?.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          style: display,
                        ),
                      ),
                      const SizedBox(height: Space.md),
                      Text(
                        'Calories and macros from a single photo — '
                        'in about three seconds. No typing, no guesswork.',
                        style: context.text.bodyLarge?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Space.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.push(Routes.phone),
                  child: const Text('Get started'),
                ),
              ),
              const SizedBox(height: Space.xs),
              Center(
                child: TextButton(
                  onPressed: () => context.push(Routes.phone),
                  child: Text.rich(
                    TextSpan(
                      text: 'Already have an account? ',
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                      children: [
                        TextSpan(
                          text: 'Sign in',
                          style: context.text.labelLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
