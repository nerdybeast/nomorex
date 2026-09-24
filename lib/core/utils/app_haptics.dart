import 'package:haptic_feedback/haptic_feedback.dart';

/// Thin wrapper over `haptic_feedback` so callers never have to care about
/// platform support (the plugin no-ops on web/desktop) or plugin errors.
class AppHaptics {
  const AppHaptics._();

  /// Light "selection" tick used for taps on interactive controls.
  static Future<void> tap() async {
    try {
      await Haptics.vibrate(HapticsType.selection);
    } catch (_) {
      // Haptics are decorative; never let a plugin failure surface to the user.
    }
  }
}
