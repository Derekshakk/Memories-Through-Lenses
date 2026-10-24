import 'package:flutter_test/flutter_test.dart';
import 'package:memories_through_lenses/services/username.dart';

void main() {
  group('Username.validate', () {
    test('accepts names up to the limit', () {
      expect(Username.validate('a' * Username.maxLength), isNull);
    });

    test('rejects names over the limit and empty names', () {
      expect(Username.validate('a' * (Username.maxLength + 1)), isNotNull);
      expect(Username.validate('   '), isNotNull);
    });

    test('allows re-saving an unchanged legacy over-limit name', () {
      final legacy = 'x' * 500;
      expect(Username.validate(legacy, previous: legacy), isNull);
      expect(Username.validate('${legacy}y', previous: legacy), isNotNull);
    });

    test('counts characters, not UTF-16 units', () {
      expect(Username.validate('😀' * Username.maxLength), isNull);
    });
  });

  group('Username.displayName', () {
    test('truncates oversized names with an ellipsis', () {
      final shown = Username.displayName('n' * 5000);
      expect(shown.runes.length, Username.maxDisplayLength + 1);
      expect(shown.endsWith('…'), isTrue);
    });

    test('collapses whitespace and line breaks', () {
      expect(Username.displayName('  Jane \n\n  Doe '), 'Jane Doe');
    });

    test('never splits an emoji', () {
      final shown = Username.displayName('😀' * 100);
      expect(shown, '${'😀' * Username.maxDisplayLength}…');
    });

    test('falls back for missing or non-string names', () {
      expect(Username.displayName(null), 'Unknown User');
      expect(Username.displayName(42, fallback: 'User'), 'User');
      expect(Username.displayName('   '), 'Unknown User');
    });
  });
}
