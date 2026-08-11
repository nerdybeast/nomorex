import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/toggle_card.dart';
import '../providers/workouts_provider.dart';

// Nothing is written to the database until Save is pressed — backing out of
// this screen must leave no trace. Once saved, the real workout row exists
// and further edits (including exercises) happen on EditWorkoutScreen.
class NewWorkoutScreen extends ConsumerStatefulWidget {
  const NewWorkoutScreen({super.key});

  @override
  ConsumerState<NewWorkoutScreen> createState() => _NewWorkoutScreenState();
}

class _NewWorkoutScreenState extends ConsumerState<NewWorkoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isPublic = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final typedTitle = _titleController.text.trim();
      final title = typedTitle.isNotEmpty
          ? typedTitle
          : (ref.read(nextWorkoutNameProvider).value ?? 'Workout 1');
      final description = _descriptionController.text.trim();
      final id = await ref.read(workoutsProvider.notifier).createWorkout(
            title: title,
            notes: description.isEmpty ? null : description,
            isPublic: _isPublic,
          );
      if (mounted) context.pushReplacement(AppConstants.routeWorkoutEdit(id));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final defaultTitle = ref.watch(nextWorkoutNameProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('NEW WORKOUT')),
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
                    TextFormField(
                      controller: _titleController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        hintText: defaultTitle,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      minLines: 3,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    ToggleCard(
                      title: 'Public',
                      subtitle: 'Other users can view this workout',
                      value: _isPublic,
                      onChanged: (v) => setState(() => _isPublic = v),
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
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
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
