import 'owner_name.dart';

/// Shown on a workout or program the user imported from a file with AI.
const String kImportedLabel = 'Imported';

/// Shown when the original or its author no longer exists.
const String kCopiedFromUnknown = 'Copied from another user';

/// The "Copied from …" label for a saved copy, or null when the item isn't a
/// copy.
///
/// The author's name is a snapshot taken when the copy was made — the live
/// profile may no longer be readable once they stop sharing. It falls back to
/// a neutral label once either the author ([copiedFromUserId]) or the original
/// ([copiedFromSourceId]) has been removed. For workouts pass
/// `Workout.copiedFromSourceId`, which covers runs of a copied program. An
/// import is a copy with no author to credit, so [isImported] takes priority.
String? copyAttributionLabel({
  required bool isCopy,
  bool isImported = false,
  String? copiedFromUserId,
  String? copiedFromDisplayName,
  String? copiedFromSourceId,
}) {
  if (!isCopy) return null;
  if (isImported) return kImportedLabel;
  if (copiedFromUserId == null || copiedFromSourceId == null) return kCopiedFromUnknown;
  return 'Copied from ${ownerDisplayName(copiedFromDisplayName)}';
}
