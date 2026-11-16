import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/percent_range.dart';
import '../../../core/utils/rep_range.dart';
import '../../../core/utils/rpe.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../shared/models/editable_set_row.dart';
import '../../../shared/models/set_type.dart';
import '../../../shared/widgets/action_sheet.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/set_pr_link.dart';
import '../../../shared/widgets/set_type_header.dart';
import '../../../shared/widgets/number_stepper_field.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/unit_toggle.dart';
import '../../../shared/models/one_rep_max.dart';
import '../../exercises/models/exercise.dart';
import '../../exercises/providers/exercises_provider.dart';
import '../providers/one_rep_max_provider.dart';
import '../utils/parsed_set.dart';
import '../utils/set_resolver.dart';

/// Editable list of sets for a single exercise, plus add controls. Works
/// against [EditableSetRow] rather than a concrete `WorkoutSet`/`ProgramSet`
/// so it's shared between editing a workout and authoring a program.
///
/// Sets are shown the way a coach writes them: one row per run of identical
/// consecutive sets ("3 × 3 · 60% of 1RM"), under a WARM-UP / WORKING /
/// COOL-DOWN header per run of one type (none when every set is working).
/// Tapping a row reopens the sets sheet filled in and saves the whole group
/// through [onReplaceGroup]; its ⋯ menu edits just the last set, changes the
/// type, moves the group, or removes it (asking first when it's more than one
/// set). Groups drag to reorder within their type. Every save that fails shows
/// a snackbar rather than failing silently.
class SetEditor extends ConsumerStatefulWidget {
  const SetEditor({
    super.key,
    required this.sets,
    required this.unit,
    required this.currentExerciseId,
    required this.currentExerciseName,
    required this.onAddPercentageSets,
    required this.onAddAbsoluteSets,
    required this.onReplaceGroup,
    required this.onReorderSets,
  });

  final List<EditableSetRow> sets;
  /// The user's unit preference ('kg', 'lbs', or 'both').
  final String unit;

  /// The exercise these sets belong to — the basis a percentage set resolves
  /// against when the "Based on" dropdown is left on "This exercise".
  final String currentExerciseId;
  final String currentExerciseName;
  final Future<void> Function(List<ParsedSet>) onAddPercentageSets;
  final Future<void> Function(AbsoluteSetBatch batch) onAddAbsoluteSets;

  /// Replaces [setIds] (one group, consecutive, of this exercise) with [count]
  /// sets of [prescription] in the same place; a count of 0 removes them.
  /// [prescription] uses the column names (`target_reps`, `weight_mode`,
  /// `absolute_weight_kg` in kg, `set_type`, …), as `replace_workout_set_group`
  /// and `replace_program_set_group` take it.
  final Future<void> Function(List<String> setIds, int count, Map<String, Object?> prescription) onReplaceGroup;
  final Future<void> Function(List<String> orderedSetIds) onReorderSets;

  @override
  ConsumerState<SetEditor> createState() => _SetEditorState();
}

/// Runs of identical consecutive sets. Every prescription column counts, the
/// note and set type included: the editor rewrites a group as copies of its
/// first set, so anything that differs must start a new group.
List<List<EditableSetRow>> groupEditableSets(List<EditableSetRow> sets) {
  bool same(EditableSetRow a, EditableSetRow b) =>
      a.weightMode == b.weightMode &&
      a.targetReps == b.targetReps &&
      a.targetRepsMax == b.targetRepsMax &&
      a.percentage == b.percentage &&
      a.percentageMax == b.percentageMax &&
      a.absoluteWeightKg == b.absoluteWeightKg &&
      a.rpeMin == b.rpeMin &&
      a.rpeMax == b.rpeMax &&
      a.basisExerciseId == b.basisExerciseId &&
      a.note == b.note &&
      a.setType == b.setType;
  final groups = <List<EditableSetRow>>[];
  for (final set in sets) {
    if (groups.isNotEmpty && same(groups.last.last, set)) {
      groups.last.add(set);
    } else {
      groups.add([set]);
    }
  }
  return groups;
}

/// A set's prescription as the group RPCs take it, optionally with a
/// different [type].
Map<String, Object?> _prescriptionOf(EditableSetRow s, {SetType? type}) => {
      'target_reps': s.targetReps,
      'target_reps_max': s.targetRepsMax,
      'weight_mode': s.weightMode,
      'percentage': s.percentage,
      'percentage_max': s.percentageMax,
      'absolute_weight_kg': s.absoluteWeightKg,
      'rpe_min': s.rpeMin,
      'rpe_max': s.rpeMax,
      'basis_exercise_id': s.basisExerciseId,
      'note': s.note,
      'set_type': (type ?? s.setType).dbValue,
    };

/// "3 × 3": the group's count by its reps.
String _groupLabel(List<EditableSetRow> group) =>
    '${group.length} × ${_repsText(group.first.targetReps ?? 1, group.first.targetRepsMax)}';

/// How a group is named to screen readers and in its menu: "3 warm-up sets
/// of 3 reps", "1 set of 5 reps".
String _groupName(List<EditableSetRow> group) {
  final first = group.first;
  final type = first.setType.isWorking ? '' : '${first.setType.label.toLowerCase()} ';
  final sets = group.length == 1 ? 'set' : 'sets';
  return '${group.length} $type$sets of ${formatTargetReps(first.targetReps, first.targetRepsMax)}';
}

class _SetEditorState extends ConsumerState<SetEditor> {
  /// The groups' first-set ids in a just-moved order, shown until the save
  /// comes back so the list doesn't snap back meanwhile.
  List<String>? _pendingOrder;

