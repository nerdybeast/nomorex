import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/environment/app_environment.dart';

/// Android, iOS and macOS each name the three environments in their own
/// project files. They have to agree, or one platform would install under
/// another's id (or share one with a different environment).
void main() {
  const production = 'com.nomorex.app';

  String xcconfigValue(String path, String key) {
    final match = RegExp('^$key = (.*)\$', multiLine: true).firstMatch(File(path).readAsStringSync());
    expect(match, isNotNull, reason: '$key in $path');
    return match!.group(1)!.trim();
  }

  String gradleSuffix(String flavor) {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final block = RegExp('create\\("$flavor"\\) \\{(.*?)\\n        \\}', dotAll: true).firstMatch(gradle);
    expect(block, isNotNull, reason: 'flavor $flavor in build.gradle.kts');
    return RegExp('applicationIdSuffix = "(.*?)"').firstMatch(block!.group(1)!)?.group(1) ?? '';
  }

  String gradleLabel(String flavor) {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final block = RegExp('create\\("$flavor"\\) \\{(.*?)\\n        \\}', dotAll: true).firstMatch(gradle)!;
    return RegExp('"appLabel"\\] = "(.*?)"').firstMatch(block.group(1)!)!.group(1)!;
  }

  for (final environment in AppEnvironment.values) {
    final name = environment.name;

    test('$name has the same application id on Android, iOS and macOS', () {
      final android = '$production${gradleSuffix(name)}';
      expect(xcconfigValue('ios/Flutter/Environment-$name.xcconfig', 'PRODUCT_BUNDLE_IDENTIFIER'), android);
      expect(xcconfigValue('macos/Runner/Configs/Environment-$name.xcconfig', 'PRODUCT_BUNDLE_IDENTIFIER'), android);
    });

    test('$name has the same display name on every platform', () {
      final android = gradleLabel(name);
      expect(xcconfigValue('ios/Flutter/Environment-$name.xcconfig', 'APP_DISPLAY_NAME'), android);
      expect(xcconfigValue('macos/Runner/Configs/Environment-$name.xcconfig', 'APP_DISPLAY_NAME'), android);
    });

    test('$name names its Firebase config folder after itself', () {
      expect(xcconfigValue('ios/Flutter/Environment-$name.xcconfig', 'APP_ENV_NAME'), name);
      expect(xcconfigValue('macos/Runner/Configs/Environment-$name.xcconfig', 'APP_ENV_NAME'), name);
    });
  }

  test('production keeps the plain application id', () {
    expect(gradleSuffix('production'), '');
    expect(xcconfigValue('ios/Flutter/Environment-production.xcconfig', 'PRODUCT_BUNDLE_IDENTIFIER'), production);
  });
}
