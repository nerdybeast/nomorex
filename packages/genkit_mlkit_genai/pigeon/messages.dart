import 'package:pigeon/pigeon.dart';

// The bridge between Dart and the ML Kit GenAI Prompt API (Gemini Nano). After
// editing, run ./scripts/gen.sh from the repo root and commit both outputs;
// scripts/check-generated.sh fails CI when they're stale.

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'genkit_mlkit_genai',
    dartOut: 'lib/src/messages.g.dart',
    kotlinOut: 'android/src/main/kotlin/com/nomorex/genkit_mlkit_genai/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.nomorex.genkit_mlkit_genai'),
  ),
)
/// Whether Gemini Nano can run, from ML Kit's `FeatureStatus`.
enum MlKitModelAvailability {
  available,

  /// The device supports it, but the model isn't on the device yet: a large
  /// download the lifter starts ([MlKitGenAiHostApi.startDownload]).
  downloadable,

  /// Downloading, started by this app or another one (AICore shares it).
  downloading,

  /// The device can't run it.
  unavailable,
}

class MlKitModelStatus {
  MlKitModelStatus({required this.availability, required this.sdkInt, required this.deviceModel});

  MlKitModelAvailability availability;

  /// Bytes so far and in all, while a download this app started runs.
  int? bytesDownloaded;
  int? bytesToDownload;

  /// Why the last download this app started failed, if it did.
  String? downloadError;

  /// Tokens the model takes in one request, once it's available.
  int? tokenLimit;

  int sdkInt;
  String deviceModel;
}

class MlKitGenerateRequest {
  MlKitGenerateRequest({required this.prompt, required this.maxOutputTokens});

  /// The whole prompt: ML Kit has no system role, so instructions come first.
  String prompt;
  double? temperature;

  /// Always set, like Apple's: an uncapped reply can run long.
  int maxOutputTokens;
}

class MlKitGenerateResponse {
  MlKitGenerateResponse({required this.text, required this.cutOff});

  String text;

  /// The reply stopped at `maxOutputTokens` (ML Kit's `MAX_TOKENS`).
  bool cutOff;

  /// The prompt's size, where ML Kit could count it.
  int? inputTokens;
}

/// Errors come back as `PlatformException`s whose code is one of:
/// `unavailable`, `tooLong`, `busy` or `failed`.
@HostApi()
abstract class MlKitGenAiHostApi {
  @async
  MlKitModelStatus status();

  /// Starts downloading the model and returns at once; [status] reports the
  /// progress. Does nothing while a download is already running.
  void startDownload();

  @async
  MlKitGenerateResponse generate(MlKitGenerateRequest request);
}