  void _failed() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't save the sets. Try again.")));
  }

  Future<void> _run(Future<void> Function() save) async {
    try {
      await save();
    } catch (_) {
      _failed();
    }
  }

  /// The flat set-id order with [group] moved to the end of [type]'s run
  /// (warm-ups, then working sets, then cool-downs), or null when it's
  /// already there. Within a type, the lifter's order is kept.
  List<String>? _orderForType(List<List<EditableSetRow>> all, List<EditableSetRow> group, SetType type) {
    final others = [...all]..remove(group);
    final at = others.lastIndexWhere((g) => g.first.setType.index <= type.index) + 1;
    final moved = [...others]..insert(at, group);
    final order = [for (final g in moved) ...g.map((s) => s.id)];
    final now = [for (final g in all) ...g.map((s) => s.id)];
    return const ListEquality<String>().equals(order, now) ? null : order;
  }

  /// Saves [ids] as [count] sets of [prescription]. When the type changes,
  /// the group first moves to its new type's run, then is rewritten in place.
  Future<void> _save(
    List<List<EditableSetRow>> all,
    List<EditableSetRow> group,
    List<String> ids,
    int count,
    Map<String, Object?> prescription,
  ) async {
    final type = SetType.fromDb(prescription['set_type']);
    if (type != group.first.setType) {
      final order = _orderForType(all, group, type);
      if (order != null) await widget.onReorderSets(order);
    }
    await widget.onReplaceGroup(ids, count, prescription);
  }

  Future<void> _edit(List<List<EditableSetRow>> all, List<EditableSetRow> group, {bool lastOnly = false}) async {
    final first = group.first;
    final ids = lastOnly ? [group.last.id] : [for (final s in group) s.id];
    // Editing one set of a group can only change that set, so it's rewritten
    // where it is rather than moved to another type's run.
    final initial = SetsSheetInitial(
      sets: lastOnly ? 1 : group.length,
      reps: first.targetReps ?? 1,
      repsMax: first.targetRepsMax,
      percentage: first.percentage,
      percentageMax: first.percentageMax,
      weightKg: first.absoluteWeightKg,
      basisExerciseId: first.basisExerciseId,
      basisExerciseName: first.basisExerciseName,
      rpeMin: first.rpeMin,
      rpeMax: first.rpeMax,
      setType: first.setType,
      lockCount: lastOnly,
    );
    // Failures surface inside the sheet (it stays open with what was
    // entered), so these saves aren't wrapped in _run.
    Future<void> save(int count, Map<String, Object?> rx) =>
        lastOnly ? widget.onReplaceGroup(ids, count, rx) : _save(all, group, ids, count, rx);
    if (first.weightMode == 'percentage') {
      final exercises = ref.read(exercisesProvider).asData?.value ?? const <Exercise>[];
      await showPercentageSetsSheet(
        context,
        exercises: exercises,
        currentExerciseId: widget.currentExerciseId,
        currentExerciseName: widget.currentExerciseName,
        unit: widget.unit,
        initial: initial,
        onSubmit: (sets) {
          final p = sets.first;
          return save(sets.length, {
            'target_reps': p.targetReps,
            'target_reps_max': p.targetRepsMax,
            'weight_mode': 'percentage',
            'percentage': p.percentage,
            'percentage_max': p.percentageMax,
            'basis_exercise_id': p.basisExerciseId,
            'rpe_min': p.rpeMin,
            'rpe_max': p.rpeMax,
            'set_type': p.setType.dbValue,
            'note': first.note,
          });
        },
      );
    } else {
      await showAbsoluteSetsSheet(
        context,
        currentExerciseName: widget.currentExerciseName,
        unit: widget.unit,
        initial: initial,
        onSubmit: (batch) => save(batch.sets, {
          'target_reps': batch.reps,
          'target_reps_max': batch.repsMax,
          'weight_mode': batch.weightKg == null ? 'open' : 'absolute',
          'absolute_weight_kg': batch.weightKg,
          'rpe_min': batch.rpeMin,
          'rpe_max': batch.rpeMax,
          'set_type': batch.setType.dbValue,
          'note': first.note,
        }),
      );
    }
  }

  Future<void> _remove(List<List<EditableSetRow>> all, List<EditableSetRow> group) async {
    if (group.length > 1) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Remove ${group.length} sets?',
        message: '${_groupLabel(group)} of ${widget.currentExerciseName} will be removed.',
        confirmLabel: 'Remove',
      );
      if (!confirmed || !mounted) return;
    }
    // Where the group sat, as a flat set index, so Undo can put it back.
    final at = [for (final g in all.takeWhile((g) => g != group)) ...g].length;
    try {
      await widget.onReplaceGroup([for (final s in group) s.id], 0, const {});
    } catch (_) {
      _failed();
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      key: const Key('set_editor_removed'),
      content: Text('Removed ${_groupLabel(group)}'),
      // An action keeps a snackbar up until dismissed unless persist is off.
      persist: false,
      action: SnackBarAction(label: 'Undo', onPressed: () => _run(() => _restore(group, at))),
    ));
  }

  /// Puts a removed group back exactly: re-adds its sets, moves them to where
  /// the group was, and rewrites them with its full prescription (note
  /// included, which adding can't carry).
  Future<void> _restore(List<EditableSetRow> group, int at) async {
    final first = group.first;
    final before = {for (final s in widget.sets) s.id};
    if (first.weightMode == 'percentage') {
      await widget.onAddPercentageSets([
        for (final _ in group)
          ParsedSet(
            first.targetReps ?? 1,
            first.percentage ?? 0,
            basisExerciseId: first.basisExerciseId,
            targetRepsMax: first.targetRepsMax,
            percentageMax: first.percentageMax,
            rpeMin: first.rpeMin,
            rpeMax: first.rpeMax,
            setType: first.setType,
          ),
      ]);
    } else {
      await widget.onAddAbsoluteSets(AbsoluteSetBatch(
        sets: group.length,
        reps: first.targetReps ?? 1,
        repsMax: first.targetRepsMax,
        weightKg: first.weightMode == 'open' ? null : first.absoluteWeightKg,
        rpeMin: first.rpeMin,
        rpeMax: first.rpeMax,
        setType: first.setType,
      ));
    }
    // The re-added rows arrive with the next build.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final added = [for (final s in widget.sets) if (!before.contains(s.id)) s.id];
    if (added.length != group.length) return;
    final rest = [for (final s in widget.sets) if (!added.contains(s.id)) s.id];
    final order = [...rest]..insertAll(at.clamp(0, rest.length), added);
    if (!const ListEquality<String>().equals(order, [for (final s in widget.sets) s.id])) {
      await widget.onReorderSets(order);
    }
    if (first.note != null) await widget.onReplaceGroup(added, group.length, _prescriptionOf(first));
  }

  Future<void> _reorder(List<List<EditableSetRow>> all, List<EditableSetRow> moved, int to) async {
    final order = [...all]..remove(moved);
    order.insert(to, moved);
    setState(() => _pendingOrder = [for (final g in order) g.first.id]);
    try {
      await widget.onReorderSets([for (final g in order) ...g.map((s) => s.id)]);
    } catch (_) {
      _failed();
    } finally {
      if (mounted) setState(() => _pendingOrder = null);
    }
  }

  Future<void> _showActions(
    List<List<EditableSetRow>> all,
    List<EditableSetRow> group, {
    required int? moveUpTo,
    required int? moveDownTo,
  }) async {
    final first = group.first;
    final otherTypes = [for (final type in SetType.values) if (type != first.setType) type];
    final action = await showActionSheet<String>(
      context,
      title: '${_groupLabel(group)} · ${widget.currentExerciseName}',
      actions: [
        SheetAction('edit', group.length == 1 ? 'Edit set' : 'Edit ${group.length} sets', Icons.edit_outlined),
        if (group.length > 1) const SheetAction('last', 'Edit the last set only', Icons.vertical_align_bottom),
        for (final (i, type) in otherTypes.indexed)
          SheetAction('type:${type.dbValue}', 'Mark as ${type.label.toLowerCase()} set', Icons.label_outline,
              dividerBefore: i == 0),
        if (moveUpTo != null) const SheetAction('up', 'Move up', Icons.arrow_upward, dividerBefore: true),
        if (moveDownTo != null)
          SheetAction('down', 'Move down', Icons.arrow_downward, dividerBefore: moveUpTo == null),
        SheetAction(
          'remove',
          group.length == 1 ? 'Remove set' : 'Remove ${group.length} sets',
          Icons.delete_outline,
          danger: true,
          dividerBefore: true,
        ),
      ],
    );
    if (!mounted || action == null) return;
    if (action.startsWith('type:')) {
      final type = SetType.fromDb(action.substring(5));
      await _run(() => _save(all, group, [for (final s in group) s.id], group.length, _prescriptionOf(first, type: type)));
      return;
    }
    switch (action) {
      case 'edit':
        await _edit(all, group);
      case 'last':
        await _edit(all, group, lastOnly: true);
      case 'up':
        await _reorder(all, group, moveUpTo!);
      case 'down':
        await _reorder(all, group, moveDownTo!);
      case 'remove':
        await _remove(all, group);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(exercisesProvider).asData?.value ?? const <Exercise>[];
    final byId = ref.watch(oneRepMaxProvider).asData?.value ?? const <String, OneRepMax>{};
    final byName = ref.watch(oneRepMaxByNameProvider).asData?.value ?? const <String, OneRepMax>{};
    final tokens = NomorexTokens.of(context);

    var groups = groupEditableSets(widget.sets);
    final pending = _pendingOrder;
    if (pending != null) {
      final byFirst = {for (final g in groups) g.first.id: g};
      if (pending.length == byFirst.length && pending.every(byFirst.containsKey)) {
        groups = [for (final id in pending) byFirst[id]!];
      }
    }

    // Runs of one type, each its own reorderable list, so a group drags
    // within its type and the headers never sit between draggable rows.
    final sections = <List<List<EditableSetRow>>>[];
    for (final g in groups) {
      if (sections.isNotEmpty && sections.last.last.first.setType == g.first.setType) {
        sections.last.add(g);
      } else {
        sections.add([g]);
      }
    }
    final showHeaders = sections.any((sec) => !sec.first.first.setType.isWorking);

    Widget row(List<EditableSetRow> group, int indexInSection, List<List<EditableSetRow>> section) {
      final set = group.first;
      final oneRepMax = set.weightMode == 'percentage'
          ? lookupOneRepMax(
              basisExerciseId: set.basisExerciseId ?? widget.currentExerciseId,
              basisExerciseName: set.basisExerciseName ?? widget.currentExerciseName,
              byExerciseId: byId,
              byExerciseName: byName,
            )
          : null;
      final at = groups.indexOf(group);
      final sectionStart = groups.indexOf(section.first);
      return _GroupRow(
        key: ValueKey(set.id),
        index: indexInSection,
        group: group,
        unit: widget.unit,
        oneRepMax: oneRepMax,
        basisExerciseId: set.basisExerciseId ?? widget.currentExerciseId,
        basisExerciseName: set.basisExerciseName ?? widget.currentExerciseName,
        onTap: () => _edit(groups, group),
        onMore: () => _showActions(
          groups,
          group,
          moveUpTo: indexInSection > 0 ? at - 1 : null,
          moveDownTo: indexInSection < section.length - 1 ? at + 1 : null,
        ),
        sectionStart: sectionStart,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in sections) ...[
          if (showHeaders)
            SetTypeHeader(
              key: ValueKey('set_editor_header_${section.first.first.id}'),
              type: section.first.first.setType,
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 2),
            ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: section.length,
            onReorderItem: (oldIndex, newIndex) {
              final sectionStart = groups.indexOf(section.first);
              _reorder(groups, section[oldIndex], sectionStart + newIndex);
            },
            itemBuilder: (context, i) => row(section[i], i, section),
          ),
        ],
        const SizedBox(height: 8),
        // Bordered secondary buttons rather than loose text links, so the
        // two ways to add sets read as actions. A Wrap, so a narrow card
        // stacks them instead of overflowing.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _AddSetsButton(
              label: 'Add sets (%)',
              icon: Icons.percent,
              tokens: tokens,
              onPressed: () => showPercentageSetsSheet(
                context,
                exercises: exercises,
                currentExerciseId: widget.currentExerciseId,
                currentExerciseName: widget.currentExerciseName,
                unit: widget.unit,
                onSubmit: widget.onAddPercentageSets,
              ),
            ),
            _AddSetsButton(
              label: 'Add sets (weight)',
              icon: Icons.fitness_center,
              tokens: tokens,
              onPressed: () => showAbsoluteSetsSheet(
                context,
                currentExerciseName: widget.currentExerciseName,
                unit: widget.unit,
                onSubmit: widget.onAddAbsoluteSets,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AddSetsButton extends StatelessWidget {
  const _AddSetsButton({
    required this.label,
    required this.icon,
    required this.tokens,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final NomorexTokens tokens;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: tokens.secondaryButtonStyle.copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
        textStyle: WidgetStatePropertyAll(tokens.buttonSmall),
        // 36px to look at, 48px to hit.
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

/// One group of identical sets, read like a ledger line: "3 × 3" (count by
/// reps, `fg-1` tabular), the prescription ("60% of 1RM · RPE 8"; a fixed
/// load in mono, "Choose load" in `fg-3`), and for a percentage group the
/// viewer has a 1RM for, the load it resolves to in blue mono. The load ends
/// the line when everything fits and drops under the prescription when it
/// doesn't. Tapping the text edits the group; the drag handle and ⋯ are
/// separate controls beside it, aligned with the first line.
class _GroupRow extends StatelessWidget {
  const _GroupRow({
    super.key,
    required this.index,
    required this.group,
    required this.unit,
    required this.oneRepMax,
    required this.onTap,
    required this.onMore,
    required this.sectionStart,
    required this.basisExerciseId,
    required this.basisExerciseName,
  });

  /// Position within its section (for the drag listener and the divider).
  final int index;
  final List<EditableSetRow> group;
  final String unit;
  final OneRepMax? oneRepMax;
  final VoidCallback onTap;
  final VoidCallback onMore;
  final int sectionStart;

  /// The lift a percentage group resolves against, for the "set PR" link
  /// when there's no 1RM.
  final String basisExerciseId;
  final String basisExerciseName;

  // Room for "10 × 8–12" on one line.
  static const _countWidth = 76.0;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium!;
    final set = group.first;
    final isPct = set.weightMode == 'percentage';
    final isOpen = isOpenLoad(set.weightMode);
    final valueLabel = isPct
        ? formatPercentTarget(set.percentage, set.percentageMax)
        : isOpen
            ? 'Choose load'
            : (set.absoluteWeightKg != null
                ? formatWeightForPreference(set.absoluteWeightKg!, unit)
                : (unit == 'both' ? '? lbs / ? kg' : '? $unit'));
    final basisLabel = set.basisExerciseId != null ? (set.basisExerciseName ?? '1RM') : '1RM';
    final loadPart = isPct ? '$valueLabel of $basisLabel' : valueLabel;
    final rpePart = formatRpeTarget(set.rpeMin, set.rpeMax);
    final prescription = [loadPart, ?rpePart].join(' · ');
    // Only a fixed load is mono; the RPE after it reads in Inter like the rest.
    final loadStyle0 = isPct
        ? body.copyWith(color: palette.fg1)
        : isOpen
            ? body.copyWith(color: palette.fg3)
            : tokens.weight.copyWith(color: palette.fg1);
    final prescriptionStyle = body.copyWith(color: palette.fg1);
    final prescriptionSpan = TextSpan(children: [
      TextSpan(text: loadPart, style: loadStyle0),
      if (rpePart != null) TextSpan(text: ' · $rpePart', style: body.copyWith(color: palette.fg2)),
    ]);
    final noOneRepMax = isPct && oneRepMax == null;
    final range = isPct && oneRepMax != null
        ? resolveSetWeightRangeKg(
            weightMode: set.weightMode,
            percentage: set.percentage,
            percentageMax: set.percentageMax,
            oneRepMaxKg: oneRepMax!.kg,
          )
        : null;
    final loadText = range == null
        ? null
        : formatResolvedWeightRange(range.low, range.high, unit, estimated: oneRepMax!.isEstimated);
    final loadStyle = tokens.weight.copyWith(color: palette.info);
    final countStyle = theme.textTheme.titleSmall!.copyWith(
      color: palette.fg1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final content = LayoutBuilder(
      builder: (context, constraints) {
        // The load ends the line only when the prescription and the load
        // both fit beside the count; otherwise it drops under the
        // prescription, indented to the same edge.
        var inline = true;
        if (loadText != null) {
          final scale = MediaQuery.textScalerOf(context);
          double width(String text, TextStyle style) =>
              (TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, textScaler: scale)
                    ..layout())
                  .width;
          final painter = TextPainter(text: prescriptionSpan, textDirection: TextDirection.ltr, textScaler: scale)
            ..layout();
          inline = _countWidth + painter.width + 12 + width(loadText, loadStyle) <= constraints.maxWidth;
        }
        final load = loadText == null
            ? null
            : Text(loadText, key: ValueKey('set_editor_resolved_${set.id}'), style: loadStyle);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: _countWidth, child: Text(_groupLabel(group), style: countStyle)),
                Expanded(child: Text.rich(prescriptionSpan, style: prescriptionStyle)),
                if (inline && load != null) ...[const SizedBox(width: 12), load],
              ],
            ),
            if (!inline && load != null)
              Padding(padding: const EdgeInsets.only(left: _countWidth, top: 2), child: load),
          ],
        );
      },
    );

    final name = _groupName(group);
    final spoken = [name, prescription, ?loadText, if (noOneRepMax) 'no 1RM yet'].join(', ');
    return DecoratedBox(
      decoration: BoxDecoration(
        border: index == 0 ? null : Border(top: BorderSide(color: palette.borderSubtle)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReorderableDragStartListener(
            index: index,
            // Hidden from screen readers: the list gives each group move
            // up/down actions, and the ⋯ menu has Move up / Move down.
            child: ExcludeSemantics(
              child: Tooltip(
                message: 'Drag to reorder',
                child: SizedBox(
                  width: 40,
                  height: 48,
                  child: Icon(Icons.drag_indicator, size: 20, color: palette.fg3),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
              container: true,
              button: true,
              label: '$spoken. Edit',
              excludeSemantics: true,
              child: InkWell(
                key: ValueKey('set_group_${set.id}'),
                onTap: onTap,
                hoverColor: palette.bg3,
                borderRadius: BorderRadius.circular(NomorexSizes.radiusMd),
                child: Padding(
                  // 14px puts the 20px first line on the 48px controls' center.
                  padding: EdgeInsets.fromLTRB(4, 14, 4, noOneRepMax ? 2 : 14),
                  child: content,
                ),
              ),
                ),
                // Said plainly rather than left blank, with the PR that would
                // resolve it; outside the row's button so it's reachable alone.
                if (noOneRepMax)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4 + _countWidth, 0, 4, 12),
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: 'No 1RM yet · ', style: tokens.bodySmall.copyWith(color: palette.fg3)),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: SetPrLink(
                            exerciseId: basisExerciseId,
                            exerciseName: basisExerciseName,
                            style: tokens.bodySmall,
                          ),
                        ),
                      ]),
                      key: ValueKey('set_editor_no_1rm_${set.id}'),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('set_group_more_${set.id}'),
            tooltip: 'Options for $name',
            icon: Icon(Icons.more_horiz, color: palette.fg3),
            onPressed: onMore,
          ),
        ],
      ),
    );
  }
}

