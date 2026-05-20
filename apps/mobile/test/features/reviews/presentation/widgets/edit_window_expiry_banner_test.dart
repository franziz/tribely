// Widget tests for EditWindowExpiryBanner.
//
// Covers:
//   1. Banner renders when review is >24h old.
//   2. Banner is absent when review is <24h old.
//   3. EditWindowExpiryBanner.isExpired() returns correct values.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tribely/src/features/reviews/presentation/string_assets/review_copy.dart';
import 'package:tribely/src/features/reviews/presentation/widgets/edit_window_expiry_banner.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('EditWindowExpiryBanner.isExpired()', () {
    test('returns true when createdAt is >24h ago', () {
      final old = DateTime.now().subtract(const Duration(hours: 25));
      expect(EditWindowExpiryBanner.isExpired(old), isTrue);
    });

    test('returns false when createdAt is <24h ago', () {
      final recent = DateTime.now().subtract(const Duration(hours: 1));
      expect(EditWindowExpiryBanner.isExpired(recent), isFalse);
    });

    test('returns true at exactly 24h', () {
      final exactly = DateTime.now().subtract(const Duration(hours: 24));
      // inHours truncates — exactly 24h → inHours == 24 → expired.
      expect(EditWindowExpiryBanner.isExpired(exactly), isTrue);
    });

    test('returns false at 23h59m', () {
      final almostExpired = DateTime.now().subtract(
        const Duration(hours: 23, minutes: 59),
      );
      // inHours == 23 → not expired.
      expect(EditWindowExpiryBanner.isExpired(almostExpired), isFalse);
    });
  });

  group('EditWindowExpiryBanner widget', () {
    testWidgets('renders the lock copy text', (tester) async {
      await tester.pumpWidget(_wrap(const EditWindowExpiryBanner()));

      expect(find.text(ReviewCopy.editWindowExpired), findsOneWidget);
    });
  });
}
