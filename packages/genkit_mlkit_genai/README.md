# genkit_mlkit_genai

Gemini Nano through the ML Kit GenAI Prompt API (beta), as a Genkit model, for
NoMoreX on Android (#190). Not published.

```dart
final status = await MlKitGenAi().status();
if (status.availability == MlKitModelAvailability.available) {
  defineMlKitGenAiModel(ai, status: status);
  // ai.generate(model: modelRef(kMlKitGenAiModel), ...)
}
```

- `pigeon/messages.dart` is the bridge. After editing it, run `./scripts/gen.sh`
  from the repo root and commit both outputs (`lib/src/messages.g.dart`,
  `android/.../Messages.g.kt`).
- `GenkitMlkitGenaiPlugin.kt` reports the status (with the progress of a
  download it started), starts the download, and generates. ML Kit's structured
  output is compile-time only, so the Dart side puts the output schema in the
  prompt and parses the JSON reply.
- `android/build.gradle.kts` declares no buildscript: the app's Gradle supplies
  the Android Gradle Plugin, and a second one on the classpath breaks the build.
- `flutter test` here runs the Dart side against a fake bridge. The Kotlin is
  compiled by the app's Android builds.
