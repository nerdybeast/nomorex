/// Shown in place of an author's name when they have not set a display name.
/// `profiles.display_name` is nullable on purpose — every account that existed
/// before the column did has none, and the fallback is preferable to
/// backfilling names nobody chose.
const String kAnonymousOwnerName = 'Anonymous lifter';

/// The author label to render for a piece of public content.
///
/// Also covers the case where the viewer cannot read the owner's profile at
/// all: the profiles SELECT policy only exposes a row to viewers who can
/// already see something that user published, so a `null` here means "no name
/// to show", never "the owner does not exist".
String ownerDisplayName(String? displayName) {
  final name = displayName?.trim();
  return (name == null || name.isEmpty) ? kAnonymousOwnerName : name;
}
