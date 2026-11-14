/// The one rule for "the same exercise name": whitespace runs collapsed to a
/// single space, trimmed, lowercased. "  Clean   &  Jerk " and "clean & jerk"
/// are the same name; "Pull-Up" and "Pull Up" are not (that's what aliases
/// are for).
///
/// It must match the database's `normalize_exercise_name()` and the AI
/// function's `normalizeExerciseName()` (`ai_import/normalize.ts`), because
/// names matched here are also matched there: a PR recorded against a name
/// has to resolve the sets the server mapped by that name.
/// `exercise_name_test.dart` runs the same cases as `exercise_catalog.test.sql`.
String normalizeExerciseName(String name) => name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
