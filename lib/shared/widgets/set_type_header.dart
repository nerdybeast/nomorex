import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_theme.dart';
import '../models/set_type.dart';

/// A mono caps label ("WARM-UP") above a run of sets of one type. The type
/// sits on its own row rather than in front of each set's reps, so every set
/// row starts its reps in the same place whatever its type.
class SetTypeHeader extends StatelessWidget {
  const SetTypeHeader({super.key, required this.type, this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 4)});

  final SetType type;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: padding,
        child: Text(
          type.label.toUpperCase(),
          style: tokens.eyebrow.copyWith(letterSpacing: 0.4, color: tokens.palette.fg3),
        ),
      ),
    );
  }
}

/// [sets] as rows, with a [SetTypeHeader] above each run of consecutive sets
/// of one type. An exercise of only working sets gets no headers at all, so it
/// reads exactly as it did before set types existed.
List<Widget> withSetTypeHeaders<T>(
  List<T> sets, {
  required SetType Function(T set) typeOf,
  required Widget Function(T set) row,
  Widget Function(SetType type)? header,
}) {
  if (sets.every((s) => typeOf(s).isWorking)) return [for (final s in sets) row(s)];
  final out = <Widget>[];
  SetType? current;
  for (final s in sets) {
    final type = typeOf(s);
    if (type != current) {
      out.add(header?.call(type) ?? SetTypeHeader(key: ValueKey('set_type_header_${out.length}'), type: type));
      current = type;
    }
    out.add(row(s));
  }
  return out;
}
