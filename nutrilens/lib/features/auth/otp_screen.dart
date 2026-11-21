import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../data/auth/auth_repository.dart';
import '../../data/auth/demo_auth_repository.dart';
import '../../state/providers.dart';
import 'auth_widgets.dart';
import 'phone_utils.dart';

/// Step 2 of sign-in: the 6-digit code. Auto-submits when complete,
/// supports SMS autofill, and offers resend after a cooldown.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with SingleTickerProviderStateMixin {
  static const _length = 6;
  static const _cooldown = 30;

  final _controller = TextEditingController();
  final _focus = FocusNode();
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  Timer? _timer;
  int _secondsLeft = _cooldown;
  bool _busy = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shake.dispose();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    final session = ref.read(otpSessionProvider);
    final code = _controller.text;
    if (session == null || code.length != _length || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .verifyCode(session, code);
      await ref.read(accountProvider.notifier).signedIn(user);
      ref.read(otpSessionProvider.notifier).set(null);
      unawaited(HapticFeedback.mediumImpact());
      // The router redirect sends new users to profile setup and
      // returning users straight to Today.
      if (mounted) context.go(Routes.today);
    } on Object catch (e) {
      if (!mounted) return;
      unawaited(HapticFeedback.heavyImpact());
      unawaited(_shake.forward(from: 0));
      setState(() {
        _error = authErrorMessage(e);
        _controller.clear();
      });
      _focus.requestFocus();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final session = ref.read(otpSessionProvider);
    if (session == null) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .sendCode(session.phone, resendToken: session.resendToken);
      if (!mounted) return;
      switch (result) {
        case CodeSent(:final session):
          ref.read(otpSessionProvider.notifier).set(session);
          _startCooldown();
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('New code sent')));
        case AutoVerified(:final user):
          await ref.read(accountProvider.notifier).signedIn(user);
          if (mounted) context.go(Routes.today);
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(otpSessionProvider);
    final isDemo = ref.watch(authRepositoryProvider).isDemo;
    if (session == null) {
      // Opened without a pending verification (e.g. refreshed): restart.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(Routes.phone);
      });
      return const Scaffold();
    }

    return AuthScaffold(
      onBack: () => context.pop(),
      title: 'Enter the code',
      subtitle: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'We sent a 6-digit code to '),
            TextSpan(
              text: PhoneUtils.pretty(session.phone),
              style: TextStyle(
                color: context.colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const TextSpan(text: '.'),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DemoModeBanner(
            isDemo: isDemo || session.devCode != null,
            text: session.devCode != null
                ? 'Development server — no SMS is sent. '
                      'Your code is ${session.devCode}.'
                : 'Demo mode — SMS is simulated until a backend is connected. '
                      'Use code ${DemoAuthRepository.code}.',
          ),
          if (isDemo || session.devCode != null)
            const SizedBox(height: Space.xl),
          AnimatedBuilder(
            animation: _shake,
            builder: (context, child) => Transform.translate(
              offset: Offset(math.sin(_shake.value * math.pi * 6) * 8, 0),
              child: child,
            ),
            child: _CodeBoxes(
              controller: _controller,
              focus: _focus,
              length: _length,
              hasError: _error != null,
              enabled: !_busy,
              onChanged: (v) {
                if (_error != null) setState(() => _error = null);
                setState(() {});
                if (v.length == _length) _verify();
              },
            ),
          ),
          InlineError(_error),
          const SizedBox(height: Space.xl),
          Row(
            children: [
              Expanded(
                child: Text(
                  _secondsLeft > 0
                      ? 'Resend code in 0:${_secondsLeft.toString().padLeft(2, '0')}'
                      : "Didn't get it?",
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: _secondsLeft > 0 || _resending ? null : _resend,
                child: Text(_resending ? 'Sending…' : 'Resend code'),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: () => context.pop(),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.onSurfaceVariant,
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Change phone number'),
          ),
        ],
      ),
      action: BusyButton(
        label: 'Verify',
        busy: _busy,
        onPressed: _controller.text.length == _length ? _verify : null,
      ),
    );
  }
}

/// Six boxes driven by one hidden text field — keeps paste, SMS autofill
/// and accessibility working like a normal input.
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({
    required this.controller,
    required this.focus,
    required this.length,
    required this.hasError,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final int length;
  final bool hasError;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      children: [
        // The real input: invisible but focusable and autofill-aware.
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              key: const Key('otp-input'),
              controller: controller,
              focusNode: focus,
              autofocus: true,
              enabled: enabled,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(length),
              ],
              showCursor: false,
              enableInteractiveSelection: false,
              onChanged: onChanged,
              decoration: const InputDecoration(
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: ListenableBuilder(
            listenable: Listenable.merge([controller, focus]),
            builder: (context, _) {
              final text = controller.text;
              return Row(
                children: [
                  for (var i = 0; i < length; i++) ...[
                    if (i > 0) const SizedBox(width: Space.sm),
                    Expanded(
                      child: AnimatedContainer(
                        duration: Motion.fast,
                        height: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.brand.card,
                          borderRadius: Radii.mdAll,
                          border: Border.all(
                            width: 1.5,
                            color: hasError
                                ? c.error
                                : (focus.hasFocus && i == text.length) ||
                                      (i < text.length)
                                ? c.onSurface
                                : c.outlineVariant,
                          ),
                        ),
                        child: Text(
                          i < text.length ? text[i] : '',
                          style: context.text.headlineSmall,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
