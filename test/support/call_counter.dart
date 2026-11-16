/// Counts calls a test fake receives.
///
/// A fake notifier holds one in a `final` field instead of exposing a mutable
/// `int`: riverpod_lint's `avoid_public_notifier_properties` flags any public
/// state on a notifier outside `state`, test fakes included.
class CallCounter {
  int _count = 0;

  int get count => _count;

  void call() => _count++;
}
