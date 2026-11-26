/// The AI import pipeline: the prompt, the file checks, the model call and
/// normalization into the result the app reviews. Pure Dart: no Flutter, so a
/// command-line tool can run it too (`tool/import_bench.dart`).
library;

export 'src/catalog.dart';
export 'src/exercise_name.dart';
export 'src/file_check.dart';
export 'src/normalize.dart';
export 'src/prompt.dart';
export 'src/run_import.dart';
