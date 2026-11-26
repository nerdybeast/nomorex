// The one rule for "the same exercise name" lives in the import pipeline
// package, so the app and the pipeline can't drift apart. It must match the
// database's `normalize_exercise_name()` and the AI function's
// `normalizeExerciseName()` (`ai_import/normalize.ts`).
export 'package:import_pipeline/import_pipeline.dart' show normalizeExerciseName;
