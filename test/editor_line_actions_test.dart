import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bisho_ide/core/services/editor_line_actions.dart';

void main() {
  group('EditorLineActions', () {
    test('duplicates the selected line and selects the duplicate', () {
      final result = EditorLineActions.duplicateSelectedLines(
        text: 'one\ntwo\nthree',
        selection: const TextSelection(baseOffset: 4, extentOffset: 7),
      );
      expect(result, isNotNull);
      expect(result!.text, 'one\ntwo\ntwo\nthree');
      expect(
        result.text.substring(result.selection.start, result.selection.end),
        'two',
      );
    });

    test('moves the current line down and keeps the cursor column', () {
      final result = EditorLineActions.moveCurrentLine(
        text: 'alpha\nbeta\ngamma',
        selection: const TextSelection.collapsed(offset: 2),
        down: true,
      );
      expect(result, isNotNull);
      expect(result!.text, 'beta\nalpha\ngamma');
      expect(result.selection.extentOffset, 7);
    });

    test('moves the current line up', () {
      final result = EditorLineActions.moveCurrentLine(
        text: 'alpha\nbeta',
        selection: const TextSelection.collapsed(offset: 8),
        down: false,
      );
      expect(result!.text, 'beta\nalpha');
    });

    test('toggles Python line comments without losing indentation', () {
      final result = EditorLineActions.toggleLineComments(
        text: '  print(1)\n  print(2)',
        selection: const TextSelection(baseOffset: 2, extentOffset: 19),
        language: 'Python',
      );
      expect(result, isNotNull);
      expect(result!.text, '  # print(1)\n  # print(2)');
      final undone = EditorLineActions.toggleLineComments(
        text: result.text,
        selection: result.selection,
        language: 'Python',
      );
      expect(undone!.text, '  print(1)\n  print(2)');
    });

    test('uses paired HTML comment delimiters', () {
      final result = EditorLineActions.toggleLineComments(
        text: '<p>Hello</p>',
        selection: const TextSelection.collapsed(offset: 2),
        language: 'HTML',
      );
      expect(result!.text, '<!-- <p>Hello</p> -->');
      expect(result.selection.isCollapsed, isTrue);
      final undone = EditorLineActions.toggleLineComments(
        text: result.text,
        selection: result.selection,
        language: 'HTML',
      );
      expect(undone!.text, '<p>Hello</p>');
    });


    test('clamps cursor column when moved to a shorter line', () {
      final result = EditorLineActions.moveCurrentLine(
        text: 'longline\nx',
        selection: const TextSelection.collapsed(offset: 7),
        down: true,
      );
      expect(result!.text, 'x\nlongline');
      expect(result.selection.extentOffset, 3);
    });

    test('duplicates a multi-line selection without duplicating next line', () {
      final result = EditorLineActions.duplicateSelectedLines(
        text: 'first\nsecond\nthird',
        selection: const TextSelection(baseOffset: 0, extentOffset: 12),
      );
      expect(result!.text, 'first\nsecond\nfirst\nsecond\nthird');
    });

    test('does not move a line beyond document boundaries', () {
      final result = EditorLineActions.moveCurrentLine(
        text: 'only',
        selection: const TextSelection.collapsed(offset: 1),
        down: true,
      );
      expect(result, isNull);
    });
  });
}
