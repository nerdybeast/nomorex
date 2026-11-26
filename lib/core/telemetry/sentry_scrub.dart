import 'package:sentry_flutter/sentry_flutter.dart';

/// Keeps lifters' AI keys out of Sentry (#185). The app calls providers
/// directly with the lifter's own key, so a failed request, breadcrumb or
/// error message could otherwise carry it.

const _redacted = '[redacted]';

/// Headers that carry a provider key: Anthropic, OpenAI and Gemini.
const _secretHeaders = {'x-api-key', 'authorization', 'x-goog-api-key'};

/// Query parameters that can carry one (Gemini accepts `key=`).
const _secretParams = {'key', 'api_key', 'apikey'};

/// What keys look like, for anything that slips into free text.
final _keyPattern = RegExp(
  r'sk-ant-[A-Za-z0-9_\-]{10,}'
  r'|sk-(?:proj-|svcacct-)?[A-Za-z0-9_\-]{20,}'
  r'|AIza[0-9A-Za-z_\-]{30,}'
  r'|(?<=[?&](?:key|api_key|apikey)=)[^&#\s]+'
  r'|(?<=\b(?:Bearer|x-api-key:|x-goog-api-key:)\s*)[A-Za-z0-9_\-.]{12,}',
  caseSensitive: false,
);

String scrubText(String text) => text.replaceAll(_keyPattern, _redacted);

String? _scrubNullable(String? text) => text == null ? null : scrubText(text);

Map<String, String> scrubHeaders(Map<String, String> headers) => {
  for (final e in headers.entries) e.key: _secretHeaders.contains(e.key.toLowerCase()) ? _redacted : e.value,
};

/// Redacts secret query parameters, in a full URL or a bare query string.
String scrubQuery(String text) => text.replaceAllMapped(
  RegExp(r'([?&]|^)([^=&#?]+)=([^&#]*)'),
  (m) => _secretParams.contains(Uri.decodeQueryComponent(m[2]!).toLowerCase())
      ? '${m[1]}${m[2]}=$_redacted'
      : m[0]!,
);

/// `beforeSend`: scrubs the request, the error text and every breadcrumb.
SentryEvent scrubEvent(SentryEvent event, Hint hint) {
  final request = event.request;
  if (request != null) {
    request.headers = scrubHeaders(request.headers);
    if (request.url != null) request.url = scrubQuery(request.url!);
    if (request.queryString != null) request.queryString = scrubQuery(request.queryString!);
  }
  final message = event.message;
  if (message != null) {
    message.formatted = scrubText(message.formatted);
    message.template = _scrubNullable(message.template);
  }
  for (final e in event.exceptions ?? const <SentryException>[]) {
    e.value = _scrubNullable(e.value);
  }
  final crumbs = event.breadcrumbs;
  if (crumbs != null) {
    event.breadcrumbs = [for (final b in crumbs) scrubBreadcrumb(b, hint)].whereType<Breadcrumb>().toList();
  }
  return event;
}

/// `beforeBreadcrumb`: scrubs the HTTP breadcrumbs Sentry records for every
/// request, and any message.
Breadcrumb? scrubBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
  if (breadcrumb == null) return null;
  breadcrumb.message = _scrubNullable(breadcrumb.message);
  final data = breadcrumb.data;
  if (data != null) breadcrumb.data = _scrubData(data);
  return breadcrumb;
}

Map<String, dynamic> _scrubData(Map<String, dynamic> data) => {
  for (final e in data.entries)
    e.key: switch (e.value) {
      _ when _secretHeaders.contains(e.key.toLowerCase()) || _secretParams.contains(e.key.toLowerCase()) => _redacted,
      final String s when e.key == 'url' || e.key == 'http.query' => scrubText(scrubQuery(s)),
      final String s => scrubText(s),
      final Map<String, dynamic> m => _scrubData(m),
      final other => other,
    },
};
