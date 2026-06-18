import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/personal_bests_provider.dart';
import '../../exercises/models/exercise.dart';
import '../../exercises/providers/exercises_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../core/utils/date_formatter.dart';

class AddPrScreen extends ConsumerStatefulWidget {
  const AddPrScreen({super.key});

  @override
  ConsumerState<AddPrScreen> createState() => _AddPrScreenState();
}

class _AddPrScreenState extends ConsumerState<AddPrScreen> {
  final _formKey = GlobalKey<FormState>();
  Exercise? _selectedExercise;
  final _weightController = TextEditingController();
  final _repsController = TextEditingController(text: '1');
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
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

    final unit = ref.read(unitPreferenceProvider);
    final enteredWeight = double.tryParse(_weightController.text) ?? 0;
    final weightKg = unit == 'lbs' ? lbsToKg(enteredWeight) : enteredWeight;
    final reps = int.tryParse(_repsController.text) ?? 1;

    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(personalBestsProvider.notifier).addPr(
        exerciseId: _selectedExercise!.id,
        weightKg: weightKg,
        reps: reps,
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
    final unit = ref.watch(unitPreferenceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New Personal Best')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Exercise picker
                _ExercisePicker(
                  exercises: exercises,
                  selected: _selectedExercise,
                  onSelected: (ex) => setState(() => _selectedExercise = ex),
                  onAddCustom: (name) async {
                    await ref.read(exercisesProvider.notifier).addCustomExercise(name);
                    final updated = ref.read(exercisesProvider).asData?.value ?? [];
                    final newEx = updated.where((e) => e.name == name).firstOrNull;
                    if (newEx != null) setState(() => _selectedExercise = newEx);
                  },
                ),
                const SizedBox(height: 16),
                // Weight + unit toggle
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _weightController,
                        decoration: InputDecoration(
                          labelText: 'Weight ($unit)',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null) return 'Enter a number';
                          if (double.parse(v) <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    _UnitToggle(
                      currentUnit: unit,
                      onChanged: (newUnit) async {
                        await ref.read(profileProvider.notifier).setUnitPreference(newUnit);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Reps
                TextFormField(
                  controller: _repsController,
                  decoration: const InputDecoration(
                    labelText: 'Reps',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final n = int.tryParse(v);
                    if (n == null || n < 1) return 'Must be at least 1';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Date
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(formatDate(_selectedDate)),
                  ),
                ),
                const SizedBox(height: 16),
                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
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
    );
  }
}

/// Autocomplete-style exercise picker with "Add custom" fallback.
class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker({
    required this.exercises,
    required this.selected,
    required this.onSelected,
    required this.onAddCustom,
  });

  final List<Exercise> exercises;
  final Exercise? selected;
  final ValueChanged<Exercise> onSelected;
  final Future<void> Function(String name) onAddCustom;

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Exercise>(
      displayStringForOption: (e) => e.name,
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return widget.exercises;
        return widget.exercises.where(
          (e) => e.name.toLowerCase().contains(textEditingValue.text.toLowerCase()),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Exercise',
            border: const OutlineInputBorder(),
            hintText: 'Search exercises...',
            errorText: widget.selected == null && controller.text.isNotEmpty ? null : null,
          ),
          validator: (_) => widget.selected == null ? 'Select an exercise' : null,
        );
      },
      onSelected: widget.onSelected,
      optionsViewBuilder: (context, onSelected, options) {
        final optionList = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: optionList.length + 1, // +1 for "Add custom" option
                itemBuilder: (context, index) {
                  if (index == optionList.length) {
                    // "Add custom exercise" option — always shown at the bottom
                    return ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('Add custom exercise'),
                      onTap: () async {
                        // Get the typed text from the field via the options view state
                        // We use a dialog to confirm the name
                        final name = await showDialog<String>(
                          context: context,
                          builder: (ctx) {
                            final nameCtrl = TextEditingController();
                            return AlertDialog(
                              title: const Text('Custom Exercise'),
                              content: TextField(
                                controller: nameCtrl,
                                decoration: const InputDecoration(labelText: 'Exercise name'),
                                autofocus: true,
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
                                  child: const Text('Add'),
                                ),
                              ],
                            );
                          },
                        );
                        if (name != null && name.isNotEmpty) {
                          await widget.onAddCustom(name);
                        }
                      },
                    );
                  }
                  final option = optionList[index];
                  return ListTile(
                    title: Text(option.name),
                    subtitle: option.isPredefined ? null : const Text('Custom'),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// kg / lbs toggle chip widget.
class _UnitToggle extends StatelessWidget {
  const _UnitToggle({required this.currentUnit, required this.onChanged});

  final String currentUnit;
  final Future<void> Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'kg', label: Text('kg')),
        ButtonSegment(value: 'lbs', label: Text('lbs')),
      ],
      selected: {currentUnit},
      onSelectionChanged: (set) => onChanged(set.first),
      style: const ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
