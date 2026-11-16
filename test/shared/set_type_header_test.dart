import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/shared/models/set_type.dart';
import 'package:nomorex/shared/widgets/set_type_header.dart';

/// What [withSetTypeHeaders] builds, as text: headers as their type, rows as
/// their label.
List<String> _layout(List<(String, SetType)> sets) => [
      for (final w in withSetTypeHeaders<(String, SetType)>(
        sets,
        typeOf: (s) => s.$2,
        row: (s) => Text(s.$1),
      ))
        w is SetTypeHeader ? '[${w.type.dbValue}]' : (w as Text).data!,
    ];

void main() {
  test('all working sets: rows only, no headers', () {
    expect(_layout([('a', SetType.working), ('b', SetType.working)]), ['a', 'b']);
  });

  test('a header above each run of one type, working included', () {
    expect(
      _layout([
        ('w1', SetType.warmup),
        ('w2', SetType.warmup),
        ('s1', SetType.working),
        ('c1', SetType.cooldown),
      ]),
      ['[warmup]', 'w1', 'w2', '[working]', 's1', '[cooldown]', 'c1'],
    );
  });

  test('a type that comes back after another gets a header again', () {
    expect(
      _layout([('s1', SetType.working), ('w1', SetType.warmup), ('s2', SetType.working)]),
      ['[working]', 's1', '[warmup]', 'w1', '[working]', 's2'],
    );
  });

  test('no sets, no widgets', () {
    expect(_layout(const []), isEmpty);
  });
}
