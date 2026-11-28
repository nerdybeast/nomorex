import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

import '../../programs/models/program.dart';
import '../../programs/utils/program_edit_summary.dart';
import '../../workouts/models/workout.dart';
import '../core/ai_generate.dart';
import '../core/ai_task.dart';

/// Which field a suggestion fills (Stage 9, #191).
enum SuggestField {
  title(AiTask.suggestTitle, maxLength: 40, maxOutputTokens: 48),
  description(AiTask.suggestDescription, maxLength: 300, maxOutputTokens: 160);

  const SuggestField(this.task, {required this.maxLength, required this.maxOutputTokens});

  final AiTask task;

  /// The longest suggestion kept; a longer reply is cut at a word.
  final int maxLength;

  /// The reply cap. On-device models loop when uncapped.
  final int maxOutputTokens;

  String get key => name;
}

/// What a suggestion describes.
enum SuggestSubject { workout, program }

/// The longest outline sent. On-device context windows are about 4,000
/// tokens (Gemini Nano), so a 12-week program is summarized, not listed.
const kSuggestOutlineMaxChars = 3000;

/// The workout as the model reads it: one line per exercise, as the editor
/// summarizes it ("Front squat: 5 × 3 · 75–80%").
String workoutOutline(Workout workout, String unit) => [
  for (final e in workout.exercises)
    '${e.exerciseName}: ${setsLine(e.exerciseName, [for (final s in e.sets) s.toEditableRow()], unit)}',
].join('\n');

/// The program as the model reads it: its shape, every exercise with how many
/// days it's on, then the weeks day by day until [kSuggestOutlineMaxChars].
String programOutline(Program program, String unit) {
  final weeks = program.weeks;
  final trainingDays = [
    for (final w in weeks)
      for (final d in w.days)
        if (!d.isRestDay && d.exercises.isNotEmpty) d,
  ];
  final perWeek = weeks.isEmpty ? 0 : (trainingDays.length / weeks.length).round();
  final counts = <String, int>{};
  for (final d in trainingDays) {
    for (final name in {for (final e in d.exercises) e.exerciseName}) {
      counts[name] = (counts[name] ?? 0) + 1;
    }
  }
  final byUse = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final out = StringBuffer()
    ..writeln('${weeks.length} ${weeks.length == 1 ? 'week' : 'weeks'}, about $perWeek training days a week.')
    ..writeln('Exercises (days on): ${byUse.map((e) => '${e.key} (${e.value})').join(', ')}.');
  for (final w in weeks) {
    final lines = StringBuffer()..writeln(weekTitle(w));
    for (final d in w.days) {
      if (d.isRestDay || d.exercises.isEmpty) continue;
      lines.writeln('  ${d.title}: ${d.exercises.map((e) => '${e.exerciseName} ${exerciseLine(e, unit)}').join('; ')}');
    }
    if (out.length + lines.length > kSuggestOutlineMaxChars) break;
    out.write(lines);
  }
  return out.toString().trim();
}

/// Whether there's anything to suggest from.
bool workoutHasOutline(Workout workout) => workout.exercises.isNotEmpty;
bool programHasOutline(Program program) => program.weeks.any((w) => w.days.any((d) => d.exercises.isNotEmpty));

const _system =
    'You write names and descriptions for strength-training workouts and programs in a lifting log. '
    'Use only what the outline shows: never invent exercises, loads, weeks or goals. '
    'Plain words: no quotes, emoji, hashtags, dates or marketing.';

String _instruction(SuggestField field, SuggestSubject subject) => switch (field) {
  SuggestField.title =>
    'Suggest a short name for this ${subject.name}: 2 to 5 words, at most ${field.maxLength} characters, '
        'naming its main lifts or focus.',
  SuggestField.description =>
    'Describe this ${subject.name} in one or two sentences, at most ${field.maxLength} characters, '
        'for the lifter who owns it: what it trains and how it is put together.',
};

SchemanticType<Map<String, dynamic>> _schema(SuggestField field) => SchemanticType.from<Map<String, dynamic>>(
  jsonSchema: {
    'type': 'object',
    'properties': {
      field.key: {'type': 'string'},
    },
    'required': [field.key],
  },
  parse: (json) => Map<String, dynamic>.from(json as Map),
);

/// Asks the on-device model on [route] for [field], from [outline]. Returns
/// the cleaned suggestion, or null when the model gave nothing usable.
/// Failures come out as `AiProviderException`, like every model call.
Future<String?> suggestText(
  Genkit ai,
  AiRoute route, {
  required SuggestField field,
  required SuggestSubject subject,
  required String outline,
}) async {
  final reply = await generateWithRoute(
    ai,
    route,
    system: _system,
    prompt: '${_instruction(field, subject)}\n\n${subject == SuggestSubject.workout ? 'Workout' : 'Program'}:\n$outline',
    outputSchema: _schema(field),
    config: {'maxOutputTokens': field.maxOutputTokens, 'temperature': 0.7},
    timeout: const Duration(seconds: 45),
  );
  final value = reply.output?[field.key];
  return value is String ? cleanSuggestion(value, field) : null;
}

/// Trims [text], drops wrapping quotes and a title's final full stop, and cuts
/// anything past [SuggestField.maxLength] at a word. Null when nothing's left.
String? cleanSuggestion(String text, SuggestField field) {
  var s = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  s = s.replaceAll(RegExp(r'^["“”\x27‘’]+|["“”\x27‘’]+$'), '').trim();
  if (field == SuggestField.title && s.endsWith('.')) s = s.substring(0, s.length - 1).trim();
  if (s.length > field.maxLength) {
    final cut = s.substring(0, field.maxLength);
    final space = cut.lastIndexOf(' ');
    s = (space > field.maxLength ~/ 2 ? cut.substring(0, space) : cut).trimRight();
    s = s.replaceAll(RegExp(r'[,;:\-–—]+$'), '');
  }
  return s.isEmpty ? null : s;
}
