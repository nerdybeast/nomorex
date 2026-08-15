import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../features/exercises/providers/exercises_provider.dart';

/// Inline "set PR" link, shown in place of a working weight when a percentage
/// set has no 1RM to resolve against.
///
/// The basis exercise isn't necessarily one the viewer has: a public workout
/// can be built around its owner's custom exercise, whose id means nothing in
/// the viewer's catalog. In that case this ensures the viewer has their own
/// same-named exercise first, so the link always lands somewhere they can
/// actually save a PR, rather than on an add-PR screen with an empty picker.
class SetPrLink extends ConsumerWidget {
  const SetPrLink({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    this.style,
  });

  /// The exercise whose 1RM the set resolves against — a set's
  /// `basis_exercise_id` when it has one, otherwise its own exercise.
  final String exerciseId;

  /// That exercise's display name, used to find-or-create the viewer's own
  /// copy when [exerciseId] isn't in their catalog.
  final String exerciseName;

  final TextStyle? style;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final String targetId;
    try {
      // Awaited rather than read off .asData: nothing on these screens watches
      // the exercise list any more, so it may well still be loading at the
      // moment of the tap — and treating "not loaded yet" as "the viewer
      // doesn't have this lift" would create a duplicate exercise.
      final visible = await ref.read(exercisesProvider.future);
      targetId = visible.any((e) => e.id == exerciseId)
          ? exerciseId
          : (await ref
                  .read(exercisesProvider.notifier)
                  .ensureExerciseByName(exerciseName))
              .id;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not open PR entry: $e')));
      }
      return;
    }

    if (context.mounted) {
      context.push(AppConstants.routeAddPrForExercise(targetId));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _open(context, ref),
      child: Text(
        'set PR',
        style: (style ?? DefaultTextStyle.of(context).style).copyWith(
          color: colorScheme.primary,
          decoration: TextDecoration.underline,
          decorationColor: colorScheme.primary,
        ),
      ),
    );
  }
}