/// The batch's set type, Working unless chosen otherwise. Three segments
/// announced by their labels, so a screen reader (and `getByRole`) finds
/// "Warm-up" directly.
class _SetTypeChoice extends StatelessWidget {
  const _SetTypeChoice({required this.value, required this.onChanged});

  final SetType value;
  final ValueChanged<SetType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SegmentedButton<SetType>(
        key: const Key('set_editor_set_type'),
        showSelectedIcon: false,
        segments: [
          for (final type in SetType.values)
            ButtonSegment<SetType>(
              value: type,
              label: Text(type.label, key: Key('set_editor_set_type_${type.dbValue}')),
            ),
        ],
        selected: {value},
        onSelectionChanged: (selection) => onChanged(selection.single),
      ),
    );
  }
}

/// Opens an "Add sets" sheet: a bottom sheet on a phone, a centered panel
/// on a wider screen. [builder] rebuilds through a [StatefulBuilder] as the
/// steppers change, so the preview reads back every tap.
Future<void> _showSetsSheet(
  BuildContext context,
  Widget Function(BuildContext ctx, StateSetter setState) builder,
) {
  Widget content() => StatefulBuilder(builder: builder);
  if (isMobile(context)) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Keeps the Add button above the keyboard while a value is typed.
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: content(),
      ),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: content(),
      ),
    ),
  );
}

