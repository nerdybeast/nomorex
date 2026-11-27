import 'package:pigeon/pigeon.dart';

// The bridge between Dart and Apple's Foundation Models. After editing, run
//   dart run pigeon --input pigeon/messages.dart
// from this package and commit both outputs; scripts/check-generated.sh
// fails CI when they're stale.

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'genkit_apple_intelligence',
    dartOut: 'lib/src/messages.g.dart',
    swiftOut: 'darwin/genkit_apple_intelligence/Sources/genkit_apple_intelligence/Messages.g.swift',
  ),
)
/// Whether the system model can run, from `SystemLanguageModel.availability`.
enum AppleModelAvailability {
  available,

  /// The device can't run Apple Intelligence.
  deviceNotEligible,

  /// The device can, but it's turned off in Settings.
  appleIntelligenceNotEnabled,

  /// Turned on, but the model is still downloading or preparing.
  modelNotReady,

  /// Older than iOS 26 / macOS 26, which Foundation Models needs.
  unsupportedOS,

  /// Some other reason Apple added since.
  unavailable,
}

class AppleModelStatus {
  AppleModelStatus({required this.availability, required this.supportsImages, required this.osVersion});

  AppleModelAvailability availability;

  /// Tokens the model takes in and gives out together, where the OS says
  /// (iOS / macOS 26.4 and later).
  int? contextSize;

  /// Image input: iOS / macOS 27 and later.
  bool supportsImages;

  /// `major.minor.patch`, for diagnostics.
  String osVersion;
}

class AppleGenerateRequest {
  AppleGenerateRequest({required this.prompt, required this.maximumResponseTokens});

  String? instructions;
  String prompt;

  /// JSON Schema for structured output. Null for plain text.
  String? schemaJson;

  /// One image (JPEG, PNG or HEIC bytes); needs `supportsImages`.
  Uint8List? image;
  double? temperature;

  /// Always set: an uncapped run can loop until it fills the context.
  int maximumResponseTokens;
}

class AppleGenerateResponse {
  AppleGenerateResponse({required this.text, required this.schemaGaps});

  /// The reply, or the structured reply as JSON.
  String text;
  int? inputTokens;
  int? outputTokens;

  /// JSON Schema keywords the translation had to drop, for diagnostics.
  List<String> schemaGaps;
}

/// Errors come back as `PlatformException`s whose code is one of:
/// `unsupported`, `unavailable`, `schemaUnsupported`, `badImage`, `tooLong`,
/// `refused`, `rateLimited`, `unsupportedLanguage` or `failed`.
@HostApi()
abstract class AppleIntelligenceHostApi {
  AppleModelStatus status();

  @async
  AppleGenerateResponse generate(AppleGenerateRequest request);

  /// Tokens [text] takes as a prompt, or null before iOS / macOS 26.4.
  @async
  int? countTokens(String text);
}
