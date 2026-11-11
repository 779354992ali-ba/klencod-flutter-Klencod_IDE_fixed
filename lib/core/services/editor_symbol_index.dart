/// Lightweight, file-local symbol index for editor navigation.
/// This is a lexical index, not a compiler or language server.
class EditorSymbol {
  const EditorSymbol({required this.name, required this.kind, required this.line, required this.offset});
  final String name;
  final String kind;
  final int line;
  final int offset;
}

class EditorSymbolUsage {
  const EditorSymbolUsage({required this.name, required this.line, required this.offset, required this.isDefinition});
  final String name;
  final int line;
  final int offset;
  final bool isDefinition;
}

class EditorSymbolIndex {
  const EditorSymbolIndex._();

  static final List<({RegExp pattern, String kind})> _patterns = [
    (pattern: RegExp(r'^\s*(?:abstract\s+|sealed\s+|final\s+)?class\s+([A-Za-z_$][\w$]*)'), kind: 'class'),
    (pattern: RegExp(r'^\s*(?:abstract\s+)?interface\s+([A-Za-z_$][\w$]*)'), kind: 'interface'),
    (pattern: RegExp(r'^\s*(?:enum|mixin|typedef|struct|union|record)\s+([A-Za-z_$][\w$]*)'), kind: 'type'),
    (pattern: RegExp(r'^\s*(?:pub\s+)?(?:async\s+)?fn\s+([A-Za-z_][\w]*)'), kind: 'function'),
    (pattern: RegExp(r'^\s*(?:pub\s+)?(?:async\s+)?fun\s+([A-Za-z_][\w]*)'), kind: 'function'),
    (pattern: RegExp(r'^\s*(?:public\s+|private\s+|protected\s+|static\s+|final\s+|override\s+)*func\s+([A-Za-z_][\w]*)'), kind: 'function'),
    (pattern: RegExp(r'^\s*func\s+([A-Za-z_][\w]*)'), kind: 'function'),
    (pattern: RegExp(r'^\s*type\s+([A-Za-z_][\w]*)\s+(?:struct|interface)'), kind: 'type'),
    (pattern: RegExp(r'^\s*(?:export\s+)?(?:async\s+)?function\s+\*?([A-Za-z_$][\w$]*)'), kind: 'function'),
    (pattern: RegExp(r'^\s*(?:async\s+)?def\s+([A-Za-z_][\w]*)'), kind: 'function'),
    (pattern: RegExp(r'^\s*(?:[\w<>?,\[\]]+\s+)+([A-Za-z_$][\w$]*)\s*\([^;]*\)\s*(?:\{|=>)'), kind: 'method'),
    (pattern: RegExp(r'^\s*(?:const|let|var|final|static)\s+([A-Za-z_$][\w$]*)'), kind: 'variable'),
    (pattern: RegExp(r'^\s*([A-Za-z_][\w]*)\s*=\s*(?:function|\([^)]*\)\s*=>)'), kind: 'function'),
    (pattern: RegExp(r'^\s*<([A-Za-z][A-Za-z0-9-]*)\b'), kind: 'tag'),
    (pattern: RegExp(r'^\s*([.#][A-Za-z_-][\w-]*)\s*\{'), kind: 'selector'),
  ];