/// The "Add sets" layout: a title, a live preview of what will be added,
/// the fields as hairline-divided rows, and Cancel / "Add 3 sets" pinned at
/// the bottom on the floor color.
class _SetsSheet extends StatelessWidget {
  const _SetsSheet({
    required this.title,
    this.editing = false,
    required this.sets,
    required this.preview,
    required this.fields,
    required this.onAdd,
    this.busy = false,
    this.error,
  });

  final String title;

  /// Editing an existing group: the button saves rather than adds.
  final bool editing;
  final int sets;
  final Widget preview;
  final List<Widget> fields;
  final VoidCallback onAdd;

  /// The save is in flight: the button spins and nothing can be pressed.
  final bool busy;

  /// Why the last save failed, shown above the buttons; the sheet stays open
  /// with everything as entered, so trying again is one tap.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    // A bottom sheet draws its own drag handle above this; a dialog doesn't.
    final inSheet = isMobile(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, inSheet ? 0 : 12, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: Icon(Icons.close, color: palette.fg2),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                preview,
                const SizedBox(height: 4),
                for (var i = 0; i < fields.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: palette.borderSubtle),
                  fields[i],
                ],
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: palette.bg0,
            border: Border(top: BorderSide(color: palette.borderSubtle)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, inSheet ? 16 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      error!,
                      key: const Key('set_editor_error'),
                      style: tokens.bodySmall.copyWith(color: palette.dangerText),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: tokens.secondaryButtonStyle,
                        onPressed: busy ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        key: const Key('set_editor_add'),
                        onPressed: busy ? null : onAdd,
                        child: busy
                            ? SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: palette.fg2),
                              )
                            : Text('${editing ? 'Save' : 'Add'} $sets ${sets == 1 ? 'set' : 'sets'}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The batch read back the way a coach writes it, on a `bg-1` card.
class _Preview extends StatelessWidget {
  const _Preview({required this.line, this.detail});

  final InlineSpan line;
  final Widget? detail;

  @override
  Widget build(BuildContext context) {
    final palette = NomorexTokens.of(context).palette;
    return Container(
      key: const Key('set_editor_preview'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: palette.bg1,
        borderRadius: BorderRadius.circular(NomorexSizes.radiusLg),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(line),
          if (detail != null) ...[const SizedBox(height: 6), detail!],
        ],
      ),
    );
  }
}

