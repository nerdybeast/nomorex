import 'package:firebase_core/firebase_core.dart';

import '../../core/environment/app_environment.dart';
import '../../firebase_options.dart';

/// The Firebase project a build reports to, per environment. Each environment
/// has its own Firebase project, so data never mixes.
///
/// - [AppEnvironment.local]: none. Local builds send nothing, and don't start
///   Firebase at all.
/// - [AppEnvironment.beta]: the beta project (`lib/firebase_options.dart`).
/// - [AppEnvironment.production]: none yet. Its Firebase project is created at
///   launch; until then a production build runs without analytics.
///   Add its options here when it exists.
FirebaseOptions? firebaseOptionsFor(AppEnvironment environment) => switch (environment) {
  AppEnvironment.local => null,
  AppEnvironment.beta => DefaultFirebaseOptions.currentPlatform,
  AppEnvironment.production => null,
};
