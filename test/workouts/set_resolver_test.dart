import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/workouts/utils/set_resolver.dart';

void main() {
  test('absolute mode returns the absolute weight, ignoring 1RM', () {
    expect(
      resolveSetWeightKg(weightMode: 'absolute', absoluteWeightKg: 60, oneRepMaxKg: 100),
      60,
    );
  });

  test('percentage mode multiplies percentage against the 1RM', () {
    expect(
      resolveSetWeightKg(weightMode: 'percentage', percentage: 80, oneRepMaxKg: 100),
      80,
    );
  });

  test('percentage mode returns null when no 1RM is available', () {
    expect(
      resolveSetWeightKg(weightMode: 'percentage', percentage: 80, oneRepMaxKg: null),
      isNull,
    );
  });

  test('absolute mode returns null when no absolute weight set', () {
    expect(
      resolveSetWeightKg(weightMode: 'absolute', absoluteWeightKg: null, oneRepMaxKg: 100),
      isNull,
    );
  });
}
