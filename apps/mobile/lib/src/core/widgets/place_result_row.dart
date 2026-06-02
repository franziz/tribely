import 'package:flutter/material.dart';

import '../design/typography.dart';

/// One venue suggestion row — pure presentation primitive.
///
/// Tappable via [InkWell] with ripple feedback. Minimum height 64dp.
/// No state, no Riverpod, no domain imports.
///
/// Parameters:
/// - [name] — venue display name (primary line, body-medium semibold).
/// - [placeFormatted] — formatted address / locality (secondary line, caption).
/// - [onTap] — called when the row is tapped.
/// - [leading] — optional leading widget; defaults to [Icons.place_outlined].
class PlaceResultRow extends StatelessWidget {
  const PlaceResultRow({
    required this.name,
    required this.placeFormatted,
    required this.onTap,
    this.leading,
    super.key,
  });

  final String name;
  final String placeFormatted;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    final nameStyle = (dark
            ? theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'GeneralSans',
                color: const Color(0xFFF4EEDF),
              )
            : theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'GeneralSans',
                color: const Color(0xFF1A1714),
              ))
        ?.copyWith(fontWeight: FontWeight.w600);

    final secondaryStyle = dark
        ? TribelyType.caption(const Color(0xFFA39B8A))
        : TribelyType.caption(const Color(0xFF5C544A));

    final iconColor = dark
        ? const Color(0xFFA39B8A)
        : const Color(0xFF5C544A);

    final effectiveLeading =
        leading ?? Icon(Icons.place_outlined, color: iconColor, size: 22);

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              effectiveLeading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name, style: nameStyle),
                    const SizedBox(height: 2),
                    Text(placeFormatted, style: secondaryStyle),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
