import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../state/providers.dart';
import 'auth_widgets.dart';
import 'phone_utils.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

/// First sign-in only: what to call the user (+ optional email).
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key, this.editing = false});

  /// Reused from Settings → Edit profile.
  final bool editing;

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: ref.read(accountProvider)?.name,
  );
  late final _email = TextEditingController(
    text: ref.read(accountProvider)?.email,
  );
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    await ref
        .read(accountProvider.notifier)
        .saveProfile(name: _name.text, email: _email.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (widget.editing) {
      context.pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated')));
    } else {
      context.go(Routes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);
    return Form(
      key: _form,
      child: AuthScaffold(
        onBack: widget.editing ? () => context.pop() : null,
        title: widget.editing ? 'Edit profile' : 'What should we call you?',
        subtitle: Text(
          widget.editing
              ? 'This is how you appear in NutriLens.'
              : 'Just your first name is fine. You can change it later.',
        ),
        body: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Label('Name'),
              TextFormField(
                controller: _name,
                autofocus: !widget.editing,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                maxLength: 40,
                decoration: const InputDecoration(
                  hintText: 'e.g. Aarav',
                  counterText: '',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter your name'
                    : null,
              ),
              const SizedBox(height: Space.xl),
              const _Label('Email (optional)'),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(hintText: 'you@example.com'),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return null;
                  return _emailPattern.hasMatch(t)
                      ? null
                      : 'Enter an email like name@example.com';
                },
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: Space.sm),
              Text(
                'For receipts and weekly progress reports. No spam.',
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              if (widget.editing && account != null) ...[
                const SizedBox(height: Space.xl),
                const _Label('Phone'),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainer,
                    borderRadius: Radii.pillAll,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.lg,
                      vertical: Space.lg,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            PhoneUtils.pretty(account.phone),
                            style: context.text.bodyLarge,
                          ),
                        ),
                        Icon(
                          Icons.verified_rounded,
                          size: 18,
                          color: context.brand.success,
                        ),
                        const SizedBox(width: Space.xs),
                        Text(
                          'Verified',
                          style: context.text.labelMedium?.copyWith(
                            color: context.brand.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        action: BusyButton(
          label: widget.editing ? 'Save changes' : 'Continue',
          busy: _busy,
          onPressed: _save,
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: Space.xs, bottom: Space.sm),
      child: Text(text, style: context.text.labelLarge),
    );
  }
}
