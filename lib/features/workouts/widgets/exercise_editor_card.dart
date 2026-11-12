import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// One exercise in the workout or program-day editor.
///
/// A `primary-subtle` header band carries the exercise's place in the
/// session (orange mono index), its name, the drag handle and delete; the
/// body below holds the notes field and the set editor ([children]).
///
/// [highlighted] edges the card in `primary-border` for a moment after the
/// exercise is added, so the lifter sees where it landed; the editor turns
/// it off again and the edge fades back.
class ExerciseEditorCard extends StatelessWidget {
  const ExerciseEditorCard({
    super.key,
    required this.index,
    required this.name,
    required this.onDelete,
    required this.children,
    this.highlighted = false,
  });

  /// Zero-based position in the list; also the reorder index.
  final int index;
  final String name;
  final VoidCallback onDelete;
  final List<Widget> children;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    const radius = NomorexSizes.radiusLg;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      // In the foreground, so the band and body underneath can't paint over
      // the edge.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: highlighted ? palette.primaryBorder : palette.borderSubtle),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        // Materials rather than colored boxes: the fields and buttons inside
        // need one above them (a card being dragged is lifted into the
        // overlay, away from the page's), and ink splashes paint on it.
        child: Material(
          color: palette.bg1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: palette.primarySubtle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: index,
                        child: Tooltip(
                          message: 'Drag to reorder',
                          child: SizedBox.square(
                            dimension: 40,
                            child: Icon(Icons.drag_handle, size: 20, color: palette.fg3),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 20,
                        child: Text(
                          '${index + 1}',
                          style: tokens.weightSm.copyWith(color: palette.primaryText),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete exercise',
                        icon: Icon(Icons.delete_outline, size: 20, color: palette.fg2),
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Brings a just-added exercise into view and edges it in orange for a
/// moment. Mixed into the workout and program editors' states.
mixin JustAddedExerciseHighlight<T extends StatefulWidget> on State<T> {
  /// The editor row (`workout_exercises.id` / `program_exercises.id`)
  /// currently highlighted, if any.
  String? highlightedExerciseId;

  /// Put on the highlighted card so it can be scrolled to.
  final highlightKey = GlobalKey(debugLabel: 'just-added-exercise');

  Timer? _highlightTimer;

  /// How long the orange edge stays before fading back.
  static const highlightHold = Duration(milliseconds: 1600);

  /// Called with the id of the row the add created. [scrollController] is
  /// used to reach the end of a lazily built list when the card hasn't been
  /// built yet.
  void highlightAddedExercise(String id, {ScrollController? scrollController}) {
    if (!mounted) return;
    _highlightTimer?.cancel();
    setState(() => highlightedExerciseId = id);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      var cardContext = highlightKey.currentContext;
      if (cardContext == null && scrollController != null && scrollController.hasClients) {
        // New exercises are appended, so the end of the list is where it is.
        final position = scrollController.position;
        await scrollController.animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
        cardContext = highlightKey.currentContext;
      }
      if (cardContext != null && cardContext.mounted) {
        await Scrollable.ensureVisible(
          cardContext,
          alignment: 0.15,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        );
      }
    });
    _highlightTimer = Timer(highlightHold, () {
      if (mounted) setState(() => highlightedExerciseId = null);
    });
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }
}