/// "8–10" or "5": reps on their own, for "3 × 8–10".
String _repsText(int reps, int? repsMax) =>
    repsMax == null || repsMax <= reps ? '$reps' : '$reps–$repsMax';

/// "100" or "102.5": a stepper value without a trailing ".0".
String _trimNumber(double v) {
  final text = v.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

/// "3 × 8–10 @ 70–75% · RPE 7": the count and reps in `fg-1`, the load in
/// orange ink, the RPE in `fg-2`. A null [load] reads "· choose load".
TextSpan _sentence(
  BuildContext context, {
  required int sets,
  required int reps,
  required int? repsMax,
  required String? load,
  bool loadIsMono = false,
  String? rpe,
  SetType setType = SetType.working,
}) {
  final tokens = NomorexTokens.of(context);
  final palette = tokens.palette;
  final base = Theme.of(context).textTheme.titleLarge!.copyWith(
        fontSize: 20,
        height: 26 / 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: palette.fg1,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
  return TextSpan(
    style: base,
    children: [
      if (!setType.isWorking)
        TextSpan(
          text: '${setType.label} · ',
          style: base.copyWith(color: palette.fg2, fontWeight: FontWeight.w500),
        ),
      TextSpan(text: '$sets × ${_repsText(reps, repsMax)}'),
      if (load == null)
        TextSpan(text: ' · choose load', style: base.copyWith(color: palette.fg3, fontWeight: FontWeight.w500))
      else
        TextSpan(
          style: base.copyWith(color: palette.primaryText),
          children: [
            const TextSpan(text: ' @ '),
            TextSpan(
              text: load,
              style: loadIsMono ? tokens.weightLg.copyWith(color: palette.primaryText) : null,
            ),
          ],
        ),
      if (rpe != null)
        TextSpan(text: ' · $rpe', style: base.copyWith(color: palette.fg2, fontWeight: FontWeight.w500)),
    ],
  );
}

/// The basis lift's 1RM for the viewer, id first then name (see
/// [lookupOneRepMax]). Watched rather than read in a callback: the providers
/// are `keepAlive` but lazy, so `.asData` would read "no 1RM" before they
/// load.
OneRepMax? _watchOneRepMax(WidgetRef ref, String basisExerciseId, String basisExerciseName) {
  final byId = ref.watch(oneRepMaxProvider).asData?.value ?? const <String, OneRepMax>{};
  final byName = ref.watch(oneRepMaxByNameProvider).asData?.value ?? const <String, OneRepMax>{};
  return lookupOneRepMax(
    basisExerciseId: basisExerciseId,
    basisExerciseName: basisExerciseName,
    byExerciseId: byId,
    byExerciseName: byName,
  );
}

/// The %1RM preview: the sentence, then the load it resolves to in blue
/// mono, or that there's no 1RM to resolve against.
class _PercentPreview extends ConsumerWidget {
  const _PercentPreview({
    required this.sets,
    required this.reps,
    required this.repsMax,
    required this.percentage,
    required this.percentageMax,
    required this.rpeMin,
    required this.rpeMax,
    required this.basisExerciseId,
    required this.basisExerciseName,
    required this.unit,
    this.setType = SetType.working,
  });

  final int sets;
  final int reps;
  final int? repsMax;
  final double percentage;
  final double? percentageMax;
  final double? rpeMin;
  final double? rpeMax;
  final String basisExerciseId;
  final String basisExerciseName;
  final String unit;
  final SetType setType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final oneRepMax = _watchOneRepMax(ref, basisExerciseId, basisExerciseName);
    final top = percentageMax != null && percentageMax! > percentage ? percentageMax : null;

    final Widget detail;
    if (oneRepMax == null) {
      detail = Text(
        'No 1RM recorded for this lift',
        style: tokens.bodySmall.copyWith(color: palette.fg3),
      );
    } else {
      final range = resolveSetWeightRangeKg(
        weightMode: 'percentage',
        percentage: percentage,
        percentageMax: top,
        oneRepMaxKg: oneRepMax.kg,
      )!;
      detail = Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 8,
        children: [
          Text(
            formatResolvedWeightRange(range.low, range.high, unit, estimated: oneRepMax.isEstimated),
            key: const Key('set_editor_preview_load'),
            style: tokens.weightLg.copyWith(color: palette.info),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text('each set', style: tokens.bodySmall),
          ),
        ],
      );
    }

    return _Preview(
      line: _sentence(
        context,
        sets: sets,
        reps: reps,
        repsMax: repsMax,
        load: formatPercentTarget(percentage, top),
        rpe: formatRpeTarget(rpeMin, rpeMax),
        setType: setType,
      ),
      detail: detail,
    );
  }
}

/// "Based on [Back Squat ▾]" with the basis 1RM on the right, the 1RM the
/// percentages resolve against. The picker is unrestricted: any exercise in
/// the catalog can be the basis.
class _BasisRow extends ConsumerWidget {
  const _BasisRow({
    required this.exercises,
    required this.value,
    required this.currentExerciseName,
    required this.basisExerciseId,
    required this.basisExerciseName,
    required this.unit,
    required this.onChanged,
  });

