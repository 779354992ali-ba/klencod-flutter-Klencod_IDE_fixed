/// Ranks local editor snippets and language keywords for lightweight completion.
/// This is lexical assistance, not semantic IntelliSense or a language server.
class EditorCompletionEngine {
  const EditorCompletionEngine._();

  static final RegExp _identifierStart = RegExp(r'[A-Za-z_]');
  static final RegExp _identifierPart = RegExp(r'[A-Za-z0-9_]');

  static const Map<String, List<String>> _keywords = {
    'Dart': ['abstract', 'as', 'assert', 'async', 'await', 'class', 'const', 'enum', 'extends', 'final', 'factory', 'for', 'Future', 'if', 'implements', 'import', 'late', 'library', 'mixin', 'new', 'return', 'static', 'super', 'switch', 'this', 'throw', 'try', 'var', 'void', 'while', 'with'],
    'JavaScript': ['async', 'await', 'break', 'case', 'catch', 'class', 'const', 'continue', 'debugger', 'else', 'export', 'extends', 'finally', 'for', 'function', 'if', 'import', 'let', 'new', 'return', 'switch', 'throw', 'try', 'var', 'while', 'yield'],
    'TypeScript': ['any', 'boolean', 'class', 'const', 'enum', 'export', 'extends', 'function', 'implements', 'interface', 'keyof', 'let', 'never', 'number', 'private', 'protected', 'public', 'readonly', 'return', 'string', 'type', 'unknown', 'void'],
    'Python': ['and', 'as', 'assert', 'async', 'await', 'break', 'class', 'continue', 'def', 'del', 'elif', 'else', 'except', 'False', 'finally', 'for', 'from', 'global', 'if', 'import', 'in', 'is', 'lambda', 'None', 'nonlocal', 'not', 'or', 'pass', 'raise', 'return', 'True', 'try', 'while', 'with', 'yield'],
    'HTML': ['article', 'aside', 'body', 'button', 'div', 'footer', 'form', 'h1', 'h2', 'head', 'header', 'html', 'img', 'input', 'label', 'li', 'link', 'main', 'meta', 'nav', 'ol', 'p', 'script', 'section', 'span', 'style', 'table', 'title', 'ul'],
    'CSS': ['align-items', 'animation', 'background', 'border', 'box-shadow', 'color', 'display', 'flex', 'font-family', 'font-size', 'gap', 'grid', 'height', 'justify-content', 'margin', 'max-width', 'padding', 'position', 'transform', 'transition', 'width'],
    'SQL': ['ALTER TABLE', 'CREATE TABLE', 'DELETE FROM', 'FROM', 'GROUP BY', 'INSERT INTO', 'JOIN', 'LIMIT', 'ORDER BY', 'SELECT', 'UPDATE', 'VALUES', 'WHERE'],
  };

  /// Returns unique candidates ordered by relevance while preserving stable
  /// source order for candidates with the same score.
  static List<String> rank({
    required String language,
    required String prefix,
    required Iterable<String> snippets,
    int maximumResults = 50,
  }) {
    final all = <String>[];
    final seen = <String>{};
    for (final item in [...? _keywords[language], ...snippets]) {
      final value = item.trimLeft();
      if (value.isNotEmpty && seen.add(value.toLowerCase())) all.add(value);
    }
    if (maximumResults <= 0 || all.isEmpty) return const [];
    if (prefix.isEmpty) {
      return all.take(maximumResults).toList(growable: false);
    }

    final needle = prefix.toLowerCase();
    final scored = <({String value, int score, int order})>[];
    for (var i = 0; i < all.length; i++) {
      final value = all[i];
      final lower = value.toLowerCase();
      final index = lower.indexOf(needle);
      if (index == 0) {
        scored.add((value: value, score: 0, order: i));
      } else if (index > 0 && _isWordBoundary(value, index)) {
        scored.add((value: value, score: 1, order: i));
      } else if (index > 0) {
        scored.add((value: value, score: 2, order: i));
      } else if (_isSubsequence(needle, lower)) {
        scored.add((value: value, score: 3, order: i));
      }
    }
    scored.sort((a, b) {
      final byScore = a.score.compareTo(b.score);
      return byScore != 0 ? byScore : a.order.compareTo(b.order);
    });
    return scored
        .take(maximumResults)
        .map((item) => item.value)
        .toList(growable: false);
  }

