import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/exercise_name.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/list_group.dart';
import '../models/admin_exercise.dart';
import '../providers/admin_exercises_provider.dart';
import '../utils/admin_error.dart';
import '../widgets/admin_gate.dart';
import '../widgets/admin_page_controls.dart';

/// The official exercise catalog: search, add, rename, set other names,
/// retire, restore, delete an unused one, and export the catalog file.
class AdminExercisesScreen extends ConsumerStatefulWidget {
  const AdminExercisesScreen({super.key});

  @override
  ConsumerState<AdminExercisesScreen> createState() => _AdminExercisesScreenState();
}

class _AdminExercisesScreenState extends ConsumerState<AdminExercisesScreen> {
  static const _debounce = Duration(milliseconds: 300);

  String _search = '';
  bool _retired = false;
  int _page = 0;
  bool _exporting = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      if (!mounted) return;
      final search = text.trim();
      if (search == _search) return;
      setState(() {
        _search = search;
        _page = 0;
      });
    });
  }

  AdminExerciseActionsNotifier get _actions => ref.read(adminExerciseActionsProvider.notifier);

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _add() async {
    final name = await showExerciseFormDialog(
      context,
      onSave: (form) async {
        final existing = await _actions.create(slug: form.slug, name: form.name, aliases: form.aliases);
        return existing;
      },
    );
    if (name == null || !mounted) return;
    final (saved, existing) = name;
    _snack(existing > 0
        ? '${_lifters(existing)} already ${existing == 1 ? 'has' : 'have'} their own "$saved". '
            "They'll see both in their exercise list."
        : 'Added $saved.');
  }

  Future<void> _edit(AdminExercise exercise) async {
    final result = await showExerciseFormDialog(
      context,
      exercise: exercise,
      onSave: (form) async {
        await _actions.edit(exercise.id, name: form.name, aliases: form.aliases);
        return 0;
      },
    );
    if (result != null && mounted) _snack('Saved ${result.$1}.');
  }

  Future<void> _setRetired(AdminExercise exercise, bool retired) async {
    if (retired) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Retire ${exercise.name}?',
        message: 'It disappears from the exercise pickers. Everything that already uses it keeps working: '
            'PRs, workouts, programs and percentages. You can restore it from the Retired list.',
        confirmLabel: 'Retire',
      );
      if (!confirmed) return;
    }
    try {
      await _actions.setRetired(exercise.id, retired);
      if (mounted) _snack(retired ? 'Retired ${exercise.name}.' : 'Restored ${exercise.name}.');
    } catch (e) {
      if (mounted) _snack(adminErrorMessage(e));
    }
  }

  Future<void> _delete(AdminExercise exercise) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete ${exercise.name}?',
      message: 'Nobody uses it, so it can be removed for good. This can\'t be undone. If it\'s in the '
          'catalog file, export and commit the catalog too, or a reload brings it back.',
      confirmLabel: 'Delete permanently',
    );
    if (!confirmed) return;
    try {
      await _actions.delete(exercise.id);
      if (mounted) _snack('Deleted ${exercise.name}.');
    } catch (e) {
      if (mounted) _snack(adminErrorMessage(e));
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    final String text;
    try {
      text = await _actions.export();
    } catch (e) {
      if (mounted) _snack(adminErrorMessage(e));
      return;
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
    if (mounted) await showCatalogExportDialog(context, text);
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the auto-disposed actions notifier alive while a save is in flight:
    // with only ref.read it's disposed during the network call, and the
    // invalidations after it throw, so a save that worked reports a failure.
    ref.watch(adminExerciseActionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercises'),
        actions: [
          IconButton(
            key: const Key('admin_exercises_export'),
            tooltip: 'Export catalog',
            onPressed: _exporting ? null : _export,
            icon: _exporting
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      body: AdminGate(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('admin_exercises_search'),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Search names, other names or slugs',
                            ),
                            onChanged: _onSearchChanged,
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          key: const Key('admin_exercises_add'),
                          // The theme's filled buttons are full-width; in a Row that's infinite.
                          style: FilledButton.styleFrom(minimumSize: const Size(0, NomorexSizes.controlHeightLg)),
                          onPressed: _add,
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<bool>(
                      key: const Key('admin_exercises_filter'),
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: false, label: Text('Active')),
                        ButtonSegment(value: true, label: Text('Retired')),
                      ],
                      selected: {_retired},
                      onSelectionChanged: (s) => setState(() {
                        _retired = s.first;
                        _page = 0;
                      }),
                    ),
                    const SizedBox(height: 16),
                    _Results(
                      search: _search,
                      retired: _retired,
                      page: _page,
                      onPage: (page) => setState(() => _page = page),
                      onEdit: _edit,
                      onRetire: (e) => _setRetired(e, true),
                      onRestore: (e) => _setRetired(e, false),
                      onDelete: _delete,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _lifters(int n) => n == 1 ? '1 lifter' : '$n lifters';

class _Results extends ConsumerWidget {
  const _Results({
    required this.search,
    required this.retired,
    required this.page,
    required this.onPage,
    required this.onEdit,
    required this.onRetire,
    required this.onRestore,
    required this.onDelete,
  });

  final String search;
  final bool retired;
  final int page;
  final ValueChanged<int> onPage;
  final ValueChanged<AdminExercise> onEdit;
  final ValueChanged<AdminExercise> onRetire;
  final ValueChanged<AdminExercise> onRestore;
  final ValueChanged<AdminExercise> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = adminExercisesProvider(search: search, retired: retired, page: page);
    final result = ref.watch(provider);
    final tokens = NomorexTokens.of(context);

    return switch (result) {
      AsyncValue(:final value?) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (value.items.isEmpty && value.page == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  search.isNotEmpty
                      ? 'No exercises match "$search".'
                      : retired
                          ? 'No retired exercises.'
                          : 'No exercises yet.',
                  key: const Key('admin_exercises_empty'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: tokens.fg2),
                ),
              )
            else
              ListGroup(
                key: const Key('admin_exercises_list'),
                children: [
                  for (final e in value.items)
                    _ExerciseRow(
                      exercise: e,
                      onEdit: () => onEdit(e),
                      onRetire: () => onRetire(e),
                      onRestore: () => onRestore(e),
                      onDelete: () => onDelete(e),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            AdminPageControls(page: value, onPage: onPage),
          ],
        ),
      AsyncError() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Couldn't load exercises.", style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
            FilledButton(
              style: tokens.secondaryButtonStyle,
              onPressed: () => ref.invalidate(provider),
              child: const Text('Try again'),
            ),
          ],
        ),
      _ => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
    };
  }
}

enum _Action { edit, retire, restore, delete }

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.exercise,
    required this.onEdit,
    required this.onRetire,
    required this.onRestore,
    required this.onDelete,
  });

  final AdminExercise exercise;
  final VoidCallback onEdit;
  final VoidCallback onRetire;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.fg3);
    final usage = exercise.usageCount == 0 ? 'Not used yet' : 'Used by ${_lifters(exercise.usageCount)}';

    // No onTap on the tile: the menu is its own button, announced and
    // activated separately from the row's text.
    return GroupableTile(
      key: ValueKey('admin_exercise_${exercise.slug}'),
      padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.name, style: Theme.of(context).textTheme.bodyLarge),
                Text(exercise.slug, style: tokens.weightXs.copyWith(color: tokens.fg3)),
                if (exercise.aliases.isNotEmpty) Text('Also: ${exercise.aliases.join(', ')}', style: small),
                Text(usage, style: small),
              ],
            ),
          ),
          PopupMenuButton<_Action>(
            key: ValueKey('admin_exercise_menu_${exercise.slug}'),
            tooltip: 'Actions for ${exercise.name}',
            onSelected: (action) => switch (action) {
              _Action.edit => onEdit(),
              _Action.retire => onRetire(),
              _Action.restore => onRestore(),
              _Action.delete => onDelete(),
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: _Action.edit, child: Text('Edit')),
              if (exercise.isRetired)
                const PopupMenuItem(value: _Action.restore, child: Text('Restore'))
              else
                const PopupMenuItem(value: _Action.retire, child: Text('Retire')),
              PopupMenuItem(
                value: _Action.delete,
                enabled: exercise.canDelete,
                child: Text(exercise.canDelete ? 'Delete permanently' : 'Delete (in use, retire instead)'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What the add/edit form saves. [slug] is ignored when editing.
typedef ExerciseForm = ({String slug, String name, List<String> aliases});

/// The add form (no [exercise]) or the edit form. [onSave] does the save and
/// returns a number for the caller (lifters with a same-named custom exercise,
/// when adding); a failure stays in the dialog as a message. Returns the
/// saved name and that number, or null if cancelled.
Future<(String, int)?> showExerciseFormDialog(
  BuildContext context, {
  AdminExercise? exercise,
  required Future<int> Function(ExerciseForm form) onSave,
}) =>
    showDialog<(String, int)>(
      context: context,
      builder: (_) => _ExerciseFormDialog(exercise: exercise, onSave: onSave),
    );

class _ExerciseFormDialog extends StatefulWidget {
  const _ExerciseFormDialog({this.exercise, required this.onSave});

  final AdminExercise? exercise;
  final Future<int> Function(ExerciseForm form) onSave;

  @override
  State<_ExerciseFormDialog> createState() => _ExerciseFormDialogState();
}

class _ExerciseFormDialogState extends State<_ExerciseFormDialog> {
  late final _name = TextEditingController(text: widget.exercise?.name ?? '');
  late final _slug = TextEditingController(text: widget.exercise?.slug ?? '');
  late final _aliases = TextEditingController(text: widget.exercise?.aliases.join(', ') ?? '');

  /// The slug follows the name until the admin types in it.
  bool _slugEdited = false;

  /// Whether the old name was added to the other names by a rename (so
  /// renaming back takes it out again).
  bool _oldNameAdded = false;

  bool _saving = false;
  bool _submitted = false;
  String? _error;

  bool get _isEdit => widget.exercise != null;

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _aliases.dispose();
    super.dispose();
  }

  void _onNameChanged(String name) {
    if (!_isEdit && !_slugEdited) _slug.text = suggestExerciseSlug(name);
    if (_isEdit) _keepOldNameAsAlias(name);
    setState(() {});
  }

  // Renaming keeps the old name as another name, so imports and copied
  // workouts that say it still find this exercise. It's added where the admin
  // can see it, and removed again if they rename back.
  void _keepOldNameAsAlias(String name) {
    final old = widget.exercise!.name;
    final aliases = parseAliases(_aliases.text);
    final has = aliases.any((a) => normalizeExerciseName(a) == normalizeExerciseName(old));
    final renamed = normalizeExerciseName(name) != normalizeExerciseName(old) && name.trim().isNotEmpty;
    if (renamed && !has) {
      _aliases.text = [...aliases, old].join(', ');
      _oldNameAdded = true;
    } else if (!renamed && has && _oldNameAdded) {
      _aliases.text =
          aliases.where((a) => normalizeExerciseName(a) != normalizeExerciseName(old)).join(', ');
      _oldNameAdded = false;
    }
  }

  String? get _nameError {
    final name = _name.text.trim();
    if (name.isEmpty) return 'Enter a name';
    if (name.length > kMaxExerciseNameLength) return 'Keep it under $kMaxExerciseNameLength characters';
    return null;
  }

  String? get _slugError {
    if (_isEdit) return null;
    if (!kExerciseSlugPattern.hasMatch(_slug.text.trim())) {
      return 'Lowercase letters and numbers joined by underscores, like clean_and_jerk';
    }
    return null;
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (_nameError != null || _slugError != null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final name = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    try {
      final n = await widget.onSave((slug: _slug.text.trim(), name: name, aliases: parseAliases(_aliases.text)));
      if (mounted) Navigator.of(context).pop((name, n));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = adminErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final theme = Theme.of(context);
    final help = theme.textTheme.bodySmall?.copyWith(color: tokens.fg3);

    return AlertDialog(
      title: Text(_isEdit ? 'Edit exercise' : 'Add exercise'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('admin_exercise_name'),
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: 'Name', errorText: _submitted ? _nameError : null),
                onChanged: _onNameChanged,
              ),
              const SizedBox(height: 12),
              if (_isEdit)
                Text('Slug: ${widget.exercise!.slug} (never changes)', style: help)
              else ...[
                TextField(
                  key: const Key('admin_exercise_slug'),
                  controller: _slug,
                  decoration: InputDecoration(labelText: 'Slug', errorText: _submitted ? _slugError : null),
                  onChanged: (_) => setState(() => _slugEdited = true),
                ),
                const SizedBox(height: 4),
                Text(
                  'Its permanent ID in the catalog file. It can\'t be changed or reused later.',
                  style: help,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                key: const Key('admin_exercise_aliases'),
                controller: _aliases,
                decoration: const InputDecoration(labelText: 'Other names', hintText: 'C&J, Clean and Jerk'),
              ),
              const SizedBox(height: 4),
              Text(
                _oldNameAdded
                    ? 'The old name is kept as another name, so imports and copied workouts still find it. '
                        'Remove it if it was a typo.'
                    : 'Separate with commas. Imports, copied workouts and search match these too.',
                key: const Key('admin_exercise_aliases_help'),
                style: help,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, key: const Key('admin_exercise_error'), style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('admin_exercise_save'),
          onPressed: _saving ? null : _save,
          child: Text(_isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

/// Shows the exported catalog with a Copy button and what to do with it.
Future<void> showCatalogExportDialog(BuildContext context, String text) => showDialog<void>(
      context: context,
      builder: (ctx) {
        final tokens = NomorexTokens.of(ctx);
        return AlertDialog(
          title: const Text('Export catalog'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Replace supabase/catalog/official_exercises.sql with this and commit it. '
                  'That file is how the catalog comes back after a database wipe.',
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tokens.palette.bg0,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.palette.borderDefault),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        text,
                        key: const Key('admin_exercises_export_text'),
                        style: tokens.weightXs,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
            FilledButton.icon(
              key: const Key('admin_exercises_copy'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Copied the catalog.')));
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy'),
            ),
          ],
        );
      },
    );
