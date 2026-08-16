import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/utils/owner_name.dart';

void main() {
  test('returns the name when one is set', () {
    expect(ownerDisplayName('BeastModeB'), 'BeastModeB');
  });

  test('trims surrounding whitespace', () {
    expect(ownerDisplayName('  BeastModeB  '), 'BeastModeB');
  });

  test('falls back when the name is null', () {
    expect(ownerDisplayName(null), kAnonymousOwnerName);
  });

  test('falls back when the name is empty or only whitespace', () {
    expect(ownerDisplayName(''), kAnonymousOwnerName);
    expect(ownerDisplayName('   '), kAnonymousOwnerName);
  });
}
