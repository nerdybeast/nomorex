# genkit_apple_intelligence

Apple Intelligence (Foundation Models) as a Genkit model, for NoMoreX on iOS
and macOS (#189). Not published.

```dart
final status = await AppleIntelligence().status();
if (status.availability == AppleModelAvailability.available) {
  defineAppleIntelligenceModel(ai, status: status);
  // ai.generate(model: modelRef(kAppleIntelligenceModel), ...)
}
```

- `pigeon/messages.dart` is the bridge. After editing it, run `./scripts/gen.sh`
  from the repo root and commit both outputs (`lib/src/messages.g.dart`,
  `darwin/.../Messages.g.swift`).
- `darwin/` holds the Swift: `GenkitAppleIntelligencePlugin.swift` (status,
  generation, token counts) and `SchemaConverter.swift` (JSON Schema to
  `DynamicGenerationSchema`).
- The app keeps its iOS 17 / macOS 12 deployment targets; Foundation Models is
  weak-linked and every use is behind `#available`.
- `flutter test` here runs the Dart side against a fake bridge. The Swift is
  compiled by the app's iOS and macOS builds.
