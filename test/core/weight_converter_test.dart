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

  group('formatWeight', () {
    test('drops the trailing .0 for a whole-number weight', () {
      expect(formatWeight(205, 'kg'), '205 kg');
    });

    test('keeps the decimal for a genuinely fractional weight', () {
      expect(formatWeight(167.5, 'kg'), '167.5 kg');
    });
  });

  group('formatWeightBoth', () {
    test('rounds lbs to a whole number but keeps the kg side exact', () {
      // Regression case: 167.5 kg was previously rounded away to "168 kg".
      expect(formatWeightBoth(167.5), '369 lbs / 167.5 kg');
    });

    test('shows no decimal on either side for a whole-number weight', () {
      expect(formatWeightBoth(100), '220 lbs / 100 kg');
    });
  });
}
