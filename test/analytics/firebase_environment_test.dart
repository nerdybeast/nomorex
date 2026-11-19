import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/environment/app_environment.dart';
import 'package:nomorex/features/analytics/firebase_environment.dart';
import 'package:nomorex/firebase_options.dart';

void main() {
  group('firebaseOptionsFor', () {
    test('local starts no Firebase', () {
      expect(firebaseOptionsFor(AppEnvironment.local), isNull);
    });

    test('production has no Firebase project yet, so it starts none', () {
      expect(firebaseOptionsFor(AppEnvironment.production), isNull);
    });
  });

  group('the beta Firebase project', () {
    // android/app/src/beta/google-services.json is what Gradle builds the
    // beta flavor with, and lib/firebase_options.dart is what Dart starts
    // Firebase with. They must describe the same app, and the beta file must
    // exist: the Gradle build is told to ignore a missing config, so nothing
    // else would notice it going missing.
    final file = File('android/app/src/beta/google-services.json');

    test('the beta flavor has its google-services.json', () {
      expect(file.existsSync(), isTrue, reason: 'regenerate it with `firebase apps:sdkconfig ANDROID <app id>`');
    });

    test('it has a client for the beta package and matches the Dart options', () {
      final config = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final clients = (config['client'] as List).cast<Map<String, dynamic>>();
      final beta = clients.singleWhere(
        (c) => (c['client_info'] as Map)['android_client_info']['package_name'] == 'com.nomorex.app.beta',
      );
      expect((config['project_info'] as Map)['project_id'], DefaultFirebaseOptions.android.projectId);
      expect((beta['client_info'] as Map)['mobilesdk_app_id'], DefaultFirebaseOptions.android.appId);
    });

    // The same for iOS and macOS: config/beta/GoogleService-Info.plist is what
    // a build phase copies into the beta app, and lib/firebase_options.dart is
    // what Dart starts Firebase with. macOS shares the iOS Firebase app.
    String plistValue(String path, String key) {
      final text = File(path).readAsStringSync();
      final match = RegExp('<key>$key</key>\\s*<string>(.*?)</string>').firstMatch(text);
      expect(match, isNotNull, reason: '$key in $path');
      return match!.group(1)!;
    }

    test('the iOS and macOS beta plists match the Dart options', () {
      for (final (platform, options) in [
        ('ios', DefaultFirebaseOptions.ios),
        ('macos', DefaultFirebaseOptions.macos),
      ]) {
        final plist = '$platform/config/beta/GoogleService-Info.plist';
        expect(File(plist).existsSync(), isTrue, reason: 'regenerate with `firebase apps:sdkconfig IOS <app id>`');
        expect(plistValue(plist, 'GOOGLE_APP_ID'), options.appId, reason: platform);
        expect(plistValue(plist, 'BUNDLE_ID'), 'com.nomorex.app.beta', reason: platform);
        expect(options.iosBundleId, 'com.nomorex.app.beta', reason: platform);
        expect(plistValue(plist, 'PROJECT_ID'), options.projectId, reason: platform);
      }
    });

    test('no other iOS or macOS environment has a Firebase config', () {
      for (final platform in ['ios', 'macos']) {
        for (final env in ['local', 'production']) {
          expect(File('$platform/config/$env/GoogleService-Info.plist').existsSync(), isFalse, reason: '$platform $env');
        }
        expect(
          File('$platform/Runner/GoogleService-Info.plist').existsSync(),
          isFalse,
          reason: '$platform: a bundled plist would reach every environment',
        );
      }
    });

    test('no other flavor has a google-services.json (local and production send nothing)', () {
      for (final flavor in ['local', 'production']) {
        expect(File('android/app/src/$flavor/google-services.json').existsSync(), isFalse, reason: flavor);
      }
      expect(File('android/app/google-services.json').existsSync(), isFalse, reason: 'a root file would match every flavor');
    });
  });
}