  /// Replaces comments and quoted text with spaces while preserving newlines
  /// and offsets, so declarations inside prose are not indexed.
  static String _maskNonCode(String source, String language) {
    final chars = source.split('');
    final slashComments = language.isEmpty || <String>{
      'dart', 'javascript', 'typescript', 'java', 'kotlin', 'swift',
      'c', 'c++', 'go', 'rust', 'php', 'css', 'json',
    }.contains(language);
    final hashComments = <String>{'python', 'bash', 'yaml', 'ruby', 'shell'}.contains(language);
    final htmlComments = language == 'html' || language == 'xml';
    var quote = '';
    var triple = false;
    var escaped = false;
    var lineComment = false;
    var blockDepth = 0;
    var htmlComment = false;
    for (var i = 0; i < chars.length; i++) {
      final ch = chars[i];
      final next = i + 1 < chars.length ? chars[i + 1] : '';
      final third = i + 2 < chars.length ? chars[i + 2] : '';
      if (htmlComment) {
        if (ch == '-' && next == '-' && third == '>') {
          chars[i] = chars[i + 1] = chars[i + 2] = ' ';
          i += 2;
          htmlComment = false;
        } else if (ch != '\n') { chars[i] = ' '; }
        continue;
      }
      if (lineComment) {
        if (ch == '\n') { lineComment = false; } else { chars[i] = ' '; }
        continue;
      }
      if (blockDepth > 0) {
        if (ch == '/' && next == '*' && <String>{'rust', 'swift', 'kotlin'}.contains(language)) {
          chars[i] = chars[i + 1] = ' ';
          blockDepth++;
          i++;
        } else if (ch == '*' && next == '/') {
          chars[i] = chars[i + 1] = ' ';
          blockDepth--;
          i++;
        } else if (ch != '\n') { chars[i] = ' '; }
        continue;
      }
      if (quote.isNotEmpty) {
        if (ch != '\n') chars[i] = ' ';
        if (escaped) { escaped = false; continue; }
        if (ch == r'\') { escaped = true; continue; }
        if (triple) {
          if (ch == quote && next == quote && third == quote) {
            chars[i] = chars[i + 1] = chars[i + 2] = ' ';
            i += 2;
            quote = '';
            triple = false;
          }
        } else if (ch == quote || (ch == '\n' && quote != '`')) { quote = ''; }
        continue;
      }
      if (htmlComments && source.startsWith('<!--', i)) {
        htmlComment = true;
        chars[i] = chars[i + 1] = chars[i + 2] = chars[i + 3] = ' ';
        i += 3;
        continue;
      }
      if (slashComments && ch == '/' && next == '/') {
        lineComment = true;
        chars[i] = chars[i + 1] = ' ';
        i++;
        continue;
      }
      if (hashComments && ch == '#') { lineComment = true; chars[i] = ' '; continue; }
      if (ch == '-' && next == '-' && language == 'sql') {
        lineComment = true; chars[i] = chars[i + 1] = ' '; i++; continue;
      }
      if (ch == '/' && next == '*') {
        blockDepth = 1; chars[i] = chars[i + 1] = ' '; i++; continue;
      }
      if (ch == '"' || ch == "'" || ch == '`') {
        quote = ch;
        triple = language == 'python' && ch != '`' && next == ch && third == ch;
        chars[i] = ' ';
        if (triple) { chars[i + 1] = chars[i + 2] = ' '; i += 2; }
      }
    }
    return chars.join();
  }

  /// Finds lexical occurrences of a symbol in this file. Comments and strings
  /// are masked first; this is intentionally not semantic cross-file analysis.
  static List<EditorSymbolUsage> findUsages(
    String source,
    EditorSymbol symbol, {
    String language = '',
    int maximumResults = 1000,
  }) {
    if (source.isEmpty || symbol.name.isEmpty || maximumResults <= 0) return const [];
    final searchable = _maskNonCode(source, language.toLowerCase());
    final escaped = RegExp.escape(symbol.name);
    final isIdentifier = RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(symbol.name);
    final pattern = RegExp(escaped);
    final usages = <EditorSymbolUsage>[];
    var line = 1;
    var lineStart = 0;
    for (final match in pattern.allMatches(searchable)) {
      if (isIdentifier) {
        final before = match.start > 0 ? searchable[match.start - 1] : '';
        final after = match.end < searchable.length ? searchable[match.end] : '';
        final identifierChar = RegExp(r'^[A-Za-z0-9_$]$');
        if ((before.isNotEmpty && identifierChar.hasMatch(before)) ||
            (after.isNotEmpty && identifierChar.hasMatch(after))) {
          continue;
        }
      }
      while (lineStart < match.start) {
        final newline = searchable.indexOf('\n', lineStart);
        if (newline == -1 || newline >= match.start) break;
        line++;
        lineStart = newline + 1;
      }
      usages.add(EditorSymbolUsage(
        name: symbol.name,
        line: line,
        offset: match.start,
        isDefinition: match.start == symbol.offset,
      ));
      if (usages.length >= maximumResults) break;
    }
    return usages;
  }

  static List<EditorSymbol> scan(
    String source, {
    String language = '',
    int maximumResults = 300,
  }) {
    if (source.isEmpty || maximumResults <= 0) return const [];
    final searchableSource = _maskNonCode(source, language.toLowerCase());
    final symbols = <EditorSymbol>[];
    final seen = <String>{};
    var offset = 0;
    final lines = searchableSource.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      for (final entry in _patterns) {
        final match = entry.pattern.firstMatch(line);
        if (match == null) continue;
        final name = match.group(1);
        if (name == null || name.isEmpty) continue;
        final key = '${entry.kind}:$name';
        if (!seen.add(key)) break;
        symbols.add(EditorSymbol(name: name, kind: entry.kind, line: i + 1, offset: offset + match.start(1)));
        break;
      }
      offset += line.length + 1;
      if (symbols.length >= maximumResults) break;
    }
    return symbols;
  }
}
