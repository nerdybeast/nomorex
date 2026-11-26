// Loaded with `deferred as` from cloud_plugins.dart: on web each provider's
// SDK then downloads only when it's used (#183: +22 KB gzipped up front
// instead of +130 KB).
import 'package:flutter/foundation.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_anthropic/genkit_anthropic.dart';

GenkitPlugin plugin(String apiKey) => anthropic(
  apiKey: apiKey,
  // Anthropic refuses browser requests without this header. The key is the
  // lifter's own, held in their own browser.
  headers: kIsWeb ? const {'anthropic-dangerous-direct-browser-access': 'true'} : null,
);
