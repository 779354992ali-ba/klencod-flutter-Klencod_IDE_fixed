/// Small, deterministic editing helpers used by the Bisho IDE editor.
///
/// The helpers only transform a single character typed at the caret. They do
/// not run for paste operations, selections, undo/redo, or multi-character
/// replacements, which keeps normal editing behavior predictable.
class EditorEditResult {
  final String text;
  final int cursorOffset;

  const EditorEditResult({required this.text, required this.cursorOffset});
}

class EditorEditingAssist {
  const EditorEditingAssist._();


  /// Skips over an already-present closing delimiter when the user types it.
  /// This prevents duplicate closers after automatic pair insertion.
  static EditorEditResult? skipExistingClosingDelimiter({
    required String previousText,
    required String currentText,
    required int cursorOffset,
  }) {
    if (currentText.length != previousText.length + 1) return null;
    if (cursorOffset < 1 || cursorOffset > currentText.length) return null;

    final insertionOffset = cursorOffset - 1;
    if (currentText.substring(0, insertionOffset) !=
        previousText.substring(0, insertionOffset)) {
      return null;
    }
    if (currentText.substring(cursorOffset) !=
        previousText.substring(insertionOffset)) {
      return null;
    }

    const closers = <String>{')', ']', '}', '\'', '\"', '`'};
    final typed = currentText[insertionOffset];
    if (!closers.contains(typed) ||
        insertionOffset + 1 >= currentText.length ||
        currentText[insertionOffset + 1] != typed) {
      return null;
    }

    return EditorEditResult(
      text: currentText.replaceRange(insertionOffset, cursorOffset, ''),
      cursorOffset: cursorOffset,
    );
  }

  /// Removes the matching closer when Backspace deletes its opening pair.
  /// Only a one-character backspace at a collapsed caret is recognized.
  static EditorEditResult? deletePairedOpeningDelimiter({
    required String previousText,
    required String currentText,
    required int cursorOffset,
  }) {
    if (currentText.length != previousText.length - 1) return null;
    if (cursorOffset < 0 || cursorOffset > currentText.length) return null;

    final deletedOffset = cursorOffset;
    if (currentText.substring(0, deletedOffset) !=
        previousText.substring(0, deletedOffset) ||
        currentText.substring(deletedOffset) !=
            previousText.substring(deletedOffset + 1)) {
      return null;
    }

    const pairs = <String, String>{
      '(': ')', '[': ']', '{': '}',
      '\'': '\'', '\"': '\"', '`': '`',
    };
    final expectedCloser = pairs[previousText[deletedOffset]];
    if (expectedCloser == null ||
        deletedOffset >= currentText.length ||
        currentText[deletedOffset] != expectedCloser) {
      return null;
    }

    return EditorEditResult(
      text: currentText.replaceRange(deletedOffset, deletedOffset + 1, ''),
      cursorOffset: deletedOffset,
    );
  }

  /// Adds the current line indentation after Enter.
  ///
  /// When Enter is pressed immediately between an opening and closing brace,
  /// bracket, or parenthesis, the caret is indented one level and the closing
  /// delimiter is moved to a following line at the original indentation.
  /// Returns null when the edit is not a single newline insertion at the
  /// cursor, so paste and multi-line edits remain untouched.
  static EditorEditResult? autoIndentNewline({
    required String previousText,
    required String currentText,
    required int cursorOffset,
    String indentUnit = '  ',
  }) {
    if (currentText.length != previousText.length + 1) return null;
    if (cursorOffset < 1 || cursorOffset > currentText.length) return null;

    final newlineOffset = cursorOffset - 1;
    if (currentText[newlineOffset] != '\n') return null;

    if (currentText.substring(0, newlineOffset) !=
        previousText.substring(0, newlineOffset)) {
      return null;
    }
    if (currentText.substring(cursorOffset) !=
        previousText.substring(newlineOffset)) {
      return null;
    }

    final lineStart = currentText.lastIndexOf('\n', newlineOffset - 1) + 1;
    final lineBeforeNewline = currentText.substring(lineStart, newlineOffset);
    final indentationMatch = RegExp(r'^[\t ]*').firstMatch(lineBeforeNewline);
    final baseIndent = indentationMatch?.group(0) ?? '';
    final trimmedLine = lineBeforeNewline.trimRight();
    final opensBlock = trimmedLine.endsWith('{') ||
        trimmedLine.endsWith('[') ||
        trimmedLine.endsWith('(');

    final suffix = currentText.substring(cursorOffset);
    final matchingClose = opensBlock && suffix.isNotEmpty &&
        ((trimmedLine.endsWith('{') && suffix.startsWith('}')) ||
            (trimmedLine.endsWith('[') && suffix.startsWith(']')) ||
            (trimmedLine.endsWith('(') && suffix.startsWith(')')));

    final innerIndent = opensBlock ? '$baseIndent$indentUnit' : baseIndent;
    final insertion = matchingClose
        ? '$innerIndent\n$baseIndent'
        : innerIndent;
    final updatedText = currentText.replaceRange(
      cursorOffset,
      cursorOffset,
      insertion,
    );

    return EditorEditResult(
      text: updatedText,
      cursorOffset: cursorOffset + innerIndent.length,
    );
  }
}
