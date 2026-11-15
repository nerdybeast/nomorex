import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../nav_section.dart';

part 'training_view_provider.g.dart';

/// The Training view used last, so the Training tab reopens on it, across
/// launches too. Starts at Programs and is saved on the device.
///
/// The saved view loads asynchronously; [lastUsed] waits for it, which is what
/// the bare Training route's redirect uses. If the device can't store it (or
/// in widget tests, where there's no platform plugin), it stays at Programs. Doesn't depend on the signed-in user: it's a device preference,
/// like the sidebar's collapsed state.
@Riverpod(keepAlive: true)
class TrainingViewNotifier extends _$TrainingViewNotifier {
  static const _key = 'training_view';

  /// Set once a view is chosen, so a slow first load can't undo it.
  bool _touched = false;

  late Future<void> _loading;

  @override
  TrainingView build() {
    _loading = _load();
    return TrainingView.programs;
  }

  /// The view to reopen, once the saved one has loaded.
  Future<TrainingView> lastUsed() async {
    await _loading;
    return state;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = TrainingView.fromSegment(prefs.getString(_key));
      if (!ref.mounted || _touched || saved == null) return;
      state = saved;
    } catch (_) {
      // No storage: keep the default.
    }
  }

  Future<void> set(TrainingView view) async {
    _touched = true;
    if (state == view) return;
    state = view;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, view.segment);
    } catch (_) {
      // Not saved; it still applies for this session.
    }
  }
}
