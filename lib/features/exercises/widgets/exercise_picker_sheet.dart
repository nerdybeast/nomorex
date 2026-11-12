import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../models/exercise.dart';
import '../providers/exercises_provider.dart';
import '../providers/recent_exercises_provider.dart';

/// Opens the exercise picker: a near-full-height bottom sheet on a phone, a
/// tall centered panel on a wider screen. The search field is pinned at the
/// top and results fill the rest, so the keyboard only ever covers the
/// bottom of the list.
///
/// Tapping an exercise calls [onPick], which saves it; the picker stays open
/// with the row spinning until that completes, closes on success, and shows
/// the failure inline otherwise, so nothing is dropped silently. Typing a name
/// with no exact match offers "Create …", which finds or creates the
/// exercise by name ([ExercisesNotifier.ensureExerciseByName]) before
/// handing it to [onPick].
///
/// [addedExerciseIds] marks lifts already in the workout or day as "Added";
/// they stay pickable, since a lift done twice in one session is normal.
Future<Exercise?> showExercisePickerSheet(
  BuildContext context, {
  required Future<void> Function(Exercise exercise) onPick,
  Set<String> addedExerciseIds = const {},
}) {
  final panel = ExercisePickerPanel(onPick: onPick, addedExerciseIds: addedExerciseIds);
  if (isMobile(context)) {
    return showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.92,
        // The sheet doesn't resize for the keyboard by itself; padding the
        // panel by the inset shortens the list instead of hiding its end.
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: panel,
        ),
      ),
    );
  }
  return showDialog<Exercise>(
    context: context,
    builder: (ctx) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
        ),
        child: SizedBox(width: 560, height: 640, child: panel),
      ),
    ),
  );
}

/// The picker's content, shared by the sheet and the dialog.
class ExercisePickerPanel extends ConsumerStatefulWidget {
  const ExercisePickerPanel({
    super.key,
    required this.onPick,
    this.addedExerciseIds = const {},
  });

  final Future<void> Function(Exercise exercise) onPick;
  final Set<String> addedExerciseIds;

  @override
  ConsumerState<ExercisePickerPanel> createState() => _ExercisePickerPanelState();
}

/// Stands in for the exercise being created while "Create …" saves.
const _creatingId = '__create__';

class _ExercisePickerPanelState extends ConsumerState<ExercisePickerPanel> {
  final _search = TextEditingController();
  String? _savingId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _query => _search.text.trim();

  Future<void> _save(String savingId, String name, Future<Exercise> Function() resolve) async {
    if (_savingId != null) return;
    setState(() {
      _savingId = savingId;
      _error = null;
    });
    try {
      final exercise = await resolve();
      await widget.onPick(exercise);
      if (mounted) Navigator.of(context).pop(exercise);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savingId = null;
        _error = "Couldn't add $name. Check your connection and try again.";
      });
    }
  }

  void _pick(Exercise exercise) => _save(exercise.id, exercise.name, () async => exercise);

  void _create(String name) => _save(
        _creatingId,
        name,
        () => ref.read(exercisesProvider.notifier).ensureExerciseByName(name),
      );

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final theme = Theme.of(context);
    final exercisesAsync = ref.watch(exercisesProvider);
    final recentIds = ref.watch(recentExerciseIdsProvider).asData?.value ?? const <String>[];

    return Material(
      color: palette.bg2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
            child: Row(
              children: [
                Expanded(child: Text('Add exercise', style: theme.textTheme.titleMedium)),
                IconButton(
                  tooltip: 'Close',
                  icon: Icon(Icons.close, color: palette.fg2),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              key: const Key('exercise_picker_search'),
              controller: _search,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search exercises',
                prefixIcon: Icon(Icons.search, color: palette.fg3),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: Icon(Icons.close, size: 18, color: palette.fg3),
                        onPressed: _search.clear,
                      ),
              ),
              onSubmitted: (_) {
                final exercises = exercisesAsync.asData?.value;
                if (exercises == null || _query.isEmpty) return;
                final results = searchExercises(exercises, _query);
                if (results.exact != null) {
                  _pick(results.exact!);
                } else if (results.matches.isNotEmpty) {
                  _pick(results.matches.first);
                } else {
                  _create(_query);
                }
              },
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                _error!,
                key: const Key('exercise_picker_error'),
                style: tokens.bodySmall.copyWith(color: palette.dangerText),
              ),
            ),
          Divider(height: 1, color: palette.borderSubtle),
          Expanded(
            child: exercisesAsync.when(
              loading: () => const _LoadingRows(key: Key('exercise_picker_loading')),
              error: (_, _) => _LoadError(onRetry: () => ref.invalidate(exercisesProvider)),
              data: (exercises) => _results(exercises, recentIds),
            ),
          ),
        ],
      ),
    );
  }

  Widget _results(List<Exercise> exercises, List<String> recentIds) {
    final entries = <Widget>[];
    final query = _query;
    bool busy(String id) => _savingId == id;
    final locked = _savingId != null;

    Widget row(Exercise e) => _ExerciseRow(
          key: ValueKey('exercise_picker_row_${e.id}'),
          exercise: e,
          query: query,
          added: widget.addedExerciseIds.contains(e.id),
          saving: busy(e.id),
          onTap: locked ? null : () => _pick(e),
        );

    if (query.isEmpty) {
      final byId = {for (final e in exercises) e.id: e};
      final recent = [
        for (final id in recentIds) ?byId[id],
      ];
      if (recent.isNotEmpty) {
        entries
          ..add(const _SectionLabel('Recent'))
          ..addAll(recent.map(row));
      }
      final all = [...exercises]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      entries
        ..add(const _SectionLabel('All exercises'))
        ..addAll(all.map(row));
    } else {
      final results = searchExercises(exercises, query);
      entries.addAll(results.matches.map(row));
      // Below the matches, so a partial name ("sna") reads as a search
      // first; on its own when nothing matches.
      if (results.exact == null) {
        entries.add(_CreateRow(
          name: query,
          saving: busy(_creatingId),
          onTap: locked ? null : () => _create(query),
        ));
      }
      if (results.matches.isEmpty) {
        final tokens = NomorexTokens.of(context);
        entries.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            'No exercise called "$query" yet. Creating it adds it to your exercises.',
            style: tokens.bodySmall,
          ),
        ));
      }
    }

    return ListView.builder(
      // The sheet already sits above the safe area; ListView would otherwise
      // pad itself by the inset a second time.
      padding: const EdgeInsets.only(bottom: 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: entries.length,
      itemBuilder: (_, i) => entries[i],
    );
  }
}