  /// Extracts identifiers already used in source code for project-local
  /// completion. Quoted strings and common comments are skipped so prose does
  /// not pollute the suggestions. This remains lexical, not semantic analysis.
  static List<String> identifiersIn(
    String source, {
    required String language,
    int maximumResults = 100,
  }) {
    if (source.isEmpty || maximumResults <= 0) return const [];
    final normalized = language.toLowerCase();
    final slashComments = <String>{
      'dart', 'javascript', 'typescript', 'java', 'kotlin', 'swift',
      'c', 'c++', 'go', 'rust', 'php',
    }.contains(normalized);
    final hashComments = <String>{'python', 'bash', 'yaml'}.contains(normalized);
    final htmlComments = normalized == 'html' || normalized == 'xml';
    final result = <String>[];
    final seen = <String>{};
    var quote = '';
    var tripleQuote = false;
    var escaped = false;
    var lineComment = false;
    var blockComment = false;
    var htmlComment = false;
    var i = 0;

    while (i < source.length) {
      final ch = source[i];
      final next = i + 1 < source.length ? source[i + 1] : '';
      final third = i + 2 < source.length ? source[i + 2] : '';
      if (htmlComment) {
        if (ch == '-' && next == '-' && third == '>') {
          htmlComment = false;
          i += 3;
        } else {
          i++;
        }
        continue;
      }
      if (lineComment) {
        if (ch == '\n') lineComment = false;
        i++;
        continue;
      }
      if (blockComment) {
        if (ch == '*' && next == '/') {
          blockComment = false;
          i += 2;
        } else {
          i++;
        }
        continue;
      }
      if (quote.isNotEmpty) {
        if (escaped) {
          escaped = false;
          i++;
          continue;
        }
        if (ch == '\\') {
          escaped = true;
          i++;
          continue;
        }
        if (tripleQuote) {
          if (ch == quote && next == quote && third == quote) {
            quote = '';
            tripleQuote = false;
            i += 3;
          } else {
            i++;
          }
          continue;
        }
        if (ch == quote || (ch == '\n' && quote != '`')) quote = '';
        i++;
        continue;
      }
      if (htmlComments && source.startsWith('<!--', i)) {
        htmlComment = true;
        i += 4;
        continue;
      }
      if (slashComments && ch == '/' && next == '/') {
        lineComment = true;
        i += 2;
        continue;
      }
      if (normalized == 'sql' && ch == '-' && next == '-') {
        lineComment = true;
        i += 2;
        continue;
      }
      if (hashComments && ch == '#') {
        lineComment = true;
        i++;
        continue;
      }
      if (ch == '/' && next == '*') {
        blockComment = true;
        i += 2;
        continue;
      }
      if (ch == '\'' || ch == '"' || ch == '`') {
        quote = ch;
        tripleQuote = normalized == 'python' &&
            (ch == '\'' || ch == '"') && next == ch && third == ch;
        i += tripleQuote ? 3 : 1;
        continue;
      }
      if (_identifierStart.hasMatch(ch)) {
        final start = i++;
        while (i < source.length &&
            _identifierPart.hasMatch(source[i])) {
          i++;
        }
        final identifier = source.substring(start, i);
        if (identifier.length > 1 && seen.add(identifier.toLowerCase())) {
          result.add(identifier);
          if (result.length >= maximumResults) break;
        }
        continue;
      }
      i++;
    }
    return result;
  }

  static bool _isWordBoundary(String value, int index) {
    final previous = value[index - 1];
    return !_identifierPart.hasMatch(previous);
  }

  static bool _isSubsequence(String needle, String value) {
    var index = 0;
    for (var i = 0; i < value.length && index < needle.length; i++) {
      if (value[i] == needle[index]) index++;
    }
    return index == needle.length;
  }
}
