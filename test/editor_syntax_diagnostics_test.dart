import 'package:flutter_test/flutter_test.dart';
import 'package:bisho_ide/core/services/editor_syntax_diagnostics.dart';

void main() {
  group('EditorSyntaxDiagnostics', () {
    test('reports an unmatched opening delimiter with its location', () {
      final result = EditorSyntaxDiagnostics.analyze(
        'void main() {\n  print(1);',
        'Dart',
      );
      expect(result, hasLength(1));
      expect(result.single.line, 1);
      expect(result.single.message, contains('بلا إغلاق'));
    });

    test('ignores delimiters inside strings and line comments', () {
      final result = EditorSyntaxDiagnostics.analyze(
        'final text = "{[(]})"; // ( [ {\nprint(text);',
        'Dart',
      );
      expect(result, isEmpty);
    });

    test('ignores delimiters inside block comments', () {
      final result = EditorSyntaxDiagnostics.analyze(
        '/* {[( */\nvoid main() {}',
        'Dart',
      );
      expect(result, isEmpty);
    });

    test('reports an unexpected closing delimiter', () {
      final result = EditorSyntaxDiagnostics.analyze('print(1));', 'Dart');
      expect(result, hasLength(1));
      expect(result.single.column, 9);
    });

    test('reports mismatched delimiter types', () {
      final result = EditorSyntaxDiagnostics.analyze('([)]', 'JavaScript');
      expect(result, isNotEmpty);
      expect(result.first.message, contains('لا يطابق'));
    });

    test('supports Python comments and triple quoted strings', () {
      final result = EditorSyntaxDiagnostics.analyze(
        'value = """{ [ ( } ] )"""\n# } ] )\nprint(value)',
        'Python',
      );
      expect(result, isEmpty);
    });


    test('ignores HTML and XML comment contents', () {
      final result = EditorSyntaxDiagnostics.analyze(
        '<!-- { [ ( -->\n<root></root>',
        'XML',
      );
      expect(result, isEmpty);
    });

    test('ignores SQL line comments', () {
      final result = EditorSyntaxDiagnostics.analyze(
        'select (1); -- } ] )\nselect (2);',
        'SQL',
      );
      expect(result, isEmpty);
    });


    test('supports Ruby and Perl hash comments without false bracket errors', () {
      expect(EditorSyntaxDiagnostics.analyze('value = 1 # } ] )', 'Ruby'), isEmpty);
      expect(EditorSyntaxDiagnostics.analyze(r'$value = 1; # } ] )', 'Perl'), isEmpty);
    });

    test('supports structural checks for C sharp and Scala source', () {
      expect(EditorSyntaxDiagnostics.analyze('class A { void Run() { }', 'C#'),
          hasLength(1));
      expect(EditorSyntaxDiagnostics.analyze('object A { def run = { 1 } }', 'Scala'),
          isEmpty);
    });


    test('ignores YAML hash comments during structural checks', () {
      expect(EditorSyntaxDiagnostics.analyze('key: value # } ] )\nlist: [one, two]', 'YAML'), isEmpty);
    });

    test('handles nested Kotlin and Rust block comments', () {
      expect(
        EditorSyntaxDiagnostics.analyze(
          '/* outer /* inner { [ */ still comment */ fun main() {}',
          'Kotlin',
        ),
        isEmpty,
      );
      expect(
        EditorSyntaxDiagnostics.analyze(
          '/* outer /* inner { [ */ still comment */ fn main() {}',
          'Rust',
        ),
        isEmpty,
      );
    });

    test('ignores delimiters inside Rust raw strings', () {
      expect(
        EditorSyntaxDiagnostics.analyze(
          'let value = r##"{ [ ( ] }"##; fn main() {}',
          'Rust',
        ),
        isEmpty,
      );
    });

    test('ignores delimiters inside C++ raw strings', () {
      expect(
        EditorSyntaxDiagnostics.analyze(
          'auto text = R"tag({ [ ( ] })tag"; int main() {}',
          'C++',
        ),
        isEmpty,
      );
    });

    test('does not claim diagnostics for unsupported languages', () {
      expect(EditorSyntaxDiagnostics.analyze('([', 'Dart Flutter'), isEmpty);
    });
  });
}