/// [exercises] whose name contains [query] (case-insensitive), names that
/// start with it first, each part A–Z; and the one whose name is exactly
/// [query], if any, which suppresses "Create …".
({List<Exercise> matches, Exercise? exact}) searchExercises(
  List<Exercise> exercises,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return (matches: exercises, exact: null);
  Exercise? exact;
  final prefix = <Exercise>[];
  final infix = <Exercise>[];
  for (final e in exercises) {
    final name = e.name.toLowerCase();
    if (name == q) exact ??= e;
    if (name.startsWith(q)) {
      prefix.add(e);
    } else if (name.contains(q)) {
      infix.add(e);
    }
  }
  int byName(Exercise a, Exercise b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());
  prefix.sort(byName);
  infix.sort(byName);
  return (matches: [...prefix, ...infix], exact: exact);
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Semantics(
        header: true,
        child: Text(text.toUpperCase(), style: tokens.eyebrow),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    super.key,
    required this.exercise,
    required this.query,
    required this.added,
    required this.saving,
    required this.onTap,
  });

  final Exercise exercise;
  final String query;
  final bool added;
  final bool saving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final base = Theme.of(context).textTheme.bodyLarge!.copyWith(color: palette.fg1);

    final Widget? trailing = saving
        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : added
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 16, color: palette.fg3),
                  const SizedBox(width: 4),
                  Text('Added', style: tokens.bodySmall.copyWith(color: palette.fg3)),
                ],
              )
            : null;

    return Semantics(
      button: true,
      label: [exercise.name, if (!exercise.isPredefined) 'custom', if (added) 'already added'].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    _highlight(exercise.name, query, base, base.copyWith(
                      color: palette.primaryText,
                      fontWeight: FontWeight.w600,
                    )),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!exercise.isPredefined) ...[
                  const SizedBox(width: 8),
                  _CustomTag(),
                ],
                if (trailing != null) ...[const SizedBox(width: 12), trailing],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [name] with the first case-insensitive occurrence of [query] in [match].
TextSpan _highlight(String name, String query, TextStyle base, TextStyle match) {
  final q = query.trim().toLowerCase();
  final at = q.isEmpty ? -1 : name.toLowerCase().indexOf(q);
  if (at < 0) return TextSpan(text: name, style: base);
  return TextSpan(style: base, children: [
    TextSpan(text: name.substring(0, at)),
    TextSpan(text: name.substring(at, at + q.length), style: match),
    TextSpan(text: name.substring(at + q.length)),
  ]);
}

class _CustomTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.palette.borderDefault),
      ),
      child: Text('CUSTOM', style: tokens.eyebrow),
    );
  }
}

/// "Create "Tall Clean"": the custom-exercise path, as a row in the results
/// rather than a second dialog.
class _CreateRow extends StatelessWidget {
  const _CreateRow({required this.name, required this.saving, required this.onTap});

  final String name;
  final bool saving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final text = Theme.of(context).textTheme.bodyLarge!;
    return Semantics(
      button: true,
      label: 'Create exercise $name',
      excludeSemantics: true,
      child: InkWell(
        key: const Key('exercise_picker_create'),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          color: palette.primarySubtle,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.add, size: 20, color: palette.primaryText),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'Create ', style: text.copyWith(color: palette.primaryText)),
                    TextSpan(
                      text: '"$name"',
                      style: text.copyWith(color: palette.fg1, fontWeight: FontWeight.w600),
                    ),
                  ]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (saving)
                const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingRows extends StatelessWidget {
  const _LoadingRows({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = NomorexTokens.of(context).palette;
    const widths = [0.42, 0.3, 0.55, 0.36, 0.48, 0.28];
    return Semantics(
      label: 'Loading exercises',
      child: ListView(
        padding: const EdgeInsets.only(top: 12),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final w in widths)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: w,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: palette.bg3,
                    borderRadius: BorderRadius.circular(NomorexSizes.radiusSm),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Couldn't load your exercises. Check your connection and try again.",
            textAlign: TextAlign.center,
            style: tokens.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: tokens.secondaryButtonStyle,
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
