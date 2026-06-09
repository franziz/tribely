import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tribely/src/core/observability/sentry_bootstrap.dart';

void main() {
  group('scrubEvent', () {
    SentryEvent makeEvent({
      String? message,
      String? exceptionValue,
      // ignore: deprecated_member_use
      Map<String, dynamic>? extra,
    }) {
      return SentryEvent(
        message: message != null ? SentryMessage(message) : null,
        exceptions: exceptionValue != null
            ? [SentryException(type: 'Error', value: exceptionValue)]
            : null,
        // ignore: deprecated_member_use
        extra: extra,
      );
    }

    test('redacts email in message', () {
      final event = makeEvent(message: 'User user@example.com logged in');
      final result = scrubEvent(event, Hint());
      expect(result!.message!.formatted, 'User [redacted-email] logged in');
    });

    test('redacts SG phone in message', () {
      final event = makeEvent(message: 'Contact +6591234567 now');
      final result = scrubEvent(event, Hint());
      expect(result!.message!.formatted, 'Contact [redacted-phone] now');
    });

    test('redacts intl phone in message', () {
      final event = makeEvent(message: 'Call +442071234567 please');
      final result = scrubEvent(event, Hint());
      expect(result!.message!.formatted, 'Call [redacted-phone] please');
    });

    test('redacts JWT token in message', () {
      const token =
          'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
      final event = makeEvent(message: 'Token: $token');
      final result = scrubEvent(event, Hint());
      expect(result!.message!.formatted, 'Token: [redacted-token]');
    });

    test('redacts email in exception value', () {
      final event = makeEvent(exceptionValue: 'Failed for user@test.org');
      final result = scrubEvent(event, Hint());
      expect(result!.exceptions!.first.value, 'Failed for [redacted-email]');
    });

    test('redacts email in extra string values', () {
      final event = makeEvent(
        message: 'error',
        extra: {'user': 'admin@tribely.app', 'count': 42},
      );
      final result = scrubEvent(event, Hint());
      // ignore: deprecated_member_use
      expect(result!.extra!['user'], '[redacted-email]');
      // ignore: deprecated_member_use
      expect(result.extra!['count'], 42); // non-string values untouched
    });

    test('tags event with stack:mobile', () {
      final event = makeEvent(message: 'hello');
      final result = scrubEvent(event, Hint());
      expect(result!.tags!['stack'], 'mobile');
    });

    test('preserves existing tags alongside stack tag', () {
      final event = SentryEvent(
        message: SentryMessage('hi'),
        tags: {'env': 'test'},
      );
      final result = scrubEvent(event, Hint());
      expect(result!.tags!['env'], 'test');
      expect(result.tags!['stack'], 'mobile');
    });

    test('passes through clean event unchanged (aside from tag)', () {
      final event = makeEvent(message: 'no PII here');
      final result = scrubEvent(event, Hint());
      expect(result!.message!.formatted, 'no PII here');
    });

    test('handles null message gracefully', () {
      final event = SentryEvent();
      final result = scrubEvent(event, Hint());
      expect(result, isNotNull);
      expect(result!.message, isNull);
    });
  });

  group('scrubBreadcrumb', () {
    Breadcrumb makeBreadcrumb({Map<String, dynamic>? data}) {
      return Breadcrumb(message: 'test', timestamp: DateTime.now(), data: data);
    }

    test('strips query string from data url', () {
      final bc = makeBreadcrumb(
        data: {'url': 'https://api.tribely.app/events?page=1&limit=20'},
      );
      final result = scrubBreadcrumb(bc, Hint());
      expect(result!.data!['url'], 'https://api.tribely.app/events');
    });

    test('returns breadcrumb unchanged when no url in data', () {
      final bc = makeBreadcrumb(data: {'key': 'value'});
      final result = scrubBreadcrumb(bc, Hint());
      expect(result, same(bc));
    });

    test('returns breadcrumb unchanged when url has no query string', () {
      final bc = makeBreadcrumb(
        data: {'url': 'https://api.tribely.app/events'},
      );
      final result = scrubBreadcrumb(bc, Hint());
      expect(result, same(bc));
    });

    test('returns null when breadcrumb is null', () {
      final result = scrubBreadcrumb(null, Hint());
      expect(result, isNull);
    });

    test('returns breadcrumb unchanged when data is null', () {
      final bc = makeBreadcrumb();
      final result = scrubBreadcrumb(bc, Hint());
      expect(result, same(bc));
    });

    test('returns breadcrumb unchanged when url is not a String', () {
      final bc = makeBreadcrumb(data: {'url': 42});
      final result = scrubBreadcrumb(bc, Hint());
      expect(result, same(bc));
    });

    test('preserves other data keys when stripping query', () {
      final bc = makeBreadcrumb(
        data: {
          'url': 'https://api.tribely.app/path?token=abc',
          'method': 'GET',
          'status_code': 200,
        },
      );
      final result = scrubBreadcrumb(bc, Hint());
      expect(result!.data!['method'], 'GET');
      expect(result.data!['status_code'], 200);
      expect(result.data!['url'], 'https://api.tribely.app/path');
    });
  });
}
