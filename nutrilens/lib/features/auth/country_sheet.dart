import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import 'phone_utils.dart';

/// Searchable list of every country with flag and dial code.
Future<Country?> showCountrySheet(BuildContext context, Country selected) {
  return showModalBottomSheet<Country>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _CountrySheet(selected: selected),
  );
}

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({required this.selected});
  final Country selected;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  final _all = PhoneUtils.allCountries;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Country> get _filtered {
    final q = _query.trim().toLowerCase().replaceAll('+', '');
    if (q.isEmpty) return _all;
    return _all
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.phoneCode.startsWith(q) ||
              c.countryCode.toLowerCase() == q,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final suggested = _query.isEmpty;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              0,
              Space.gutter,
              Space.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose your country', style: context.text.titleLarge),
                const SizedBox(height: Space.md),
                TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search country or code',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.cancel_rounded),
                          ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text(
                      'No country matches “${_query.trim()}”',
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.only(bottom: Space.xxl),
                    itemCount: list.length + (suggested ? 2 : 0),
                    itemBuilder: (context, i) {
                      if (suggested && i == 0) {
                        return _CountryTile(
                          country: widget.selected,
                          selected: true,
                          onTap: () => Navigator.pop(context, widget.selected),
                        );
                      }
                      if (suggested && i == 1) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Space.gutter,
                            Space.lg,
                            Space.gutter,
                            Space.sm,
                          ),
                          child: Text(
                            'ALL COUNTRIES',
                            style: context.text.labelSmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        );
                      }
                      final c = list[i - (suggested ? 2 : 0)];
                      return _CountryTile(
                        key: ValueKey(c.countryCode),
                        country: c,
                        selected: false,
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CountryTile extends StatelessWidget {
  const _CountryTile({
    super.key,
    required this.country,
    required this.selected,
    required this.onTap,
  });

  final Country country;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      leading: Text(country.flagEmoji, style: const TextStyle(fontSize: 26)),
      title: Text(country.name, style: context.text.bodyLarge),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '+${country.phoneCode}',
            style: context.text.titleSmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          if (selected) ...[
            const SizedBox(width: Space.sm),
            Icon(Icons.check_circle_rounded, color: context.colors.onSurface),
          ],
        ],
      ),
    );
  }
}
