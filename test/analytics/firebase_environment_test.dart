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

    test('no other flavor has a google-services.json (local and production send nothing)', () {
      for (final flavor in ['local', 'production']) {
        expect(File('android/app/src/$flavor/google-services.json').existsSync(), isFalse, reason: flavor);
      }
      expect(File('android/app/google-services.json').existsSync(), isFalse, reason: 'a root file would match every flavor');
    });
  });
}
