import 'package:flutter/material.dart';

/// Displays the unit a weight value is being entered/shown in. When
/// [preference] is fixed to a single unit ('kg' or 'lbs') there's nothing to
/// choose, so this renders a static chip. When [preference] is 'both', it
/// renders an interactive kg/lbs pill so the caller can pick which unit
/// *this* value is being entered/shown in — that choice is local to the
/// caller and is never persisted as the user's saved preference (only the
/// Profile screen does that).
class UnitToggle extends StatelessWidget {
  const UnitToggle({
    super.key,
    required this.preference,
    required this.value,
    required this.onChanged,
  });

  final String preference;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (preference != 'both') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          preference,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final u in const ['kg', 'lbs']) _segment(context, colorScheme, u),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, ColorScheme colorScheme, String u) {
    final selected = u == value;
    return InkWell(
      onTap: selected ? null : () => onChanged(u),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          u,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
