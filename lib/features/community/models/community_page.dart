/// What a paged Community list has loaded so far, and whether another page may
/// exist past it.
///
/// [hasMore] lives in the notifier's state, next to the items, rather than as a
/// notifier field: a screen that watches the provider then rebuilds when it
/// changes, instead of reading a value Riverpod doesn't know about.
class CommunityPage<T> {
  const CommunityPage(this.items, {required this.hasMore});

  final List<T> items;
  final bool hasMore;
}
