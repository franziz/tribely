import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

// Rule 17 (no extra device PII): sentry_flutter's default device context
// includes platform/OS/app-version only — no advertising id, precise geo, or
// contacts. Do NOT enable attachThreads or any extra device-data integration.

/// Regex patterns for PII redaction (Rule 18).
/// Mirrors Brief A's server-side regexes to maintain a consistent scrub floor.
final RegExp _emailRegex = RegExp(
  r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}',
);
final RegExp _sgPhoneRegex = RegExp(r'\+?65?\d{8,}');
final RegExp _intlPhoneRegex = RegExp(r'\+\d{7,15}');
final RegExp _tokenRegex = RegExp(
  r'eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+',
);

/// Scrubs a single string value of PII patterns (email, phone, token).
/// Returns a sanitised copy; never mutates the original.
String _scrub(String value) {
  return value
      .replaceAll(_emailRegex, '[redacted-email]')
      .replaceAll(_sgPhoneRegex, '[redacted-phone]')
      .replaceAll(_intlPhoneRegex, '[redacted-phone]')
      .replaceAll(_tokenRegex, '[redacted-token]');
}

/// Strips query strings from a URL string, if present.
/// Returns the original string unchanged when there is no query component.
String _stripQuery(String url) {
  try {
    final uri = Uri.parse(url);
    if (!uri.hasQuery) return url;
    // Rebuild without the query component. Using `Uri` constructor avoids the
    // trailing `?` that `uri.replace(query: '')` emits.
    return Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
      fragment: uri.hasFragment ? uri.fragment : null,
    ).toString();
  } catch (_) {
    return url;
  }
}

/// beforeSend hook: scrubs PII from event message, exception values, and
/// extra data, then tags the event as `stack:mobile` (Rule 18 + env tagging).
///
/// Exposed at library level for unit-testing without SDK initialisation.
/// In Sentry v9.x, SentryEvent fields are mutable — mutate in place.
SentryEvent? scrubEvent(SentryEvent event, Hint hint) {
  // Scrub top-level message.
  final rawMessage = event.message?.formatted;
  if (rawMessage != null) {
    event.message = SentryMessage(_scrub(rawMessage));
  }

  // Scrub exception values.
  event.exceptions?.forEach((ex) {
    final raw = ex.value;
    if (raw != null) ex.value = _scrub(raw);
  });

  // Scrub string values in event.extra.
  // extra is deprecated in v9.x in favour of Contexts, but the brief mandates
  // scrubbing it as a defensive measure for any consumers that still set it.
  // ignore: deprecated_member_use
  event.extra?.forEach((k, v) {
    if (v is String) {
      // ignore: deprecated_member_use
      event.extra![k] = _scrub(v);
    }
  });

  // Tag as mobile. Tags map is nullable; initialise if absent.
  (event.tags ??= {})['stack'] = 'mobile';

  return event;
}

/// beforeBreadcrumb hook: strips query strings from any `data['url']` field
/// (defensive Rule 16 scrub — practical surface is minimal since v1 wires no
/// SentryNavigatorObserver / HTTP instrumentation, but guards against future
/// print-breadcrumb leakage).
///
/// Exposed at library level for unit-testing without SDK initialisation.
/// The SDK passes a nullable Breadcrumb; null means already dropped — pass
/// through without modification.
Breadcrumb? scrubBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
  if (breadcrumb == null) return null;

  final data = breadcrumb.data;
  if (data == null || !data.containsKey('url')) return breadcrumb;

  final url = data['url'];
  if (url is! String) return breadcrumb;

  final stripped = _stripQuery(url);
  if (stripped == url) return breadcrumb;

  // Breadcrumb is immutable in the constructor sense; rebuild with stripped url.
  return Breadcrumb(
    message: breadcrumb.message,
    timestamp: breadcrumb.timestamp,
    category: breadcrumb.category,
    data: {...data, 'url': stripped},
    level: breadcrumb.level,
    type: breadcrumb.type,
  );
}

/// Initialises Sentry and runs [appRunner].
///
/// When [dsn] is blank (local dev / CI without secrets), Sentry is skipped
/// entirely and [appRunner] is called directly — no overhead, no errors.
Future<void> initSentry({
  required String dsn,
  required Future<void> Function() appRunner,
}) async {
  if (dsn.isEmpty) {
    await appRunner();
    return;
  }

  await SentryFlutter.init((options) {
    options.dsn = dsn;

    // ── Environment ──────────────────────────────────────────────────────
    options.environment = kReleaseMode ? 'production' : 'development';

    // ── Rule 14: no default PII ──────────────────────────────────────────
    options.sendDefaultPii = false;

    // ── Rule 15: no screenshots / view hierarchy ─────────────────────────
    // Defaults are already false; set explicitly per legal mandate.
    options.attachScreenshot = false;
    // attachViewHierarchy is experimental; set false explicitly per legal.
    // ignore: experimental_member_use
    options.attachViewHierarchy = false;

    // ── Rule 4: errors-only — no tracing, no session tracking ────────────
    // tracesSampleRate left at default (null/0) — do NOT set it.
    options.enableAutoSessionTracking = false;

    // ── Rule 16: breadcrumb scrub ─────────────────────────────────────────
    // Disable print/debugPrint breadcrumbs to eliminate the primary PII
    // surface in a v1 app without navigator/HTTP instrumentation.
    options.enablePrintBreadcrumbs = false;
    // Defensive query-string strip on any breadcrumb that carries a URL.
    options.beforeBreadcrumb = scrubBreadcrumb;

    // ── Rule 18: PII redaction on outbound events ────────────────────────
    options.beforeSend = scrubEvent;
  }, appRunner: appRunner);
}
