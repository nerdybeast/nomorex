import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/telemetry/sentry_scrub.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const anthropicKey = 'sk-ant-api03-AbCdEfGhIjKlMnOpQrStUvWxYz0123456789';
const openaiKey = 'sk-proj-AbCdEfGhIjKlMnOpQrStUvWxYz0123456789';
const geminiKey = 'AIzaSyAbCdEfGhIjKlMnOpQrStUvWxYz01234567';

void main() {
  test('scrubs key headers in any case and leaves the rest', () {
    expect(
      scrubHeaders({
        'X-Api-Key': anthropicKey,
        'authorization': 'Bearer $openaiKey',
        'x-goog-api-key': geminiKey,
        'content-type': 'application/json',
      }),
      {
        'X-Api-Key': '[redacted]',
        'authorization': '[redacted]',
        'x-goog-api-key': '[redacted]',
        'content-type': 'application/json',
      },
    );
  });

  test('scrubs key= from URLs and query strings', () {
    expect(
      scrubQuery('https://generativelanguage.googleapis.com/v1beta/models/x:generate?key=$geminiKey&alt=sse'),
      'https://generativelanguage.googleapis.com/v1beta/models/x:generate?key=[redacted]&alt=sse',
    );
    expect(scrubQuery('alt=sse&key=$geminiKey'), 'alt=sse&key=[redacted]');
    expect(scrubQuery('https://example.com/a?monkey=1'), 'https://example.com/a?monkey=1');
  });

  test('scrubs keys that slip into free text', () {
    for (final key in [anthropicKey, openaiKey, geminiKey]) {
      final scrubbed = scrubText('Anthropic API error: invalid key $key (401)');
      expect(scrubbed, isNot(contains(key)));
      expect(scrubbed, contains('[redacted]'));
      expect(scrubbed, startsWith('Anthropic API error: invalid key'));
    }
    expect(scrubText('Authorization: Bearer abcdefghijklmnop'), isNot(contains('abcdefghijklmnop')));
    expect(scrubText('Back squat 5 × 5 @ 80%'), 'Back squat 5 × 5 @ 80%');
  });

  test('beforeSend scrubs the request, the message, the exceptions and breadcrumbs', () {
    final event = SentryEvent(
      message: SentryMessage('Request failed with $anthropicKey'),
      exceptions: [SentryException(type: 'GenkitException', value: 'OpenAI API error: $openaiKey')],
      request: SentryRequest(
        url: 'https://api.example.com/v1?key=$geminiKey',
        queryString: 'key=$geminiKey',
        headers: {'x-api-key': anthropicKey},
      ),
      breadcrumbs: [
        Breadcrumb.http(url: Uri.parse('https://api.example.com/v1?key=$geminiKey'), method: 'POST'),
      ],
    );

    final scrubbed = scrubEvent(event, Hint());
    final all = [
      scrubbed.message!.formatted,
      scrubbed.exceptions!.single.value,
      scrubbed.request!.url,
      scrubbed.request!.queryString,
      scrubbed.request!.headers.toString(),
      scrubbed.breadcrumbs!.single.data.toString(),
    ].join('\n');
    for (final key in [anthropicKey, openaiKey, geminiKey]) {
      expect(all, isNot(contains(key)));
    }
  });

  test('beforeBreadcrumb scrubs HTTP breadcrumbs and keeps the rest', () {
    final crumb = scrubBreadcrumb(
      Breadcrumb(
        message: 'GET with $geminiKey',
        data: {'url': 'https://x.test/?key=$geminiKey', 'status_code': 200, 'x-goog-api-key': geminiKey},
      ),
      Hint(),
    )!;
    expect(crumb.message, isNot(contains(geminiKey)));
    expect(crumb.data!['url'], 'https://x.test/?key=[redacted]');
    expect(crumb.data!['x-goog-api-key'], '[redacted]');
    expect(crumb.data!['status_code'], 200);
    expect(scrubBreadcrumb(null, Hint()), isNull);
  });
}
