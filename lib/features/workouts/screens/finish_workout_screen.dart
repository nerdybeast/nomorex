import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/dark_theme.dart';
import '../providers/workout_detail_provider.dart';
import '../widgets/elapsed_timer.dart';

// By the time this screen is reached, WorkoutDetailScreen has already paused
// the workout (via the Finish button), freezing the clock server-side — so
// the duration shown here is static regardless of how long the user spends
// writing notes before tapping Save.
class FinishWorkoutScreen extends ConsumerStatefulWidget {
  const FinishWorkoutScreen({super.key, required this.workoutId});
  final String workoutId;

  @override
  ConsumerState<FinishWorkoutScreen> createState() => _FinishWorkoutScreenState();
}

class _FinishWorkoutScreenState extends ConsumerState<FinishWorkoutScreen> {
  final _notesController = TextEditingController();
  bool _initializedNotes = false;
  bool _busy = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final notifier = ref.read(workoutDetailProvider(widget.workoutId).notifier);
      final notes = _notesController.text.trim();
      await notifier.finishWorkout(sessionNotes: notes.isEmpty ? null : notes);
      // pop, not go(routeWorkoutDetail(...)): this screen is always reached
      // by pushing on top of WorkoutDetailScreen, which go() would discard
      // from the stack — leaving the AppBar with no back button and no
      // shell nav (this route sits outside the shell), a dead end. Popping
      // reveals that same WorkoutDetailScreen, already showing "finished"
      // since finishWorkout() above already refreshed its provider.
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discard() async {
    // Buttons live in `content` (a Column), not `actions` (an OverflowBar):
    // OverflowBar dry-lays-out its children to measure their natural size,
    // and Expanded — needed here for the two buttons to fill the width
    // evenly — asserts when queried for an intrinsic size outside an actual
    // Flex layout pass. A Column gives the inner Row a normal bounded-width
    // layout instead, sidestepping that.
    final tokens = Theme.of(context).extension<NomorexDarkTokens>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard workout?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This resets it back to not started — any sets you already checked off stay as they are.',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: tokens?.secondaryButtonStyle,
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: tokens?.dangerButtonStyle,
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Discard'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final notifier = ref.read(workoutDetailProvider(widget.workoutId).notifier);
      await notifier.discardSession();
      if (mounted) context.go(AppConstants.routeWorkouts);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(workoutDetailProvider(widget.workoutId));
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<NomorexDarkTokens>();

    return Scaffold(
      appBar: AppBar(title: const Text('FINISH WORKOUT')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: colorScheme.error))),
        data: (workout) {
          if (!_initializedNotes) {
            _notesController.text = workout.sessionNotes ?? '';
            _initializedNotes = true;
          }
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // startedAt is only null for a beat right after a
                      // successful Discard: discardSession() resets the
                      // workout to not-started, and this screen (still
                      // watching the provider) rebuilds with that cleared
                      // data before context.go() finishes navigating away.
                      if (workout.startedAt != null) ...[
                        Text(
                          'Workout duration',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        ElapsedTimer(
                          startedAt: workout.startedAt!,
                          totalPausedSeconds: workout.totalPausedSeconds,
                          pausedAt: workout.pausedAt,
                        ),
                        const SizedBox(height: 20),
                      ],
                      TextField(
                        controller: _notesController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          hintText: 'How did it go?',
                        ),
                        minLines: 3,
                        maxLines: 6,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              style: tokens?.dangerButtonStyle,
                              onPressed: _busy ? null : _discard,
                              child: const Text('Discard'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _busy ? null : _save,
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
