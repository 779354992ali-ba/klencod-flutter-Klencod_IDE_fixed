import 'package:flutter_test/flutter_test.dart';
import 'package:bisho_ide/core/services/editor_completion_engine.dart';

void main() {
  group('EditorCompletionEngine', () {
    test('puts prefix matches before inner substring matches', () {
      final result = EditorCompletionEngine.rank(
        language: 'JavaScript',
        prefix: 'con',
        snippets: ['function ', 'console.log()', 'const '],
      );
      expect(result.first, 'console.log()');
      expect(result, contains('const '));
    });

    test('includes language keywords and supplied snippets', () {
      final result = EditorCompletionEngine.rank(
        language: 'Python',
        prefix: 'def',
        snippets: ['print()', 'def '],
      );
      expect(result, contains('def'));
      expect(result, contains('def '));
      expect(result, isNot(contains('print()')));
    });

    test('supports subsequence matching when no direct match exists', () {
      final result = EditorCompletionEngine.rank(
        language: 'CSS',
        prefix: 'dsp',
        snippets: const [],
      );
      expect(result, contains('display'));
    });

    test('returns all unique options when prefix is empty', () {
      final result = EditorCompletionEngine.rank(
        language: 'Dart',
        prefix: '',
        snippets: ['class ', 'CUSTOM'],
      );
      expect(result.where((item) => item.toLowerCase() == 'class'), hasLength(1));
      expect(result, contains('CUSTOM'));
    });

    test('extracts project identifiers but skips strings and comments', () {
      final result = EditorCompletionEngine.identifiersIn(
        'final customerName = "hiddenString";\n// hiddenComment\nvoid greetCustomer() { print(customerName); }',
        language: 'Dart',
      );
      expect(result, contains('customerName'));
      expect(result, contains('greetCustomer'));
      expect(result, isNot(contains('hiddenString')));
      expect(result, isNot(contains('hiddenComment')));
    });

    test('handles Python triple-quoted strings and SQL line comments', () {
      final python = EditorCompletionEngine.identifiersIn(
        '"""hiddenName\nmoreHidden"""\nvisibleName = 1',
        language: 'Python',
      );
      expect(python, contains('visibleName'));
      expect(python, isNot(contains('hiddenName')));

      final sql = EditorCompletionEngine.identifiersIn(
        'SELECT customer_id FROM customers -- hiddenColumn\nWHERE active = 1',
        language: 'SQL',
      );
      expect(sql, contains('customer_id'));
      expect(sql, isNot(contains('hiddenColumn')));
    });

    test('limits returned completion results', () {
      final result = EditorCompletionEngine.rank(
        language: 'Python',
        prefix: '',
        snippets: const ['customOne', 'customTwo'],
        maximumResults: 3,
      );
      expect(result, hasLength(3));
    });

    test('does not return unrelated options for an unmatched prefix', () {
      final result = EditorCompletionEngine.rank(
        language: 'JavaScript',
        prefix: 'zzq',
        snippets: ['console.log()', 'function '],
      );
      expect(result, isEmpty);
    });
  });
}
