import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../data/auth/auth_repository.dart';

/// The pending OTP verification between the phone and code screens.
class OtpSessionNotifier extends Notifier<OtpSession?> {
  @override
  OtpSession? build() => null;
  void set(OtpSession? s) => state = s;
}

final otpSessionProvider = NotifierProvider<OtpSessionNotifier, OtpSession?>(
  OtpSessionNotifier.new,
);

/// Consistent frame for every auth step: back button, heading, body,
/// and a primary action pinned above the keyboard.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.action,
    this.onBack,
    this.footer,
  });

  final String title;
  final Widget subtitle;
  final Widget body;
  final Widget action;
  final VoidCallback? onBack;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: onBack == null
            ? null
            : IconButton(
                onPressed: onBack,
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.sm,
                  Space.gutter,
                  Space.xl,
                ),
                children: [
                  Semantics(
                    header: true,
                    child: Text(title, style: context.text.displaySmall),
                  ),
                  const SizedBox(height: Space.sm),
                  DefaultTextStyle.merge(
                    style: context.text.bodyLarge?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                    child: subtitle,
                  ),
                  const SizedBox(height: Space.xxxl),
                  body,
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.sm,
                Space.gutter,
                Space.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: double.infinity, child: action),
                  if (footer != null) ...[
                    const SizedBox(height: Space.md),
                    footer!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Primary button with an inline spinner while busy.
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
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
            : Text(label, key: ValueKey(label)),
      ),
    );
  }
}

/// "By continuing you agree to the Terms and Privacy Policy."
class LegalConsent extends StatefulWidget {
  const LegalConsent({super.key});

  @override
  State<LegalConsent> createState() => _LegalConsentState();
}

class _LegalConsentState extends State<LegalConsent> {
  late final _terms = TapGestureRecognizer()
    ..onTap = () => context.push(Routes.terms);
  late final _privacy = TapGestureRecognizer()
    ..onTap = () => context.push(Routes.privacy);

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodySmall?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    final link = muted?.copyWith(
      color: context.colors.onSurface,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );
    return Text.rich(
      TextSpan(
        style: muted,
        children: [
          const TextSpan(text: 'By continuing you agree to our '),
          TextSpan(text: 'Terms', style: link, recognizer: _terms),
          const TextSpan(text: ' and '),
          TextSpan(text: 'Privacy Policy', style: link, recognizer: _privacy),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Inline error line under a field.
class InlineError extends StatelessWidget {
  const InlineError(this.message, {super.key});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: Motion.fast,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: context.colors.error,
                    ),
                    const SizedBox(width: Space.xs + 2),
                    Expanded(
                      child: Text(
                        message!,
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.error,
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

/// Visible only when SMS is simulated, so nobody mistakes demo for live.
class DemoModeBanner extends ConsumerWidget {
  const DemoModeBanner({super.key, required this.text, required this.isDemo});
  final String text;
  final bool isDemo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isDemo) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.brand.warning.withValues(alpha: 0.12),
        borderRadius: Radii.mdAll,
        border: Border.all(color: context.brand.warning.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Row(
          children: [
            Icon(
              Icons.science_outlined,
              color: context.brand.warning,
              size: 20,
            ),
            const SizedBox(width: Space.sm),
            Expanded(child: Text(text, style: context.text.bodySmall)),
          ],
        ),
      ),
    );
  }
}

String authErrorMessage(Object e) =>
    e is AuthFailure ? e.message : 'Something went wrong. Please try again.';
