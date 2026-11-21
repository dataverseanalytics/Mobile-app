import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../scan/scan_launcher.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      extendBody: true,
      bottomNavigationBar: _NavBar(
        index: shell.currentIndex,
        onSelect: (i) {
          HapticFeedback.selectionClick();
          shell.goBranch(i, initialLocation: i == shell.currentIndex);
        },
      ),
    );
  }
}

class _NavBar extends ConsumerWidget {
  const _NavBar({required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Today'),
    (Icons.menu_book_outlined, Icons.menu_book_rounded, 'Diary'),
    (Icons.insights_outlined, Icons.insights_rounded, 'Progress'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget item(int i) => Expanded(
      child: _NavItem(
        icon: _items[i].$1,
        selectedIcon: _items[i].$2,
        label: _items[i].$3,
        selected: index == i,
        onTap: () => onSelect(i),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: Sizes.navBar,
          child: Row(
            children: [
              item(0),
              item(1),
              Expanded(
                child: Center(
                  child: _ScanButton(onTap: () => openScanner(context, ref)),
                ),
              ),
              item(2),
              item(3),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = selected
        ? context.colors.onSurface
        : context.colors.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: Motion.fast,
              child: Icon(
                selected ? selectedIcon : icon,
                key: ValueKey(selected),
                color: c,
                size: 24,
              ),
            ),
            const SizedBox(height: Space.xs),
            Text(
              label,
              style: context.text.labelSmall?.copyWith(
                color: c,
                letterSpacing: 0.2,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The hero action: ink disc with a lime ring.
class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = context.isDark
        ? context.brand.accent
        : context.colors.onSurface;
    final onInk = context.isDark
        ? context.brand.onAccent
        : context.brand.accent;
    return Semantics(
      button: true,
      label: 'Scan a meal',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Scan a meal',
        child: Material(
          color: ink,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(
              dimension: Sizes.scanButton - 6,
              child: Icon(Icons.photo_camera_rounded, color: onInk, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}
