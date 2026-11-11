import 'package:flutter_test/flutter_test.dart';
import 'package:bisho_ide/core/services/editor_bracket_matcher.dart';

void main() {
  group('EditorBracketMatcher', () {
    test('matches nested opening delimiter from cursor', () {
      const source = 'call([value])';
      expect(
        EditorBracketMatcher.findMatchingOffset(
          source: source,
          cursorOffset: 5,
          language: 'JavaScript',
        ),
        11,
      );
    });

    test('matches closing delimiter immediately before cursor', () {
      const source = 'items[0]';
      expect(
        EditorBracketMatcher.findMatchingOffset(
          source: source,
          cursorOffset: source.length,
          language: 'Dart',
        ),
        5,
      );
    });

    test('ignores delimiters in strings and comments', () {
      const source = 'final s = "}"; // ]\nrun({});';
      expect(
        EditorBracketMatcher.findMatchingOffset(
          source: source,
          cursorOffset: source.indexOf('{'),
          language: 'Dart',
        ),
        source.lastIndexOf('}'),
      );
    });

    test('returns null for malformed or absent pairs', () {
      expect(
        EditorBracketMatcher.findMatchingOffset(
          source: '([)]',
          cursorOffset: 0,
          language: 'JavaScript',
        ),
        isNull,
      );
      expect(
        EditorBracketMatcher.findMatchingOffset(
          source: 'plain text',
          cursorOffset: 3,
          language: 'Dart',
        ),
        isNull,
      );
    });
  });
}
