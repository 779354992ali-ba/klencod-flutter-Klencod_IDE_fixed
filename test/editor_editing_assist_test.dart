import 'package:flutter_test/flutter_test.dart';
import 'package:bisho_ide/core/services/editor_editing_assist.dart';

void main() {
  group('EditorEditingAssist', () {
    test('skips an existing closer instead of duplicating it', () {
      final result = EditorEditingAssist.skipExistingClosingDelimiter(
        previousText: '()',
        currentText: '())',
        cursorOffset: 2,
      );
      expect(result, isNotNull);
      expect(result!.text, '()');
      expect(result.cursorOffset, 2);
    });

    test('backspace removes the matching closer with its opener', () {
      final result = EditorEditingAssist.deletePairedOpeningDelimiter(
        previousText: '()',
        currentText: ')',
        cursorOffset: 0,
      );
      expect(result, isNotNull);
      expect(result!.text, '');
      expect(result.cursorOffset, 0);
    });

    test('copies indentation on a normal newline', () {
      final result = EditorEditingAssist.autoIndentNewline(
        previousText: '  print(1);',
        currentText: '  print(1);\n',
        cursorOffset: 12,
      );
      expect(result, isNotNull);
      expect(result!.text, '  print(1);\n  ');
      expect(result.cursorOffset, 14);
    });

    test('indents one level after an opening brace', () {
      final result = EditorEditingAssist.autoIndentNewline(
        previousText: '  {',
        currentText: '  {\n',
        cursorOffset: 4,
      );
      expect(result, isNotNull);
      expect(result!.text, '  {\n    ');
      expect(result.cursorOffset, 8);
    });

    test('creates an inner line and aligns a matching closing brace', () {
      final result = EditorEditingAssist.autoIndentNewline(
        previousText: '{}',
        currentText: '{\n}',
        cursorOffset: 2,
      );
      expect(result, isNotNull);
      expect(result!.text, '{\n  \n}');
      expect(result.cursorOffset, 4);
    });

    test('does not alter a multi-character paste', () {
      final result = EditorEditingAssist.autoIndentNewline(
        previousText: 'abc',
        currentText: 'a\n  bc',
        cursorOffset: 3,
      );
      expect(result, isNull);
    });
  });
}
