import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/food_photo.dart';
import '../../core/widgets/scan_frame.dart';
import '../../data/scan_repository.dart';
import '../../state/providers.dart';

/// The 3-second wait, made to feel fast: a sweeping scan line and
/// step-by-step progress so the user sees work happening.
class AnalyzingScreen extends ConsumerStatefulWidget {
  const AnalyzingScreen({super.key, required this.photo});
  final String photo;

  @override
  ConsumerState<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends ConsumerState<AnalyzingScreen>
    with SingleTickerProviderStateMixin {
  static const _steps = [
    'Identifying foods',
    'Estimating portion sizes',
    'Calculating nutrition',
  ];

  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  Timer? _stepTimer;
  int _step = 0;
  ScanFailure? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep.stop();
    } else if (!_sweep.isAnimating && _error == null) {
      _sweep.repeat(reverse: true);
    }
  }

  Future<void> _retry() async {
    setState(() {
      _error = null;
      _step = 0;
    });
    if (!MediaQuery.disableAnimationsOf(context)) {
      unawaited(_sweep.repeat(reverse: true));
    }
    await _run();
  }

  Future<void> _run() async {
    _stepTimer?.cancel();
    _stepTimer = Timer.periodic(const Duration(milliseconds: 1050), (t) {
      if (!mounted) return t.cancel();
      if (_step < _steps.length - 1) setState(() => _step++);
    });
    try {
      final result = await ref
          .read(scanRepositoryProvider)
          .analyzePhoto(widget.photo);
      if (!mounted) return;
      if (result.fromServer) {
        // The server is the source of truth for scan allowance.
        final left = result.scansLeft;
        if (left == null) {
          ref.read(premiumProvider.notifier).set(true);
        } else {
          ref.read(freeScansProvider.notifier).set(left);
        }
      } else if (!ref.read(premiumProvider)) {
        ref.read(freeScansProvider.notifier).consume();
      }
      ref.read(scanDraftProvider.notifier).set(result.meal);
      unawaited(HapticFeedback.mediumImpact());
      if (mounted) context.pushReplacement(Routes.result);
    } on ScanNeedsPro {
      if (!mounted) return;
      ref.read(freeScansProvider.notifier).set(0);
      context.pushReplacement(Routes.paywall);
    } on ScanFailure catch (e) {
      if (!mounted) return;
      _sweep.stop();
      setState(() => _error = e);
    } finally {
      _stepTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final frame = size.width - Space.huge * 2;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            FoodPhoto(
              widget.photo,
              width: size.width,
              semanticLabel: 'Your meal photo',
            ),
            ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
            Positioned(
              left: Space.huge,
              top: size.height * 0.38 - frame / 2,
              width: frame,
              height: frame,
              child: ScanFrame(
                color: _error == null
                    ? context.brand.accent
                    : context.colors.error,
                child: _error == null
                    ? AnimatedBuilder(
                        animation: _sweep,
                        builder: (_, _) => Align(
                          alignment: Alignment(0, _sweep.value * 2 - 1),
                          child: const _ScanLine(),
                        ),
                      )
                    : null,
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(Space.md),
                      child: GlassIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Cancel',
                        onPressed: () => context.pop(),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(Space.md),
                    child: AnimatedSwitcher(
                      duration: Motion.base,
                      child: _error == null
                          ? _ProgressPanel(steps: _steps, current: _step)
                          : _ErrorPanel(
                              failure: _error!,
                              onRetry: _retry,
                              onSearch: () =>
                                  context.pushReplacement(Routes.search),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanLine extends StatelessWidget {
  const _ScanLine();

  @override
  Widget build(BuildContext context) {
    final lime = context.brand.accent;
    return Container(
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: Space.md),
      decoration: BoxDecoration(
        color: lime,
        borderRadius: Radii.pillAll,
        boxShadow: [
          BoxShadow(
            color: lime.withValues(alpha: 0.7),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.steps, required this.current});
  final List<String> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const ValueKey('progress'),
      child: Semantics(
        liveRegion: true,
        label: '${steps[current]}…',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: context.colors.onSurface,
                  size: 20,
                ),
                const SizedBox(width: Space.sm),
                Text('Analysing your meal', style: context.text.titleMedium),
              ],
            ),
            const SizedBox(height: Space.lg),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.xs + 1),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 20,
                      child: i < current
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: context.brand.success,
                              size: 20,
                            )
                          : i == current
                          ? CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: context.colors.onSurface,
                            )
                          : Icon(
                              Icons.radio_button_unchecked_rounded,
                              color: context.colors.outline,
                              size: 20,
                            ),
                    ),
                    const SizedBox(width: Space.md),
                    Text(
                      steps[i],
                      style: context.text.bodyMedium?.copyWith(
                        color: i <= current
                            ? context.colors.onSurface
                            : context.colors.onSurfaceVariant,
                        fontWeight: i == current ? FontWeight.w600 : null,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: Space.md),
            ClipRRect(
              borderRadius: Radii.pillAll,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: (current + 1) / steps.length),
                duration: const Duration(milliseconds: 900),
                curve: Motion.enter,
                builder: (_, v, _) =>
                    LinearProgressIndicator(value: v, minHeight: 6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.failure,
    required this.onRetry,
    required this.onSearch,
  });
  final ScanFailure failure;
  final VoidCallback onRetry;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const ValueKey('error'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, color: context.colors.error),
              const SizedBox(width: Space.sm),
              Text("Couldn't read this plate", style: context.text.titleMedium),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(
            failure.message,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Space.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onSearch,
                  child: const Text('Search instead'),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: FilledButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
