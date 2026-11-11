import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/percent_range.dart';
import '../../../core/utils/rpe.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/list_group.dart';
import '../../exercises/providers/exercises_provider.dart';
import '../../exercises/widgets/exercise_picker.dart';
import '../../workouts/utils/set_resolver.dart';
import '../models/ai_import_result.dart';
import '../providers/ai_import_review_provider.dart';
import '../utils/genkit_call.dart';
import '../utils/import_messages.dart';

/// Where "Review" leads for a finished import: a read-only preview of what was
/// read, with the few fixes a save needs (title, exercise matches, the unit of
/// unlabelled weights), then Accept, Discard, or a re-run as the other type.
///
/// Reached from the Home card and the import alert.
class AiImportReviewScreen extends ConsumerWidget {
  const AiImportReviewScreen({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final review = ref.watch(aiImportReviewProvider(jobId));
    return switch (review) {
      AsyncData(value: final r?) when r.status == 'ready' && r.result != null => _ReviewBody(
        key: ValueKey(r.jobId),
        review: r,
        result: r.result!,
      ),
      AsyncData(value: final r?) when r.status == 'accepted' => _Message(
        message: 'This import has already been saved.',
        action: (r.acceptedWorkoutId ?? r.acceptedProgramId) == null
            ? null
            : (
                label: r.acceptedProgramId != null ? 'Open program' : 'Open workout',
                onPressed: () => context.pushReplacement(
                  r.acceptedProgramId != null
                      ? AppConstants.routeProgramDetail(r.acceptedProgramId!)
                      : AppConstants.routeWorkoutDetail(r.acceptedWorkoutId!),
                ),
              ),
      ),
      AsyncData() => const _Message(message: 'This import is no longer available.'),
      AsyncError() => _Message(
        message: "Couldn't load this import. Check your connection and try again.",
        action: (label: 'Try again', onPressed: () => ref.invalidate(aiImportReviewProvider(jobId))),
      ),
      _ => Scaffold(
        appBar: AppBar(title: const Text('Review import')),
        body: const Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.message, this.action});

  final String message;
  final ({String label, VoidCallback onPressed})? action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review import')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, key: const Key('ai_import_review_message'), style: Theme.of(context).textTheme.bodyLarge),
            if (action case final a?) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: a.onPressed, child: Text(a.label)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewBody extends ConsumerStatefulWidget {
  const _ReviewBody({super.key, required this.review, required this.result});

  final AiImportReview review;
  final AiImportResult result;

  @override
  ConsumerState<_ReviewBody> createState() => _ReviewBodyState();
}

class _ReviewBodyState extends ConsumerState<_ReviewBody> {
  late final TextEditingController _title = TextEditingController(text: widget.result.title ?? '');
  late final List<ExerciseToCheck> _toCheck = widget.result.exercisesToCheck;
  late final bool _needsUnit = widget.result.needsUnit;
  final Map<String, ExerciseFix> _fixes = {};
  String? _unit;
  bool _busy = false;
  String? _error;

  AiImportResult get _result => widget.result;
  String get _thing => _result.isProgram ? 'program' : 'workout';
  String get _other => _result.isProgram ? 'workout' : 'program';
  bool get _canAccept => !_busy && (!_needsUnit || _unit != null);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final reviewed = buildReviewedPayload(_result.raw, title: _title.text, fixes: _fixes, unit: _unit);
      final saved = await ref.read(aiImportReviewProvider(widget.review.jobId).notifier).accept(reviewed);
      if (!mounted) return;
      final location = saved.programId != null
          ? AppConstants.routeProgramDetail(saved.programId!)
          : AppConstants.routeWorkoutDetail(saved.workoutId!);
      context.pushReplacement(location);
    } catch (e) {
      debugPrint('[ai_import] accept failed: $e');
      if (mounted) {
        setState(() {
          _busy = false;
          _error = "Couldn't save the $_thing. Your review is kept, so try again.";
        });
      }
    }
  }

  Future<void> _rerun() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Read it as a $_other?',
      message:
          'The files are read again as a $_other. This uses one of your imports, '
          'and what was read this time is replaced.',
      confirmLabel: 'Re-run',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(aiImportReviewProvider(widget.review.jobId).notifier).rerunAs(widget.review.importId, _other);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text("Reading your import again as a $_other. You'll be told when it's ready.")),
      );
      context.go(AppConstants.routeHome);
    } on GenkitFlowException catch (e) {
      final refused = const {'FAILED_PRECONDITION', 'RESOURCE_EXHAUSTED', 'INVALID_ARGUMENT'}.contains(e.status);
      if (mounted) {
        setState(() {
          _busy = false;
          _error = refused ? importRefusalMessage(e.message) : e.message;
        });
      }
    } catch (e) {
      debugPrint('[ai_import] re-run failed: $e');
      if (mounted) {
        setState(() {
          _busy = false;
          _error = "The import couldn't be re-run. Try again in a moment.";
        });
      }
    }
  }

  Future<void> _discard() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Discard this import?',
      message: "What was read is deleted and nothing is saved. The import it used isn't given back.",
      confirmLabel: 'Discard',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(aiImportReviewProvider(widget.review.jobId).notifier).discard();
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppConstants.routeHome);
      }
    } catch (e) {
      debugPrint('[ai_import] discard failed: $e');
      if (mounted) {
        setState(() {
          _busy = false;
          _error = "Couldn't discard the import. Try again.";
        });
      }
    }
  }

  Future<void> _fix(ExerciseToCheck item) async {
    final fix = await showDialog<ExerciseFix>(
      context: context,
      builder: (_) => _ExerciseFixDialog(item: item),
    );
    if (fix != null && mounted) setState(() => _fixes[item.key] = fix);
  }

  /// The preview's rows, built lazily so a long program stays quick.
  List<WidgetBuilder> _rows() {
    final rows = <WidgetBuilder>[
      (_) => _summary(),
      (_) => _titleField(),
      if (_needsUnit) (_) => _unitChoice(),
      if (_toCheck.isNotEmpty) (_) => _exercisesToCheck(),
      if (_result.unstructured.isNotEmpty) (_) => _unstructured(),
    ];
    if (_result.isProgram) {
      for (final (w, week) in _result.weeks.indexed) {
        rows.add((_) => _WeekHeader(label: week.label ?? 'Week ${w + 1}', index: w));
        for (final (d, day) in week.days.indexed) {
          rows.add((_) => _dayGroup(day, 'Day ${d + 1}'));
        }
      }
    } else {
      for (final day in _result.days) {
        rows.add((_) => _dayGroup(day, 'Exercises'));
      }
    }
    return rows;
  }

  Widget _summary() {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final weeks = _result.weeks.length;
    final training = _result.days.where((d) => d.exercises.isNotEmpty).length;
    final rest = _result.days.where((d) => d.isRestDay).length;
    final description = _result.isProgram
        ? [
            'Read as a program',
            '$weeks ${weeks == 1 ? 'week' : 'weeks'}',
            '$training training ${training == 1 ? 'day' : 'days'}',
            if (rest > 0) '$rest rest ${rest == 1 ? 'day' : 'days'}',
          ].join(' · ')
        : 'Read as a workout · ${_result.exercises.length} exercises';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(description, key: const Key('ai_import_review_summary'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Check what was read against your files, then save it.', style: muted),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              TextButton(
                key: const Key('ai_import_review_rerun'),
                onPressed: _busy ? null : _rerun,
                child: Text('Read it as a $_other instead'),
              ),
              Text('Uses one of your imports', style: theme.textTheme.bodySmall?.copyWith(color: muted?.color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _titleField() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      key: const Key('ai_import_review_title'),
      controller: _title,
      enabled: !_busy,
      maxLength: 200,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: 'Title',
        hintText: _result.isProgram ? 'Imported program' : 'Imported workout',
        counterText: '',
      ),
    ),
  );

  Widget _unitChoice() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ListGroup(
        header: const ListGroupHeader(title: 'UNITS'),
        children: [
          GroupableTile(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Some weights have no unit printed. Which unit are they in?', style: theme.textTheme.bodyLarge),
                const SizedBox(height: 4),
                Text(
                  'Only applies to those weights. Weights printed with a unit keep it.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  key: const Key('ai_import_review_unit'),
                  segments: const [
                    ButtonSegment(value: 'kg', label: Text('kg')),
                    ButtonSegment(value: 'lb', label: Text('lbs')),
                  ],
                  selected: {?_unit},
                  emptySelectionAllowed: true,
                  showSelectedIcon: false,
                  onSelectionChanged: _busy
                      ? null
                      : (s) {
                          if (s.isNotEmpty) setState(() => _unit = s.first);
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _exercisesToCheck() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: ListGroup(
      header: const ListGroupHeader(
        title: 'EXERCISES TO CHECK',
        subtitle: 'A fix applies everywhere the name appears.',
      ),
      children: [
        for (final (i, item) in _toCheck.indexed)
          _FixRow(
            key: Key('ai_import_review_check_$i'),
            buttonKey: Key('ai_import_review_fix_$i'),
            item: item,
            fix: _fixes[item.key],
            onFix: _busy ? null : () => _fix(item),
          ),
      ],
    ),
  );

  Widget _unstructured() {
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ListGroup(
        header: const ListGroupHeader(
          title: "COULDN'T BE STRUCTURED",
          subtitle: 'Saved as notes, in the original wording, on the week, day or exercise it belongs to.',
        ),
        children: [
          for (final (i, item) in _result.unstructured.indexed)
            GroupableTile(
              key: Key('ai_import_review_unstructured_$i'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.location case final location?) Text(location.toUpperCase(), style: tokens.eyebrow),
                  Text(item.originalText, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayGroup(ImportDay day, String fallback) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final weekday = day.weekday == null ? null : '${day.weekday![0].toUpperCase()}${day.weekday!.substring(1)}';
    final title = [?weekday, ?day.title].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ListGroup(
        header: ListGroupHeader(title: (title.isEmpty ? fallback : title).toUpperCase()),
        children: [
          if (day.isRestDay)
            GroupableTile(child: Text('Rest day', style: theme.textTheme.bodyLarge))
          else if (day.exercises.isEmpty)
            GroupableTile(child: Text('Nothing was read for this day.', style: muted)),
          if (day.notes case final notes?) GroupableTile(child: Text(notes, style: muted)),
          for (final exercise in day.exercises) _ExerciseTile(exercise: exercise, fixes: _fixes, unit: _unit),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    return Material(
      color: palette.bg1,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: palette.borderSubtle)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          // heightFactor keeps the bar its own height rather than the screen's.
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_result.handwritten) ...[
                    Container(
                      key: const Key('ai_import_review_handwritten'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: palette.primarySubtle,
                        borderRadius: BorderRadius.circular(NomorexSizes.radiusLg),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.edit_note, color: palette.primaryText),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This was handwritten. Check every weight against your page before training with it: '
                              'smudged numbers can be misread without being flagged.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_needsUnit && _unit == null) ...[
                    Text(
                      'Choose kg or lbs for the weights with no unit to save.',
                      key: const Key('ai_import_review_unit_hint'),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_error case final error?) ...[
                    Text(
                      error,
                      key: const Key('ai_import_review_error'),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      FilledButton(
                        key: const Key('ai_import_review_discard'),
                        // The theme's buttons are full width, which a Row can't lay out.
                        style: tokens.secondaryButtonStyle.copyWith(
                          minimumSize: const WidgetStatePropertyAll(Size(0, NomorexSizes.controlHeight)),
                        ),
                        onPressed: _busy ? null : _discard,
                        child: const Text('Discard'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: const Key('ai_import_review_accept'),
                          onPressed: _canAccept ? _accept : null,
                          child: _busy
                              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text('Save $_thing'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    return Scaffold(
      appBar: AppBar(title: const Text('Review import')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.max(16.0, (constraints.maxWidth - 720) / 2);
          return ListView.builder(
            key: const Key('ai_import_review_list'),
            padding: EdgeInsets.fromLTRB(side, 16, side, 24),
            itemCount: rows.length,
            itemBuilder: (context, i) => rows[i](context),
          );
        },
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.label, required this.index});

  final String label;
  final int index;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: index == 0 ? 0 : 8, bottom: 8),
    child: Text(label, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// What a name will be saved as, given the model's match and any fix.
({String text, bool warn}) _resolution(String name, ImportMatch? match, ExerciseFix? fix) => switch (fix) {
  UseExistingExercise(:final exercise) => (text: 'Saved as ${exercise.name}', warn: false),
  CreateCustomExercise(:final name) => (text: 'Saved as a new custom exercise, "$name"', warn: false),
  null => switch (match) {
    null => (text: 'Not in your exercises. Saved as a new custom exercise.', warn: true),
    ImportMatch(confidence: 'exact') => (text: '', warn: false),
    ImportMatch(confidence: 'high', :final name) => (text: 'Matched to $name', warn: false),
    ImportMatch(:final name) => (text: 'Best guess: $name. Check it.', warn: true),
  },
};

class _FixRow extends StatelessWidget {
  const _FixRow({super.key, required this.buttonKey, required this.item, required this.fix, required this.onFix});

  final Key buttonKey;
  final ExerciseToCheck item;
  final ExerciseFix? fix;
  final VoidCallback? onFix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    final status = _resolution(item.name, item.match, fix);
    return GroupableTile(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.occurrences > 1 ? '${item.name} (${item.occurrences} times)' : item.name,
                  style: theme.textTheme.bodyLarge,
                ),
                Text(
                  status.text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: status.warn ? tokens.palette.primaryText : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            key: buttonKey,
            style: tokens.secondaryButtonStyle.copyWith(
              minimumSize: const WidgetStatePropertyAll(Size(0, NomorexSizes.controlHeight)),
            ),
            onPressed: onFix,
            child: Text(
              fix == null ? 'Fix' : 'Change',
              semanticsLabel: '${fix == null ? 'Fix' : 'Change'} ${item.name}',
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.exercise, required this.fixes, required this.unit});

  final ImportExercise exercise;
  final Map<String, ExerciseFix> fixes;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final status = _resolution(exercise.name, exercise.match, fixes[exerciseKey(exercise.name)]);
    return GroupableTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exercise.name, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          if (status.text.isNotEmpty)
            Text(status.text, style: muted?.copyWith(color: status.warn ? tokens.palette.primaryText : null)),
          if (exercise.sets.isEmpty) Text('No sets were read.', style: muted),
          for (final set in exercise.sets) ...[const SizedBox(height: 4), _SetLine(set: set, fixes: fixes, unit: unit)],
          if (exercise.notes case final notes?) ...[const SizedBox(height: 4), Text(notes, style: muted)],
        ],
      ),
    );
  }
}

class _SetLine extends StatelessWidget {
  const _SetLine({required this.set, required this.fixes, required this.unit});

  final ImportSet set;
  final Map<String, ExerciseFix> fixes;
  final String? unit;

  static const _empty = '—';

  String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final unread = set.unreadable.toSet();

    final reps = set.reps == null
        ? (unread.contains('reps') ? _empty : null)
        : set.repsMax == null
        ? '${set.reps}'
        : '${set.reps}–${set.repsMax}';
    final count = unread.contains('sets') ? _empty : '${set.sets}';
    final volume = reps == null ? '$count ${set.sets == 1 ? 'set' : 'sets'}' : '$count × $reps';

    final spans = <InlineSpan>[TextSpan(text: volume)];
    if (set.percent != null) {
      spans.add(TextSpan(text: ' @ ${formatPercentTarget(set.percent, set.percentMax)}'));
      if (set.basisName case final basis?) {
        final fix = fixes[exerciseKey(basis)];
        final shown = switch (fix) {
          UseExistingExercise(:final exercise) => exercise.name,
          CreateCustomExercise(:final name) => name,
          null => set.basisMatch?.name ?? basis,
        };
        spans.add(TextSpan(text: ' of $shown'));
      }
    } else if (set.weight != null) {
      final shownUnit = switch (set.unit ?? unit) {
        'kg' => ' kg',
        'lb' => ' lbs',
        _ => ' (unit?)',
      };
      spans
        ..add(const TextSpan(text: ' @ '))
        ..add(TextSpan(text: '${_num(set.weight!)}$shownUnit', style: tokens.weight));
    } else if (set.openLoad) {
      spans.add(const TextSpan(text: ' · $kOpenLoadLabel'));
    } else if (unread.contains('load')) {
      spans.add(const TextSpan(text: ' @ $_empty'));
    }
    if (formatRpeTarget(set.rpeMin, set.rpeMax) case final rpe?) {
      spans.add(TextSpan(text: ' · $rpe'));
    } else if (unread.contains('rpe')) {
      spans.add(const TextSpan(text: ' · RPE $_empty'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(TextSpan(children: spans), style: theme.textTheme.bodyMedium),
        if (unread.isNotEmpty)
          Text(
            "Couldn't read: ${unread.join(', ')}",
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
        if (set.note case final note?) Text(note, style: muted),
      ],
    );
  }
}

/// Fixes one exercise name: pick one from the catalog, or save it as a new
/// custom exercise (the default for a combination lift like "2 Hang Clean +
/// 1 Jerk", which no catalog entry matches).
class _ExerciseFixDialog extends ConsumerStatefulWidget {
  const _ExerciseFixDialog({required this.item});

  final ExerciseToCheck item;

  @override
  ConsumerState<_ExerciseFixDialog> createState() => _ExerciseFixDialogState();
}

class _ExerciseFixDialogState extends ConsumerState<_ExerciseFixDialog> {
  late final TextEditingController _custom = TextEditingController(text: widget.item.name);

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _createCustom() {
    final name = _custom.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, CreateCustomExercise(name));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercises = ref.watch(exercisesProvider).value ?? const [];
    return AlertDialog(
      title: Text('Fix "${widget.item.name}"'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Use one of your exercises', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ExercisePicker(
                key: const Key('ai_import_fix_picker'),
                exercises: exercises,
                selected: null,
                onSelected: (e) => Navigator.pop(context, UseExistingExercise(e)),
                onAddCustom: (name) async => Navigator.pop(context, CreateCustomExercise(name)),
              ),
              const SizedBox(height: 24),
              Text('Or save it as a new custom exercise', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                "A custom exercise isn't linked to any other lift's PRs.",
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('ai_import_fix_custom_name'),
                controller: _custom,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Custom exercise name'),
                onSubmitted: (_) => _createCustom(),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  key: const Key('ai_import_fix_custom'),
                  onPressed: _createCustom,
                  child: const Text('Save as custom'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
    );
  }
}
