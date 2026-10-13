import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/utils/copy_attribution.dart';
import 'package:nomorex/core/utils/owner_name.dart';

void main() {
  test('returns null for content that is not a copy', () {
    expect(
      copyAttributionLabel(
        isCopy: false,
        copiedFromUserId: 'u1',
        copiedFromDisplayName: 'BeastModeB',
        copiedFromSourceId: 'w1',
      ),
      isNull,
    );
  });

  test('names the original author', () {
    expect(
      copyAttributionLabel(
        isCopy: true,
        copiedFromUserId: 'u1',
        copiedFromDisplayName: 'BeastModeB',
        copiedFromSourceId: 'w1',
      ),
      'Copied from BeastModeB',
    );
  });

  test('uses the anonymous fallback when the author had no display name', () {
    expect(
      copyAttributionLabel(isCopy: true, copiedFromUserId: 'u1', copiedFromSourceId: 'w1'),
      'Copied from $kAnonymousOwnerName',
    );
  });

  test('falls back to a neutral label once the author is removed', () {
    expect(
      copyAttributionLabel(
        isCopy: true,
        copiedFromDisplayName: 'BeastModeB',
        copiedFromSourceId: 'w1',
      ),
      kCopiedFromUnknown,
    );
  });

  test('falls back to a neutral label once the original is removed', () {
    expect(
      copyAttributionLabel(
        isCopy: true,
        copiedFromUserId: 'u1',
        copiedFromDisplayName: 'BeastModeB',
      ),
      kCopiedFromUnknown,
    );
  });

  // A run of a copied program has no source workout; Workout.copiedFromSourceId
  // hands over the program id instead (see models_test.dart).
  test('a run of a copied program still names the author', () {
    expect(
      copyAttributionLabel(
        isCopy: true,
        copiedFromUserId: 'u1',
        copiedFromDisplayName: 'BeastModeB',
        copiedFromSourceId: 'p1',
      ),
      'Copied from BeastModeB',
    );
  });
}
