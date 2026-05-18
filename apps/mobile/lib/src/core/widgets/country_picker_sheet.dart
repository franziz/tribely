import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';

/// A country + dial-code record returned when the user selects a country.
typedef CountrySelection = ({
  String dialCode,
  String flagEmoji,
  String isoCode,
});

/// A static country entry in the picker list.
class _Country {
  const _Country({
    required this.isoCode,
    required this.name,
    required this.dialCode,
    required this.flagEmoji,
  });

  final String isoCode;
  final String name;
  final String dialCode;
  final String flagEmoji;
}

// ---------------------------------------------------------------------------
// Static country list — covers Singapore, the pinned suggestions, and the
// ~50 most common dial codes. Full ISO-3166 is not required for MVP.
// Expanding this list in future is trivial.
// ---------------------------------------------------------------------------
const List<_Country> _kCountries = [
  _Country(
    isoCode: 'SG',
    name: 'Singapore',
    dialCode: '+65',
    flagEmoji: '🇸🇬',
  ),
  _Country(isoCode: 'MY', name: 'Malaysia', dialCode: '+60', flagEmoji: '🇲🇾'),
  _Country(isoCode: 'IN', name: 'India', dialCode: '+91', flagEmoji: '🇮🇳'),
  _Country(isoCode: 'CN', name: 'China', dialCode: '+86', flagEmoji: '🇨🇳'),
  _Country(
    isoCode: 'PH',
    name: 'Philippines',
    dialCode: '+63',
    flagEmoji: '🇵🇭',
  ),
  _Country(
    isoCode: 'AU',
    name: 'Australia',
    dialCode: '+61',
    flagEmoji: '🇦🇺',
  ),
  _Country(
    isoCode: 'BD',
    name: 'Bangladesh',
    dialCode: '+880',
    flagEmoji: '🇧🇩',
  ),
  _Country(isoCode: 'BR', name: 'Brazil', dialCode: '+55', flagEmoji: '🇧🇷'),
  _Country(isoCode: 'CA', name: 'Canada', dialCode: '+1', flagEmoji: '🇨🇦'),
  _Country(isoCode: 'DE', name: 'Germany', dialCode: '+49', flagEmoji: '🇩🇪'),
  _Country(isoCode: 'EG', name: 'Egypt', dialCode: '+20', flagEmoji: '🇪🇬'),
  _Country(isoCode: 'ES', name: 'Spain', dialCode: '+34', flagEmoji: '🇪🇸'),
  _Country(isoCode: 'FR', name: 'France', dialCode: '+33', flagEmoji: '🇫🇷'),
  _Country(
    isoCode: 'GB',
    name: 'United Kingdom',
    dialCode: '+44',
    flagEmoji: '🇬🇧',
  ),
  _Country(isoCode: 'GH', name: 'Ghana', dialCode: '+233', flagEmoji: '🇬🇭'),
  _Country(
    isoCode: 'HK',
    name: 'Hong Kong',
    dialCode: '+852',
    flagEmoji: '🇭🇰',
  ),
  _Country(
    isoCode: 'ID',
    name: 'Indonesia',
    dialCode: '+62',
    flagEmoji: '🇮🇩',
  ),
  _Country(isoCode: 'IE', name: 'Ireland', dialCode: '+353', flagEmoji: '🇮🇪'),
  _Country(isoCode: 'IT', name: 'Italy', dialCode: '+39', flagEmoji: '🇮🇹'),
  _Country(isoCode: 'JP', name: 'Japan', dialCode: '+81', flagEmoji: '🇯🇵'),
  _Country(isoCode: 'KE', name: 'Kenya', dialCode: '+254', flagEmoji: '🇰🇪'),
  _Country(
    isoCode: 'KR',
    name: 'South Korea',
    dialCode: '+82',
    flagEmoji: '🇰🇷',
  ),
  _Country(
    isoCode: 'LK',
    name: 'Sri Lanka',
    dialCode: '+94',
    flagEmoji: '🇱🇰',
  ),
  _Country(isoCode: 'MM', name: 'Myanmar', dialCode: '+95', flagEmoji: '🇲🇲'),
  _Country(isoCode: 'MX', name: 'Mexico', dialCode: '+52', flagEmoji: '🇲🇽'),
  _Country(isoCode: 'NG', name: 'Nigeria', dialCode: '+234', flagEmoji: '🇳🇬'),
  _Country(
    isoCode: 'NL',
    name: 'Netherlands',
    dialCode: '+31',
    flagEmoji: '🇳🇱',
  ),
  _Country(isoCode: 'NP', name: 'Nepal', dialCode: '+977', flagEmoji: '🇳🇵'),
  _Country(
    isoCode: 'NZ',
    name: 'New Zealand',
    dialCode: '+64',
    flagEmoji: '🇳🇿',
  ),
  _Country(isoCode: 'PK', name: 'Pakistan', dialCode: '+92', flagEmoji: '🇵🇰'),
  _Country(
    isoCode: 'PT',
    name: 'Portugal',
    dialCode: '+351',
    flagEmoji: '🇵🇹',
  ),
  _Country(isoCode: 'RU', name: 'Russia', dialCode: '+7', flagEmoji: '🇷🇺'),
  _Country(
    isoCode: 'SA',
    name: 'Saudi Arabia',
    dialCode: '+966',
    flagEmoji: '🇸🇦',
  ),
  _Country(isoCode: 'SE', name: 'Sweden', dialCode: '+46', flagEmoji: '🇸🇪'),
  _Country(isoCode: 'TH', name: 'Thailand', dialCode: '+66', flagEmoji: '🇹🇭'),
  _Country(isoCode: 'TR', name: 'Turkey', dialCode: '+90', flagEmoji: '🇹🇷'),
  _Country(isoCode: 'TW', name: 'Taiwan', dialCode: '+886', flagEmoji: '🇹🇼'),
  _Country(isoCode: 'UA', name: 'Ukraine', dialCode: '+380', flagEmoji: '🇺🇦'),
  _Country(
    isoCode: 'US',
    name: 'United States',
    dialCode: '+1',
    flagEmoji: '🇺🇸',
  ),
  _Country(isoCode: 'VN', name: 'Vietnam', dialCode: '+84', flagEmoji: '🇻🇳'),
  _Country(
    isoCode: 'ZA',
    name: 'South Africa',
    dialCode: '+27',
    flagEmoji: '🇿🇦',
  ),
];

