import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../state/providers.dart';

/// Single entry point to the camera — enforces the free-scan limit.
void openScanner(BuildContext context, WidgetRef ref, {bool barcode = false}) {
  HapticFeedback.mediumImpact();
  if (!barcode && !ref.read(canScanProvider)) {
    context.push(Routes.paywall);
    return;
  }
  context.push(barcode ? '${Routes.scan}?mode=barcode' : Routes.scan);
}

/// "How do you want to log?" sheet: photo, barcode, or search.
Future<void> showLogSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) {
      void pick(VoidCallback action) {
        Navigator.of(sheetContext).pop();
        action();
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          0,
          Space.gutter,
          Space.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Log a meal', style: sheetContext.text.titleLarge),
            const SizedBox(height: Space.lg),
            _LogOption(
              icon: Icons.photo_camera_rounded,
              title: 'Snap a photo',
              subtitle: 'Fastest — AI does the rest',
              highlight: true,
              onTap: () => pick(() => openScanner(context, ref)),
            ),
            _LogOption(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Scan a barcode',
              subtitle: 'Exact numbers for packaged food',
              onTap: () => pick(() => openScanner(context, ref, barcode: true)),
            ),
            _LogOption(
              icon: Icons.search_rounded,
              title: 'Search or describe',
              subtitle: 'Type “2 rotis and dal”',
              onTap: () => pick(() => context.push(Routes.search)),
            ),
          ],
        ),
      );
    },
  );
}

class _LogOption extends StatelessWidget {
  const _LogOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Material(
        color: highlight ? context.colors.onSurface : context.brand.card,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.lgAll,
          side: highlight
              ? BorderSide.none
              : BorderSide(color: context.colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: highlight
                        ? context.brand.accent
                        : context.colors.surfaceContainerHigh,
                    borderRadius: Radii.mdAll,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(Space.md - 2),
                    child: Icon(
                      icon,
                      size: 22,
                      color: highlight
                          ? context.brand.onAccent
                          : context.colors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.text.titleMedium?.copyWith(
                          color: highlight
                              ? context.colors.surface
                              : context.colors.onSurface,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: context.text.bodySmall?.copyWith(
                          color: highlight
                              ? context.colors.surface.withValues(alpha: 0.7)
                              : context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: highlight
                      ? context.colors.surface
                      : context.colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
