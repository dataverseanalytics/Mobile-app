import 'dart:async';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../data/auth/auth_repository.dart';
import '../../state/providers.dart';
import 'auth_widgets.dart';
import 'country_sheet.dart';
import 'phone_utils.dart';

/// Step 1 of sign-in: country + mobile number. Same flow for new and
/// returning users.
class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late Country _country = PhoneUtils.deviceCountry();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _complete => PhoneUtils.looksComplete(_country, _controller.text);

  Future<void> _pickCountry() async {
    final c = await showCountrySheet(context, _country);
    if (c == null || !mounted) return;
    setState(() {
      _country = c;
      _error = null;
    });
    _focus.requestFocus();
  }

  Future<void> _submit() async {
    final e164 = PhoneUtils.toE164(_country, _controller.text);
    if (e164 == null) {
      setState(
        () => _error =
            "That doesn't look like a valid ${_country.name} mobile number.",
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(authRepositoryProvider).sendCode(e164);
      if (!mounted) return;
      switch (result) {
        case CodeSent(:final session):
          ref.read(otpSessionProvider.notifier).set(session);
          setState(() => _busy = false);
          // Don't await: this screen must not stay "busy" underneath.
          unawaited(context.push(Routes.otp));
        case AutoVerified(:final user):
          await ref.read(accountProvider.notifier).signedIn(user);
          if (mounted) context.go(Routes.today);
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AuthScaffold(
      onBack: () =>
          context.canPop() ? context.pop() : context.go(Routes.welcome),
      title: 'Enter your phone number',
      subtitle: const Text(
        "We'll text you a 6-digit code to sign in or create your account.",
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: 'Country: ${_country.name}, +${_country.phoneCode}',
                excludeSemantics: true,
                child: Material(
                  color: context.brand.card,
                  shape: StadiumBorder(
                    side: BorderSide(color: c.outlineVariant),
                  ),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: _busy ? null : _pickCountry,
                    child: SizedBox(
                      height: Sizes.buttonHeight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.lg,
                        ),
                        child: Row(
                          children: [
                            Text(
                              _country.flagEmoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: Space.sm),
                            Text(
                              '+${_country.phoneCode}',
                              style: context.text.titleMedium,
                            ),
                            const SizedBox(width: Space.xs),
                            Icon(
                              Icons.expand_more_rounded,
                              color: c.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  enabled: !_busy,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-()]')),
                    LengthLimitingTextInputFormatter(18),
                  ],
                  style: context.text.titleMedium?.copyWith(
                    letterSpacing: 0.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  decoration: InputDecoration(
                    hintText: 'Mobile number',
                    enabledBorder: OutlineInputBorder(
                      borderRadius: Radii.pillAll,
                      borderSide: BorderSide(
                        color: _error == null ? c.outlineVariant : c.error,
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _complete ? _submit() : null,
                ),
              ),
            ],
          ),
          InlineError(_error),
          const SizedBox(height: Space.xl),
          const _InfoRow(
            icon: Icons.public_rounded,
            text: 'Works in 200+ countries. Standard SMS rates may apply.',
          ),
          const SizedBox(height: Space.md),
          const _InfoRow(
            icon: Icons.lock_outline_rounded,
            text: 'Your number is only used to sign you in. We never share it.',
          ),
        ],
      ),
      action: BusyButton(
        label: 'Send code',
        busy: _busy,
        onPressed: _complete ? _submit : null,
      ),
      footer: const LegalConsent(),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: context.colors.onSurfaceVariant),
        const SizedBox(width: Space.md),
        Expanded(
          child: Text(
            text,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