// Pinned ISO codes shown at the top as "Suggested".
const List<String> _kPinnedIsoCodes = ['SG', 'MY', 'IN', 'CN', 'PH'];

/// Shows the country picker modal sheet and returns the user's selection.
///
/// IMPORTANT: This sheet is used in the phone-OTP sign-up wizard, which is
/// NOT inside a [StatefulShellRoute.indexedStack]. The modal-sheet memory-leak
/// bug that affects sheets launched from inside the indexed-stack shell does
/// NOT apply here. Future callers who want to reuse this sheet from inside the
/// indexed-stack shell MUST audit the go_router StatefulShellRoute issue first.
Future<CountrySelection?> showCountryPickerSheet(
  BuildContext context, {
  String selectedIsoCode = 'SG',
}) {
  return showModalBottomSheet<CountrySelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _CountryPickerSheet(selectedIsoCode: selectedIsoCode),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({required this.selectedIsoCode});

  final String selectedIsoCode;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(_Country c, String query) {
    if (query.isEmpty) return true;
    return c.name.toLowerCase().contains(query) || c.dialCode.contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final primary = dark
        ? TribelyColors.nightPrimary
        : TribelyColors.paperPrimary;
    final borderSubtle = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;

    final pinnedCountries =
        _kCountries
            .where((c) => _kPinnedIsoCodes.contains(c.isoCode))
            .where((c) => _matches(c, _query))
            .toList()
          ..sort(
            (a, b) => _kPinnedIsoCodes
                .indexOf(a.isoCode)
                .compareTo(_kPinnedIsoCodes.indexOf(b.isoCode)),
          );

    final allCountries = _kCountries.where((c) => _matches(c, _query)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _SearchField(
                controller: _searchController,
                dark: dark,
                inkPrimary: inkPrimary,
                inkSecondary: inkSecondary,
                accentColor: primary,
                borderSubtle: borderSubtle,
              ),
            ),
            // Country list
            Expanded(
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  // Pinned "Suggested" section
                  if (pinnedCountries.isNotEmpty) ...[
                    _SectionHeader(
                      label: 'Suggested',
                      inkSecondary: inkSecondary,
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _CountryRow(
                          country: pinnedCountries[i],
                          isSelected:
                              pinnedCountries[i].isoCode ==
                              widget.selectedIsoCode,
                          inkPrimary: inkPrimary,
                          inkSecondary: inkSecondary,
                          primary: primary,
                          borderSubtle: borderSubtle,
                          onTap: () => Navigator.of(context).pop((
                            dialCode: pinnedCountries[i].dialCode,
                            flagEmoji: pinnedCountries[i].flagEmoji,
                            isoCode: pinnedCountries[i].isoCode,
                          )),
                        ),
                        childCount: pinnedCountries.length,
                      ),
                    ),
                    _SectionDivider(color: borderSubtle),
                    _SectionHeader(
                      label: 'All countries',
                      inkSecondary: inkSecondary,
                    ),
                  ],
                  // A–Z list
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _CountryRow(
                        country: allCountries[i],
                        isSelected:
                            allCountries[i].isoCode == widget.selectedIsoCode,
                        inkPrimary: inkPrimary,
                        inkSecondary: inkSecondary,
                        primary: primary,
                        borderSubtle: borderSubtle,
                        onTap: () => Navigator.of(context).pop((
                          dialCode: allCountries[i].dialCode,
                          flagEmoji: allCountries[i].flagEmoji,
                          isoCode: allCountries[i].isoCode,
                        )),
                      ),
                      childCount: allCountries.length,
                    ),
                  ),
                  // Bottom safe-area padding
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-components
// ---------------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.dark,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.accentColor,
    required this.borderSubtle,
  });

  final TextEditingController controller;
  final bool dark;
  final Color inkPrimary;
  final Color inkSecondary;
  final Color accentColor;
  final Color borderSubtle;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      keyboardType: TextInputType.text,
      style: TribelyType.bodyM(inkPrimary),
      cursorColor: accentColor,
      decoration: InputDecoration(
        hintText: 'Search country or dial code',
        hintStyle: TribelyType.bodyM(inkSecondary),
        prefixIcon: Icon(Icons.search, size: 20, color: inkSecondary),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderSubtle, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.inkSecondary});

  final String label;
  final Color inkSecondary;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(label, style: TribelyType.caption(inkSecondary)),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Divider(
        color: color,
        height: 1,
        thickness: 1,
        indent: 16,
        endIndent: 16,
      ),
    );
  }
}

class _CountryRow extends StatelessWidget {
  const _CountryRow({
    required this.country,
    required this.isSelected,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.primary,
    required this.borderSubtle,
    required this.onTap,
  });

  final _Country country;
  final bool isSelected;
  final Color inkPrimary;
  final Color inkSecondary;
  final Color primary;
  final Color borderSubtle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Emoji flag
              Text(country.flagEmoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              // Country name
              Expanded(
                child: Text(
                  country.name,
                  style: TribelyType.bodyM(inkPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Trailing: checkmark if selected, dial code otherwise.
              if (isSelected)
                Icon(Icons.check, size: 18, color: primary)
              else
                Text(country.dialCode, style: TribelyType.bodyM(inkSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