  final List<Exercise> exercises;
  final Exercise? value;
  final String currentExerciseName;
  final String basisExerciseId;
  final String basisExerciseName;
  final String unit;
  final ValueChanged<Exercise?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final oneRepMax = _watchOneRepMax(ref, basisExerciseId, basisExerciseName);
    final body = Theme.of(context).textTheme.bodyMedium!;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          Text('Based on', style: body.copyWith(color: palette.fg2)),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              height: 36,
              padding: const EdgeInsets.only(left: 12, right: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: palette.borderDefault),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Exercise?>(
                  key: const Key('set_editor_basis'),
                  value: value,
                  isDense: true,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(NomorexSizes.radiusLg),
                  icon: Icon(Icons.expand_more, size: 18, color: palette.fg2),
                  style: body.copyWith(color: palette.fg1, fontWeight: FontWeight.w500),
                  items: [
                    DropdownMenuItem<Exercise?>(
                      child: Text(currentExerciseName, overflow: TextOverflow.ellipsis),
                    ),
                    for (final ex in exercises)
                      DropdownMenuItem<Exercise?>(
                        value: ex,
                        child: Text(ex.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
          if (oneRepMax != null) ...[
            const SizedBox(width: 12),
            Text(
              '${oneRepMax.isEstimated ? 'Est. 1RM' : '1RM'} ${formatWeightForPreference(oneRepMax.kg, unit)}',
              style: tokens.weightSm.copyWith(color: oneRepMax.isEstimated ? palette.info : palette.fg2),
            ),
          ],
        ],
      ),
    );
  }
}

/// A field row: the label (plus [after], e.g. a One/Range toggle) on the
/// left and [trailing], usually a compact stepper, on the right. The label
/// and the stepper share one [Row], so the row reads as one field.
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, this.after, this.below, this.trailing});

  final String label;
  final Widget? after;
  final Widget? below;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    Widget left = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        if (after != null) ...[const SizedBox(width: 10), after!],
      ],
    );
    if (below != null) {
      left = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [left, const SizedBox(height: 6), below!],
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: below != null ? 10 : 0),
        child: Row(
          children: [
            left,
            const Spacer(),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// The sheet's stepper: just − value +, with the theme's stepper chrome at a
/// row-sized value.
Widget _compactStepper({
  Key? key,
  required String label,
  required double value,
  required double min,
  double? max,
  required double step,
  required int decimals,
  required NomorexTokens tokens,
  required ValueChanged<double> onChanged,
}) =>
    NumberStepperField(
      key: key,
      compact: true,
      label: label,
      value: value,
      min: min,
      max: max,
      step: step,
      decimals: decimals,
      onChanged: onChanged,
      valueTextStyle: tokens.stepperValue.copyWith(fontSize: 20, height: 26 / 20),
      valueDecoration: tokens.stepperValueDecoration,
      decrementButtonStyle: tokens.stepperDecrementStyle,
      incrementButtonStyle: tokens.stepperIncrementStyle,
    );

Widget _setsCountRow({required int sets, required ValueChanged<int> onChanged}) => Builder(
      builder: (context) => _FieldRow(
        label: 'Sets',
        trailing: _compactStepper(
          label: 'Sets',
          value: sets.toDouble(),
          min: 1,
          step: 1,
          decimals: 0,
          tokens: NomorexTokens.of(context),
          onChanged: (v) => onChanged(v.round()),
        ),
      ),
    );

/// The small ONE | RANGE toggle beside a field's label. One control, one
/// tap flips it; announced as a switch named [label] ("Rep range").
class _OneRangeToggle extends StatelessWidget {
  const _OneRangeToggle({super.key, required this.label, required this.isRange, required this.onChanged});

  final String label;
  final bool isRange;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    Widget segment(String text, bool on) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          color: on ? palette.primarySubtle : null,
          child: Text(text, style: tokens.weightXs.copyWith(color: on ? palette.primaryText : palette.fg3)),
        );
    return Semantics(
      label: label,
      toggled: isRange,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onChanged(!isRange),
        borderRadius: BorderRadius.circular(NomorexSizes.radiusSm),
        // 24px to look at, 48px to hit.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(NomorexSizes.radiusSm),
              border: Border.all(color: palette.borderDefault),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [segment('ONE', !isRange), segment('RANGE', isRange)],
            ),
          ),
        ),
      ),
    );
  }
}

/// The range top to save: null unless it's actually above [low], so a range
/// the author narrowed back down to one number is stored as a single value.
T? _rangeTop<T extends num>(T low, T? high) =>
    (high != null && high > low) ? high : null;

/// A field that's one value or a range ("7 to 9" reps, "67–72.5%"). The
/// label row carries a ONE | RANGE toggle and, for one value, the stepper;
/// a range drops to a second line of two steppers joined by "to". [max] is
/// null exactly when it's a single value.
class _RangeInput extends StatelessWidget {
  const _RangeInput({
    required this.value,
    required this.max,
    required this.label,
    required this.minLabel,
    required this.maxLabel,
    required this.switchLabel,
    required this.floor,
    this.ceiling,
    required this.step,
    required this.decimals,
    required this.spread,
    required this.valueKey,
    required this.switchKey,
    required this.maxKey,
    required this.onChanged,
    this.labelAction,
  });

