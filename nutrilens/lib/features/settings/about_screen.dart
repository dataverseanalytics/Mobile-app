import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/settings_widgets.dart';

const appVersion = '1.0.0';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      title: 'About',
      children: [
        const SizedBox(height: Space.lg),
        const Center(child: LogoMark(size: 72)),
        const SizedBox(height: Space.lg),
        Center(child: Text('NutriLens', style: context.text.headlineMedium)),
        Center(
          child: Text(
            'Version $appVersion',
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        Text(
          'NutriLens turns a photo of your plate into calories and macros in '
          'seconds, so eating well takes less effort than ever.',
          textAlign: TextAlign.center,
          style: context.text.bodyLarge?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const GroupLabel('Legal'),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.description_outlined,
              title: 'Terms of Use',
              onTap: () => context.push(Routes.terms),
            ),
            SettingsRow(
              icon: Icons.lock_outline_rounded,
              title: 'Privacy Policy',
              onTap: () => context.push(Routes.privacy),
            ),
            SettingsRow(
              icon: Icons.code_rounded,
              title: 'Open-source licences',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'NutriLens',
                applicationVersion: appVersion,
              ),
            ),
          ],
        ),
        const GroupLabel('Credits'),
        const SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.photo_outlined,
              title: 'Food photography',
              subtitle: 'Unsplash contributors (Unsplash Licence)',
            ),
            SettingsRow(
              icon: Icons.text_fields_rounded,
              title: 'Typefaces',
              subtitle: 'Inter & Sora (SIL Open Font Licence)',
            ),
          ],
        ),
        const SizedBox(height: Space.xxl),
        Center(
          child: Text(
            '© 2026 NutriLens. Made with care for healthier days.',
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
