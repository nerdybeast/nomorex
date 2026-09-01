import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/utils/weight_converter.dart';

void main() {
  group('formatResolvedWeight', () {
    test('renders a measured-1RM weight plainly', () {
      expect(
        formatResolvedWeight(115.5, 'kg', estimated: false),
        '115.5 kg',
      );
    });

    test('marks a weight derived from an estimated 1RM', () {
      expect(
        formatResolvedWeight(115.5, 'kg', estimated: true),
        '115.5 kg (est.)',
      );
    });

    test('keeps the marker outside the both-units form', () {
      expect(
        formatResolvedWeight(100, 'both', estimated: true),
        '220 lbs / 100 kg (est.)',
      );
    });
  });
}