  final double value;
  final double? max;
  /// Stepper names for assistive tech: [label] alone, [minLabel] /
  /// [maxLabel] as a range.
  final String label;
  final String minLabel;
  final String maxLabel;
  final String switchLabel;
  final double floor;
  final double? ceiling;
  final double step;
  final int decimals;
  /// How far above [value] the top starts when the range is turned on.
  final double spread;
  final Key valueKey;
  final Key switchKey;
  final Key maxKey;
  final void Function(double value, double? max) onChanged;
  /// Shown after the toggle, e.g. RPE's remove button.
  final Widget? labelAction;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final top = max;
    final low = _compactStepper(
      key: valueKey,
      label: top == null ? label : minLabel,
      value: value,
      min: floor,
      max: ceiling,
      step: step,
      decimals: decimals,
      tokens: tokens,
      // Raising the bottom of a range past its top drags the top along, so
      // the pair can never be saved inverted.
      onChanged: (v) => onChanged(v, top == null ? null : (top < v ? v : top)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldRow(
          label: label,
          after: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OneRangeToggle(
                key: switchKey,
                label: switchLabel,
                isRange: top != null,
                // The top starts [spread] above the bottom, never past
                // [ceiling].
                onChanged: (on) {
                  final c = ceiling;
                  final start = c != null && value + spread > c ? c : value + spread;
                  onChanged(value, on ? start : null);
                },
              ),
              ?labelAction,
            ],
          ),
          trailing: top == null ? low : null,
        ),
        if (top != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                low,
                Expanded(
                  child: Text(
                    'to',
                    textAlign: TextAlign.center,
                    style: tokens.bodySmall.copyWith(color: tokens.palette.fg3),
                  ),
                ),
                _compactStepper(
                  key: maxKey,
                  label: maxLabel,
                  value: top,
                  min: value,
                  max: ceiling,
                  step: step,
                  decimals: decimals,
                  tokens: tokens,
                  onChanged: (v) => onChanged(value, v),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// [_RangeInput] for a rep target: whole numbers from 1, starting a typical
/// two-rep spread ("7 to 9").
Widget _repTargetInput({
  required int reps,
  required int? repsMax,
  required void Function(int reps, int? repsMax) onChanged,
}) =>
    _RangeInput(
      value: reps.toDouble(),
      max: repsMax?.toDouble(),
      label: 'Reps',
      minLabel: 'Min reps',
      maxLabel: 'Max reps',
      switchLabel: 'Rep range',
      floor: 1,
      step: 1,
      decimals: 0,
      spread: 2,
      valueKey: const Key('set_editor_reps'),
      switchKey: const Key('set_editor_rep_range_switch'),
      maxKey: const Key('set_editor_reps_max'),
      onChanged: (v, max) => onChanged(v.round(), max?.round()),
    );

/// Optional target effort for a batch. Off, it's an "Add target RPE" link;
/// on, an RPE field (1–10 in half steps, starting at 7) with its own range
/// toggle ("RPE 6–7") and a remove button. [rpeMin] is null exactly when no
/// RPE is prescribed. The `set_editor_rpe_switch` key is on whichever
/// control turns it on or off.
class _RpeTargetInput extends StatelessWidget {
  const _RpeTargetInput({
    required this.rpeMin,
    required this.rpeMax,
    required this.onChanged,
  });

  final double? rpeMin;
  final double? rpeMax;
  final void Function(double? rpeMin, double? rpeMax) onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = NomorexTokens.of(context).palette;
    final min = rpeMin;
    if (min == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          toggled: false,
          child: TextButton.icon(
            key: const Key('set_editor_rpe_switch'),
            style: TextButton.styleFrom(
              foregroundColor: palette.primaryText,
              padding: const EdgeInsets.symmetric(horizontal: 0),
            ),
            onPressed: () => onChanged(7, null),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add target RPE'),
          ),
        ),
      );
    }
    return _RangeInput(
      value: min,
      max: rpeMax,
      label: 'RPE',
      minLabel: 'Min RPE',
      maxLabel: 'Max RPE',
      switchLabel: 'RPE range',
      floor: kRpeMin,
      ceiling: kRpeMax,
      step: kRpeStep,
      decimals: 1,
      spread: 1,
      valueKey: const Key('set_editor_rpe'),
      switchKey: const Key('set_editor_rpe_range_switch'),
      maxKey: const Key('set_editor_rpe_max'),
      onChanged: onChanged,
      labelAction: IconButton(
        key: const Key('set_editor_rpe_switch'),
        tooltip: 'Remove target RPE',
        icon: Icon(Icons.close, size: 18, color: palette.fg3),
        onPressed: () => onChanged(null, null),
      ),
    );
  }
}

/// What an existing group of identical sets prescribes, to open a sets
/// sheet pre-filled for editing it.
class SetsSheetInitial {
const SetsSheetInitial({
  required this.sets,
  required this.reps,
  this.repsMax,
  this.percentage,
  this.percentageMax,
  this.weightKg,
  this.basisExerciseId,
  this.basisExerciseName,
  this.rpeMin,
  this.rpeMax,
  this.setType = SetType.working,
  this.lockCount = false,
});

final int sets;
final int reps;
final int? repsMax;
final double? percentage;
final double? percentageMax;

/// Null for an open load.
final double? weightKg;

/// Null when the 1RM is the exercise's own.
final String? basisExerciseId;
final String? basisExerciseName;
final double? rpeMin;
final double? rpeMax;
final SetType setType;

/// Editing exactly [sets] sets ("Edit the last set only"): the sheet hides the
/// Sets stepper, so editing one set can't quietly add more.
final bool lockCount;
}

/// The "%1RM" sets sheet. Adds a batch, or with [initial] edits an existing
/// group: it opens filled in, reads "Save" and hands back the whole group.
/// [onSubmit] gets one [ParsedSet] per set, all alike.
Future<void> showPercentageSetsSheet(
BuildContext context, {
required List<Exercise> exercises,
required String currentExerciseId,
required String currentExerciseName,
required String unit,
required FutureOr<void> Function(List<ParsedSet> sets) onSubmit,
SetsSheetInitial? initial,
}) async {
  var sets = initial?.sets ?? 1;
  var reps = initial?.reps ?? 1;
  int? repsMax = initial?.repsMax;
  var percentage = initial?.percentage ?? 70.0;
  double? percentageMax = initial?.percentageMax;
  double? rpeMin = initial?.rpeMin;
  double? rpeMax = initial?.rpeMax;
  var setType = initial?.setType ?? SetType.working;
  // The dropdown matches by identity, so the basis has to be one of its
  // entries; a basis missing from the catalog (another user's lift on a
  // copy) is added so editing doesn't silently reset it.
  var pickable = exercises;
  Exercise? basisExercise;
  final basisId = initial?.basisExerciseId;
  if (basisId != null && basisId != currentExerciseId) {
    basisExercise = exercises.where((e) => e.id == basisId).firstOrNull;
    if (basisExercise == null) {
      basisExercise = Exercise(id: basisId, name: initial?.basisExerciseName ?? 'Other lift', isPredefined: false);
      pickable = [basisExercise, ...exercises];
    }
  }
  final editing = initial != null;
  var busy = false;
  String? error;

  await _showSetsSheet(
    context,
    (ctx, setState) => _SetsSheet(
      title: '${editing ? 'Edit sets' : 'Add sets'} · $currentExerciseName',
      editing: editing,
      sets: sets,
      busy: busy,
      error: error,
      preview: _PercentPreview(
        sets: sets,
        reps: reps,
        repsMax: repsMax,
        percentage: percentage,
        percentageMax: percentageMax,
        rpeMin: rpeMin,
        rpeMax: rpeMax,
        basisExerciseId: basisExercise?.id ?? currentExerciseId,
        basisExerciseName: basisExercise?.name ?? currentExerciseName,
        unit: unit,
        setType: setType,
      ),
      fields: [
        _SetTypeChoice(value: setType, onChanged: (v) => setState(() => setType = v)),
        _BasisRow(
          exercises: pickable,
          value: basisExercise,
          currentExerciseName: currentExerciseName,
          basisExerciseId: basisExercise?.id ?? currentExerciseId,
          basisExerciseName: basisExercise?.name ?? currentExerciseName,
          unit: unit,
          onChanged: (v) => setState(() => basisExercise = v),
        ),
        if (!(initial?.lockCount ?? false)) _setsCountRow(sets: sets, onChanged: (v) => setState(() => sets = v)),
        _repTargetInput(
          reps: reps,
          repsMax: repsMax,
          onChanged: (r, max) => setState(() {
            reps = r;
            repsMax = max;
          }),
        ),
        // One %1RM (or range) shared by the whole batch keeps the sheet a
        // fixed height; wave-loading is another batch at the next
        // percentage. One decimal so half-percent prescriptions like 72.5%
        // can be typed; the +/- step stays 5.
        _RangeInput(
          value: percentage,
          max: percentageMax,
          label: '%1RM',
          minLabel: 'Min %1RM',
          maxLabel: 'Max %1RM',
          switchLabel: '%1RM range',
          // The database accepts above 0 and up to 200% (#36), the same
          // bounds an AI import accepts.
          floor: kMinSetPercentage,
          ceiling: kMaxSetPercentage,
          step: 5,
          decimals: 1,
          spread: 5,
          valueKey: const Key('set_editor_pct'),
          switchKey: const Key('set_editor_pct_range_switch'),
          maxKey: const Key('set_editor_pct_max'),
          onChanged: (v, max) => setState(() {
            percentage = v;
            percentageMax = max;
          }),
        ),
        _RpeTargetInput(
          rpeMin: rpeMin,
          rpeMax: rpeMax,
          onChanged: (min, max) => setState(() {
            rpeMin = min;
            rpeMax = max;
          }),
        ),
      ],
      onAdd: () => _submitSheet(ctx, setState, (b, e) {
        busy = b;
        error = e;
      }, () => onSubmit([
          for (var i = 0; i < sets; i++)
            ParsedSet(
              reps,
              percentage,
              basisExerciseId: basisExercise?.id,
              targetRepsMax: _rangeTop(reps, repsMax),
              percentageMax: _rangeTop(percentage, percentageMax),
              rpeMin: rpeMin,
              rpeMax: rpeMin == null ? null : _rangeTop(rpeMin!, rpeMax),
              setType: setType,
            ),
        ])),
    ),
  );
}

