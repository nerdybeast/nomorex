import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/ai/core/ai_provider.dart';
import 'package:nomorex/features/ai/utils/ai_provider_info.dart';

void main() {
  test('maskKey shows the start and end only', () {
    expect(maskKey('AIzaSyAbCdEfGhIjKlMnQ7cE'), 'AIzaSy••••••••••••Q7cE');
    expect(maskKey('short-key'), '••••••••••••', reason: 'too short to show any of it');
  });

  test('onDeviceModelLabel names each platform model', () {
    expect(onDeviceModelLabel(isWeb: true), 'Chrome built-in AI');
    expect(onDeviceModelLabel(isWeb: false, platform: TargetPlatform.iOS), 'Apple Intelligence');
    expect(onDeviceModelLabel(isWeb: false, platform: TargetPlatform.macOS), 'Apple Intelligence');
    expect(onDeviceModelLabel(isWeb: false, platform: TargetPlatform.android), 'Gemini Nano');
    expect(onDeviceModelLabel(isWeb: false, platform: TargetPlatform.linux), isNull);
    expect(onDeviceModelLabel(isWeb: false, platform: TargetPlatform.windows), isNull);
  });

  test('every provider links to an https key page', () {
    for (final p in CloudAiProvider.values) {
      expect(p.getKeyUrl.scheme, 'https');
      expect(p.getKeyLabel, isNotEmpty);
    }
  });
}
