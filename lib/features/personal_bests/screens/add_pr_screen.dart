import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/personal_bests_provider.dart';
import '../../exercises/models/exercise.dart';
import '../../exercises/providers/exercises_provider.dart';
import '../../exercises/widgets/exercise_picker.dart';
import '../../profile/providers/profile_provider.dart';
import '../../../core/theme/dark_theme.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/number_stepper_field.dart';
import '../../../shared/widgets/unit_toggle.dart';

class AddPrScreen extends ConsumerStatefulWidget {
  const AddPrScreen({super.key, this.exerciseId});
  final String? exerciseId;

  @override
  ConsumerState<AddPrScreen> createState() => _AddPrScreenState();
}

class _AddPrScreenState extends ConsumerState<AddPrScreen> {
  final _formKey = GlobalKey<FormState>();
  Exercise? _selectedExercise;
  double _weight = 0;
  int _reps = 1;
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _loading = false;
  String? _error;
  late String _entryUnit;

  @override
  void initState() {
    super.initState();
    final preference = ref.read(unitPreferenceProvider);
    _entryUnit = preference == 'both' ? 'kg' : preference;
  }

  // Flips exactly once (false -> true) once we've had a chance to resolve
  // widget.exerciseId against the loaded exercise list (or determined there's
  // nothing to resolve). Used as an ExercisePicker key so it remounts exactly
  // once at that moment — see the ExercisePicker build() below for why.
  bool _prefilledFromArg = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedExercise == null) return;

    final weightKg = _entryUnit == 'lbs' ? lbsToKg(_weight) : _weight;

    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(personalBestsProvider.notifier).addPr(
        exerciseId: _selectedExercise!.id,
        weightKg: weightKg,
        reps: _reps,
        date: _selectedDate,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      if (mounted) context.pop();
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(exercisesProvider).asData?.value ?? [];

    // Resolve widget.exerciseId against the loaded list exactly once. This
    // mutates state directly rather than via setState: it runs synchronously
    // within this same build() call, so the values are already in effect for
    // the widget tree built below. If exercisesProvider is still loading on
    // first build, this simply re-runs (still guarded by _prefilledFromArg)
    // on the rebuild that ref.watch triggers once data arrives.
    if (!_prefilledFromArg) {
      if (widget.exerciseId == null) {
        _prefilledFromArg = true;
      } else if (exercises.isNotEmpty) {
        for (final e in exercises) {
          if (e.id == widget.exerciseId) {
            _selectedExercise = e;
            break;
          }
        }
        _prefilledFromArg = true;
      }
    }

    final preference = ref.watch(unitPreferenceProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<NomorexDarkTokens>();
    final overline = tokens?.overline;

    return Scaffold(
      appBar: AppBar(title: const Text('NEW PERSONAL BEST')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Exercise picker
                    ExercisePicker(
                      key: ValueKey(_prefilledFromArg),
                      exercises: exercises,
                      selected: _selectedExercise,
                      onSelected: (ex) => setState(() => _selectedExercise = ex),
                      onAddCustom: (name) async {
                        final newEx = await ref.read(exercisesProvider.notifier).addCustomExercise(name);
                        if (mounted) setState(() => _selectedExercise = newEx);
                      },
                    ),
                    const SizedBox(height: 20),
                    // Weight header (label + unit toggle) sits above the
                    // stepper, not inline with it — inline would give
                    // the weight and reps steppers different available
                    // widths (only weight shares its row with the unit
                    // toggle), so their -/value/+ clusters wouldn't
                    // line up between rows.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Weight ($_entryUnit)'.toUpperCase(), style: overline),
                        UnitToggle(
                          preference: preference,
                          value: _entryUnit,
                          onChanged: (newUnit) => setState(() {
                            if (newUnit == _entryUnit) return;
                            _weight = newUnit == 'lbs' ? kgToLbs(_weight) : lbsToKg(_weight);
                            _entryUnit = newUnit;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    NumberStepperField(
                      key: const Key('add_pr_weight'),
                      label: '',
                      value: _weight,
                      min: 0,
                      step: _entryUnit == 'lbs' ? 5 : 2.5,
                      decimals: _entryUnit == 'lbs' ? 0 : 1,
                      onChanged: (v) => setState(() => _weight = v),
                      valueTextStyle: tokens?.stepperValue,
                      valueDecoration: tokens?.stepperValueDecoration,
                      decrementButtonStyle: tokens?.stepperDecrementStyle,
                      incrementButtonStyle: tokens?.stepperIncrementStyle,
                    ),
                    const SizedBox(height: 20),
                    // Reps
                    Text('Reps'.toUpperCase(), style: overline),
                    const SizedBox(height: 8),
                    NumberStepperField(
                      key: const Key('add_pr_reps'),
                      label: '',
                      value: _reps.toDouble(),
                      min: 1,
                      step: 1,
                      decimals: 0,
                      onChanged: (v) => setState(() => _reps = v.round()),
                      valueTextStyle: tokens?.stepperValue,
                      valueDecoration: tokens?.stepperValueDecoration,
                      decrementButtonStyle: tokens?.stepperDecrementStyle,
                      incrementButtonStyle: tokens?.stepperIncrementStyle,
                    ),
                    const SizedBox(height: 20),
                    // Date
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          suffixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(formatDate(_selectedDate)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Notes
                    TextFormField(
                      controller: _notesController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                      ),
                      minLines: 3,
                      maxLines: 3,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('add_pr_submit'),
                      onPressed: (_loading || _selectedExercise == null) ? null : _submit,
                      child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save Personal Best'),
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