/// Runs a sheet's save and keeps the sheet open until it resolves: the
/// button spins meanwhile, a failure shows in the sheet with everything still
/// entered, and only a success closes it.
Future<void> _submitSheet(
  BuildContext ctx,
  StateSetter setState,
  void Function(bool busy, String? error) setStatus,
  FutureOr<void> Function() save,
) async {
  setState(() => setStatus(true, null));
  try {
    await save();
    if (ctx.mounted) Navigator.pop(ctx);
  } catch (_) {
    if (ctx.mounted) setState(() => setStatus(false, "Couldn't save the sets. Check your connection and try again."));
  }
}

/// The "weight" sets sheet: a fixed load or none ("No set load"). Adds a
/// batch, or with [initial] edits an existing group.
Future<void> showAbsoluteSetsSheet(
BuildContext context, {
required String currentExerciseName,
required String unit,
required FutureOr<void> Function(AbsoluteSetBatch batch) onSubmit,
SetsSheetInitial? initial,
}) async {
  var sets = initial?.sets ?? 1;
  var reps = initial?.reps ?? 1;
  int? repsMax = initial?.repsMax;
  var openLoad = initial != null && initial.weightKg == null;
  double? rpeMin = initial?.rpeMin;
  double? rpeMax = initial?.rpeMax;
  var setType = initial?.setType ?? SetType.working;
  var dialogUnit = unit == 'both' ? 'kg' : unit;
  final initialKg = initial?.weightKg ?? 0.0;
  var weightDisplay = dialogUnit == 'lbs' ? kgToLbs(initialKg) : initialKg;
  final editing = initial != null;
  var busy = false;
  String? error;

  await _showSetsSheet(
    context,
    (ctx, setState) {
      final tokens = NomorexTokens.of(ctx);
      final weightLabel = 'Weight ($dialogUnit)';
      return _SetsSheet(
        title: '${editing ? 'Edit sets' : 'Add sets'} · $currentExerciseName',
        editing: editing,
        sets: sets,
        busy: busy,
        error: error,
        preview: _Preview(
          line: _sentence(
            ctx,
            sets: sets,
            reps: reps,
            repsMax: repsMax,
            load: openLoad ? null : '${_trimNumber(weightDisplay)} $dialogUnit',
            loadIsMono: true,
            rpe: formatRpeTarget(rpeMin, rpeMax),
            setType: setType,
          ),
          detail: openLoad
              ? Text('The lifter picks the weight on the day', style: tokens.bodySmall)
              : null,
        ),
        fields: [
          _SetTypeChoice(value: setType, onChanged: (v) => setState(() => setType = v)),
          if (!(initial?.lockCount ?? false)) _setsCountRow(sets: sets, onChanged: (v) => setState(() => sets = v)),
          _repTargetInput(
            reps: reps,
            repsMax: repsMax,
            onChanged: (r, max) => setState(() {
              reps = r;
              repsMax = max;
            }),
          ),
          // "Vert Pull 3x7-9, %1RM NA": no prescribed load, the lifter
          // picks it on the day. Hides the weight rather than saving a
          // misleading 0 kg.
          SwitchListTile(
            key: const Key('set_editor_open_load_switch'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('No set load'),
            subtitle: Text('The lifter picks the weight', style: tokens.bodySmall),
            value: openLoad,
            onChanged: (on) => setState(() => openLoad = on),
          ),
          if (!openLoad)
            _FieldRow(
              label: weightLabel,
              // Under the label rather than beside it: beside it, the
              // label, toggle and stepper don't fit a phone's row.
              below: UnitToggle(
                preference: unit,
                value: dialogUnit,
                onChanged: (newUnit) => setState(() {
                  if (newUnit == dialogUnit) return;
                  weightDisplay = newUnit == 'lbs' ? kgToLbs(weightDisplay) : lbsToKg(weightDisplay);
                  dialogUnit = newUnit;
                }),
              ),
              trailing: _compactStepper(
                label: weightLabel,
                value: weightDisplay,
                min: 0,
                step: dialogUnit == 'lbs' ? 5.0 : 2.5,
                decimals: 1,
                tokens: tokens,
                onChanged: (v) => setState(() => weightDisplay = v),
              ),
            ),
          _RpeTargetInput(
            rpeMin: rpeMin,
            rpeMax: rpeMax,
            onChanged: (min, max) => setState(() {
              rpeMin = min;
              rpeMax = max;
            }),
          ),
        ],
        onAdd: () => _submitSheet(ctx, setState, (b, e) {
          busy = b;
          error = e;
        }, () {
          final weightKg = openLoad
              ? null
              : (dialogUnit == 'lbs' ? lbsToKg(weightDisplay) : weightDisplay);
          return onSubmit(AbsoluteSetBatch(
            sets: sets,
            reps: reps,
            repsMax: _rangeTop(reps, repsMax),
            weightKg: weightKg,
            rpeMin: rpeMin,
            rpeMax: rpeMin == null ? null : _rangeTop(rpeMin!, rpeMax),
            setType: setType,
          ));
        }),
      );
    },
  );
}
