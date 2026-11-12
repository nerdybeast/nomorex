import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

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
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    // Mono, so the tag sits naturally beside a mono weight.
    final labelStyle = tokens.weightXs;

    if (preference != 'both') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: palette.borderDefault),
          borderRadius: BorderRadius.circular(NomorexSizes.radiusSm),
        ),
        child: Text(preference, style: labelStyle.copyWith(color: palette.fg2)),
      );
    }

    // The track stays small beside a weight, but each segment's tap area is
    // a full touch target tall: this sits in the weight dialog and Add PR,
    // used mid-session. The border is painted behind the taller row.
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Container(
                height: _segmentHeight + 4,
                decoration: BoxDecoration(
                  border: Border.all(color: palette.borderDefault),
                  borderRadius: BorderRadius.circular(NomorexSizes.radiusSm),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final u in const ['kg', 'lbs']) _segment(palette, labelStyle, u),
            ],
          ),
        ),
      ],
    );
  }

  static const _segmentHeight = 22.0;

  Widget _segment(NomorexPalette palette, TextStyle labelStyle, String u) {
    final selected = u == value;
    final onTap = selected ? null : () => onChanged(u);
    return Semantics(
      button: true,
      selected: selected,
      label: u == 'kg' ? 'Kilograms' : 'Pounds',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: palette.bg3,
        child: SizedBox(
          height: NomorexSizes.touchTarget,
          child: Center(
            child: Container(
              height: _segmentHeight,
              constraints: const BoxConstraints(minWidth: 40),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: selected ? palette.primarySubtle : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                u,
                style: labelStyle.copyWith(color: selected ? palette.primaryText : palette.fg2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
