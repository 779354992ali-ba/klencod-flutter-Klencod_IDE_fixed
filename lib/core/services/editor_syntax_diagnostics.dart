/// Lightweight, dependency-free structural diagnostics for common source files.
/// This is not a compiler or a full language parser.
class EditorSyntaxDiagnostic {
  final int offset;
  final int line;
  final int column;
  final String message;

  const EditorSyntaxDiagnostic({
    required this.offset,
    required this.line,
    required this.column,
    required this.message,
  });

  @override
  String toString() => 'السطر $line، العمود $column: $message';
}

class EditorSyntaxDiagnostics {
  const EditorSyntaxDiagnostics._();

  static const _supported = <String>{
    'dart', 'javascript', 'typescript', 'java', 'kotlin', 'swift',
    'c', 'c++', 'go', 'rust', 'php', 'python', 'bash', 'json',
    'css', 'sql', 'html', 'xml', 'c#', 'csharp', 'scala',
    'groovy', 'objective-c', 'objc', 'ruby', 'perl', 'r', 'yaml', 'yml',
  };

  static List<EditorSyntaxDiagnostic> analyze(String source, String language) {
    if (!_supported.contains(language.toLowerCase())) return const [];

    final stack = <({String char, int offset})>[];
    final diagnostics = <EditorSyntaxDiagnostic>[];
    var quote = '';
    var tripleQuote = false;
    var escaped = false;
    var lineComment = false;
    var blockComment = false;
    var blockCommentDepth = 0;
    var htmlComment = false;
    var rawStringTerminator = '';
    final normalizedLanguage = language.toLowerCase();
    final nestedComments = normalizedLanguage == 'rust' ||
        normalizedLanguage == 'kotlin' || normalizedLanguage == 'swift';
    const hashCommentLanguages = <String>{'python', 'bash', 'ruby', 'perl', 'r', 'yaml', 'yml'};
    const slashCommentLanguages = <String>{
      'dart', 'javascript', 'typescript', 'java', 'kotlin', 'swift',
      'c', 'c++', 'go', 'rust', 'php', 'c#', 'csharp',
      'scala', 'groovy', 'objective-c', 'objc',
    };

    int lineAt(int offset) => '\n'.allMatches(source.substring(0, offset)).length + 1;
    int columnAt(int offset) {
      final previousNewline = offset == 0 ? -1 : source.lastIndexOf('\n', offset - 1);
      return offset - previousNewline;
    }

    void report(int offset, String message) {
      diagnostics.add(EditorSyntaxDiagnostic(
        offset: offset,
        line: lineAt(offset),
        column: columnAt(offset),
        message: message,
      ));
    }

    for (var i = 0; i < source.length; i++) {
      final ch = source[i];
      final next = i + 1 < source.length ? source[i + 1] : '';
      final third = i + 2 < source.length ? source[i + 2] : '';

      if (rawStringTerminator.isNotEmpty) {
        if (source.startsWith(rawStringTerminator, i)) {
          i += rawStringTerminator.length - 1;
          rawStringTerminator = '';
        }
        continue;
      }
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
        if (nestedComments && ch == '/' && next == '*') {
          blockCommentDepth++;
          i++;
        } else if (ch == '*' && next == '/') {
          blockCommentDepth--;
          if (blockCommentDepth <= 0) {
            blockComment = false;
            blockCommentDepth = 0;
          }
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
          // A newline terminates ordinary single/double quoted strings in
          // these languages; do not report a string error here because some
          // editors intentionally hold incomplete code while typing.
          quote = '';
        }
        continue;
      }

      if ((language.toLowerCase() == 'html' || language.toLowerCase() == 'xml') &&
          source.startsWith('<!--', i)) {
        htmlComment = true;
        i += 3;
        continue;
      }
      if ((slashCommentLanguages.contains(normalizedLanguage) && ch == '/' && next == '/') ||
          (normalizedLanguage == 'sql' && ch == '-' && next == '-') ||
          (hashCommentLanguages.contains(normalizedLanguage) && ch == '#')) {
        lineComment = true;
        if ((ch == '/' || ch == '-') && next == ch) i++;
        continue;
      }
      if (ch == '/' && next == '*') {
        blockComment = true;
        blockCommentDepth = 1;
        i++;
        continue;
      }
      // Rust raw strings: r#"..."#, r##"..."## and byte-string variants.
      if (normalizedLanguage == 'rust' &&
          (ch == 'r' || (ch == 'b' && next == 'r'))) {
        final prefixLength = ch == 'b' ? 2 : 1;
        var hashEnd = i + prefixLength;
        while (hashEnd < source.length && source[hashEnd] == '#') {
          hashEnd++;
        }
        if (hashEnd < source.length && source[hashEnd] == '"') {
          final hashes = source.substring(i + prefixLength, hashEnd);
          rawStringTerminator = '"$hashes';
          i = hashEnd;
          continue;
        }
      }
      // C++ raw strings use R"delimiter(... )delimiter".
      if (normalizedLanguage == 'c++' && ch == 'R' && next == '"') {
        final openParen = source.indexOf('(', i + 2);
        if (openParen != -1 && openParen - (i + 2) <= 16) {
          final delimiter = source.substring(i + 2, openParen);
          if (!delimiter.contains(RegExp(r'[\s\\()]'))) {
            rawStringTerminator = ')$delimiter"';
            i = openParen;
            continue;
          }
        }
      }
      if (ch == '"' || ch == "'" || ch == '`') {
        quote = ch;
        tripleQuote = (language.toLowerCase() == 'python' &&
            (ch == '"' || ch == "'") && next == ch && third == ch);
        if (tripleQuote) i += 2;
        continue;
      }

      if (ch == '(' || ch == '[' || ch == '{') {
        stack.add((char: ch, offset: i));
      } else if (ch == ')' || ch == ']' || ch == '}') {
        final expected = ch == ')' ? '(' : (ch == ']' ? '[' : '{');
        if (stack.isEmpty) {
          report(i, 'قوس إغلاق "$ch" دون قوس فتح مطابق');
        } else if (stack.last.char != expected) {
          final opened = stack.removeLast();
          report(i, 'القوس "$ch" لا يطابق "${opened.char}" المفتوح في السطر ${lineAt(opened.offset)}');
        } else {
          stack.removeLast();
        }
      }
    }

    for (final opened in stack) {
      final closing = opened.char == '(' ? ')' : (opened.char == '[' ? ']' : '}');
      report(opened.offset, 'قوس الفتح "${opened.char}" بلا إغلاق "$closing"');
    }

    diagnostics.sort((a, b) => a.offset.compareTo(b.offset));
    return diagnostics;
  }
}
