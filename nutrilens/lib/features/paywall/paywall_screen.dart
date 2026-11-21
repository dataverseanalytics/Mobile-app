import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/assets.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/food_photo.dart';
import '../../core/widgets/pressable.dart';
import '../../data/payments/payments.dart';
import '../../state/providers.dart';

/// Card copy derived from server prices, so labels never disagree with
/// what Razorpay charges.
({String detail, String? badge}) _copyFor(ProPlan plan, List<ProPlan> all) {
  final monthly = all.where((p) => p.id == 'monthly').firstOrNull;
  if (plan.id == 'yearly') {
    final save = monthly == null
        ? null
        : (100 - plan.amountMinor * 100 / (monthly.amountMinor * 12)).round();
    final perMonth = plan.perMonthLabel;
    return (
      detail: perMonth == null
          ? '365 days of Pro'
          : '$perMonth / month · 365 days of Pro',
      badge: save != null && save > 0 ? 'Save $save%' : null,
    );
  }
  return (detail: '${plan.days} days of Pro', badge: null);
}

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, this.fromOnboarding = false});
  final bool fromOnboarding;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String _planId = 'yearly';
  bool _busy = false;

  void _close() {
    if (widget.fromOnboarding || !context.canPop()) {
      context.go(Routes.today);
    } else {
      context.pop();
    }
  }

  Future<void> _purchase(ProPlan plan) async {
    setState(() => _busy = true);
    try {
      final until = await ref.read(paymentsRepositoryProvider).purchase(plan);
      if (!mounted) return;
      ref.read(premiumProvider.notifier).activateUntil(until);
      unawaited(HapticFeedback.mediumImpact());
      final messenger = ScaffoldMessenger.of(context);
      _close();
      messenger.showSnackBar(
        const SnackBar(content: Text('Welcome to NutriLens Pro — scan away!')),
      );
    } on PurchaseCancelled {
      // Closed the payment sheet: nothing to say.
    } on PurchaseFailed catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // With a backend, prices depend on the customer's country: wait for
    // them rather than flash rupee prices to someone in the US.
    final loaded = ref.watch(proPlansProvider).value;
    final plans =
        loaded ??
        (ref.watch(apiClientProvider) == null ? ProPlan.fallback : null);
    final plan = plans?.firstWhere(
      (p) => p.id == _planId,
      orElse: () => plans.first,
    );
    final size = MediaQuery.sizeOf(context);
    final photoH = (size.height * 0.24).clamp(170.0, 260.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: photoH,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          FoodPhoto(Photos.heroSpread, width: size.width),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0, 0.35, 1],
                                colors: [
                                  Colors.black.withValues(alpha: 0.45),
                                  Colors.transparent,
                                  context.colors.surface,
                                ],
                              ),
                            ),
                          ),
                          SafeArea(
                            child: Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: const EdgeInsets.all(Space.md),
                                child: GlassIconButton(
                                  icon: Icons.close_rounded,
                                  tooltip: 'Close',
                                  onPressed: _close,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.gutter,
                    ),
                    sliver: SliverList.list(
                      children: [
                        Row(
                          children: [
                            const Wordmark(size: 26),
                            const SizedBox(width: Space.sm),
                            Pill(
                              label: 'PRO',
                              background: context.brand.accent,
                              foreground: context.brand.onAccent,
                            ),
                          ],
                        ),
                        const SizedBox(height: Space.lg),
                        Semantics(
                          header: true,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: 'Eat smarter,\n'),
                                TextSpan(
                                  text: 'effortlessly.',
                                  style: context.text.displayMedium?.copyWith(
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            style: context.text.displayMedium,
                          ),
                        ),
                        const SizedBox(height: Space.xl),
                        const _Benefit(
                          icon: Icons.photo_camera_rounded,
                          text: 'Unlimited AI photo scans',
                        ),
                        const _Benefit(
                          icon: Icons.auto_awesome_rounded,
                          text: 'Smart "what to eat next" suggestions',
                        ),
                        const _Benefit(
                          icon: Icons.qr_code_scanner_rounded,
                          text: 'Barcode scanner & 1M+ food search',
                        ),
                        const _Benefit(
                          icon: Icons.insights_rounded,
                          text: 'Weekly insights & progress reports',
                        ),
                        const SizedBox(height: Space.xl),
                        if (plans == null || plan == null)
                          for (var i = 0; i < 3; i++) ...[
                            const _PlanCardSkeleton(),
                            const SizedBox(height: Space.sm),
                          ]
                        else
                          for (final p in plans) ...[
                            _PlanCard(
                              plan: p,
                              copy: _copyFor(p, plans),
                              selected: p.id == plan.id,
                              onTap: () => setState(() => _planId = p.id),
                            ),
                            const SizedBox(height: Space.sm),
                          ],
                        const SizedBox(height: Space.lg),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (plan != null)
              _CheckoutBar(
                plan: plan,
                busy: _busy,
                onBuy: () => _purchase(plan),
              ),
          ],
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHigh,
              borderRadius: Radii.smAll,
            ),
            child: Padding(
              padding: const EdgeInsets.all(Space.sm),
              child: Icon(icon, size: 18, color: context.colors.onSurface),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(child: Text(text, style: context.text.titleSmall)),
          Icon(Icons.check_rounded, size: 20, color: context.brand.success),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.copy,
    required this.selected,
    required this.onTap,
  });
  final ProPlan plan;
  final ({String detail, String? badge}) copy;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Pressable(
        onTap: onTap,
        semanticLabel:
            '${plan.label}, ${plan.priceLabel} for ${plan.period}. ${copy.detail}. ${copy.badge ?? ''}',
        child: AnimatedContainer(
          duration: Motion.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: Space.lg,
          ),
          decoration: BoxDecoration(
            color: context.brand.card,
            borderRadius: Radii.xlAll,
            border: Border.all(
              color: selected ? c.onSurface : c.outlineVariant,
              width: selected ? 2 : 1.5,
            ),
          ),
          child: ExcludeSemantics(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: Motion.fast,
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? c.onSurface : Colors.transparent,
                    border: Border.all(
                      color: selected ? c.onSurface : c.outline,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? Icon(Icons.check_rounded, size: 16, color: c.surface)
                      : null,
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: Space.sm,
                        runSpacing: Space.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(plan.label, style: context.text.titleMedium),
                          if (copy.badge != null) ...[
                            Pill(
                              label: copy.badge!,
                              background: context.brand.accent,
                              foreground: context.brand.onAccent,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: Space.xxs),
                      Text(
                        copy.detail,
                        style: context.text.bodySmall?.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text.rich(
                  TextSpan(
                    text: plan.priceLabel,
                    style: context.text.titleMedium,
                    children: [
                      TextSpan(
                        text: ' / ${plan.period}',
                        style: context.text.bodySmall?.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCardSkeleton extends StatelessWidget {
  const _PlanCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading prices',
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          color: context.colors.surfaceContainer,
          borderRadius: Radii.xlAll,
        ),
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.plan,
    required this.busy,
    required this.onBuy,
  });
  final ProPlan plan;
  final bool busy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodySmall?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.md,
            Space.gutter,
            Space.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy ? null : onBuy,
                  child: AnimatedSwitcher(
                    duration: Motion.fast,
                    child: busy
                        ? SizedBox.square(
                            key: const ValueKey('busy'),
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: context.colors.onSurface,
                            ),
                          )
                        : Text(
                            'Get Pro · ${plan.priceLabel}',
                            key: ValueKey(plan.id),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: Space.sm),
              Text(
                'One-time payment for ${plan.period} of Pro. No auto-renewal. '
                '${plan.supportsUpi ? 'Pay securely with UPI, cards or net banking' : 'Pay securely by card'} via Razorpay.',
                style: muted,
                textAlign: TextAlign.center,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final (label, route) in const [
                    ('Terms', Routes.terms),
                    ('Privacy', Routes.privacy),
                    ('Help', Routes.help),
                  ])
                    TextButton(
                      onPressed: () => context.push(route),
                      style: TextButton.styleFrom(
                        foregroundColor: context.colors.onSurfaceVariant,
                        textStyle: context.text.labelMedium,
                      ),
                      child: Text(label),
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
