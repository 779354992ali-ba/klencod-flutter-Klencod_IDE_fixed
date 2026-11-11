/// Finds the matching delimiter around the editor cursor.
///
/// This is a lightweight lexical scan, not a language parser. It skips common
/// quoted strings and comments so brackets in those regions are not matched.
class EditorBracketMatcher {
  const EditorBracketMatcher._();

  static int? findMatchingOffset({
    required String source,
    required int cursorOffset,
    required String language,
  }) {
    if (source.isEmpty) return null;
    final cursor = cursorOffset.clamp(0, source.length).toInt();
    final candidate = cursor < source.length && _isDelimiter(source[cursor])
        ? cursor
        : (cursor > 0 && _isDelimiter(source[cursor - 1]) ? cursor - 1 : -1);
    if (candidate < 0) return null;

    final target = source[candidate];
    final isOpening = '([{'.contains(target);
    final expected = isOpening ? _closeFor(target) : _openFor(target);
    if (expected == null) return null;

    final normalized = language.toLowerCase();
    final supportsSlashComments = <String>{
      'dart', 'javascript', 'typescript', 'java', 'kotlin', 'swift',
      'c', 'c++', 'go', 'rust', 'php',
    }.contains(normalized);
    final supportsHashComments = <String>{'python', 'bash', 'yaml'}.contains(normalized);
    final supportsHtmlComments = normalized == 'html' || normalized == 'xml';

    var quote = '';
    var tripleQuote = false;
    var escaped = false;
    var lineComment = false;
    var blockComment = false;
    var htmlComment = false;
    final stack = <({String char, int offset})>[];

    for (var i = 0; i < source.length; i++) {
      final ch = source[i];
      final next = i + 1 < source.length ? source[i + 1] : '';
      final third = i + 2 < source.length ? source[i + 2] : '';

      if (htmlComment) {
        if (ch == '-' && next == '-' && third == '>') {
          htmlComment = false;
          i += 2;
        }
        continue;
      }
      if (lineComment) {
        if (ch == '\n') lineComment = false;
        continue;
      }
      if (blockComment) {
        if (ch == '*' && next == '/') {
          blockComment = false;
          i++;
        }
        continue;
      }
      if (quote.isNotEmpty) {
        if (escaped) {
          escaped = false;
          continue;
        }
        if (ch == '\\') {
          escaped = true;
          continue;
        }
        if (tripleQuote) {
          if (ch == quote && next == quote && third == quote) {
            quote = '';
            tripleQuote = false;
            i += 2;
          }
        } else if (ch == quote) {
          quote = '';
        } else if (ch == '\n' && quote != '`') {
          quote = '';
        }
        continue;
      }

      if (supportsHtmlComments && source.startsWith('<!--', i)) {
        htmlComment = true;
        i += 3;
        continue;
      }
      if ((supportsSlashComments && ch == '/' && (next == '/' || next == '*')) ||
          ((normalized == 'sql') && ch == '-' && next == '-') ||
          (supportsHashComments && ch == '#')) {
        if (ch == '/' && next == '*') {
          blockComment = true;
        } else {
          lineComment = true;
        }
        if (next == ch) i++;
        continue;
      }
      if (ch == '"' || ch == "'" || ch == '`') {
        quote = ch;
        tripleQuote = normalized == 'python' &&
            (ch == '"' || ch == "'") && next == ch && third == ch;
        if (tripleQuote) i += 2;
        continue;
      }

      if (!_isDelimiter(ch)) continue;
      if (ch == '(' || ch == '[' || ch == '{') {
        stack.add((char: ch, offset: i));
      } else {
        final opening = _openFor(ch)!;
        if (stack.isEmpty || stack.last.char != opening) return null;
        final matched = stack.removeLast();
        if (isOpening && matched.offset == candidate) return i;
        if (!isOpening && i == candidate) return matched.offset;
      }
    }
    return null;
  }

  static bool _isDelimiter(String value) => '()[]{}'.contains(value);
  static String? _closeFor(String value) => const {'(': ')', '[': ']', '{': '}'}[value];
  static String? _openFor(String value) => const {')': '(', ']': '[', '}': '{'}[value];
}
