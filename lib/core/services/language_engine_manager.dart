/// Runtime routing and language capability registry.
///
/// Editing/highlighting support is deliberately separate from execution:
/// recognizing a source file never implies that Bisho can compile or run it.
enum LanguageEngine {
  webProject,
  webCode,
  jsonViewer,
  unsupported,
}

class LanguageCapabilities {
  const LanguageCapabilities({
    required this.language,
    required this.extensions,
    required this.syntaxHighlighting,
    required this.structuralDiagnostics,
    required this.executionEngine,
    this.note = '',
  });

  final String language;
  final List<String> extensions;
  final bool syntaxHighlighting;
  final bool structuralDiagnostics;
  final bool executionEngine;
  final String note;
}

class LanguageEngineManager {
  const LanguageEngineManager._();

  static const List<LanguageCapabilities> capabilities = [
    LanguageCapabilities(language: 'Dart', extensions: ['dart'], syntaxHighlighting: true, structuralDiagnostics: true, executionEngine: false, note: 'تحرير وفحص بنيوي؛ لا يوجد مترجم Dart مضمّن.'),
    LanguageCapabilities(language: 'Python', extensions: ['py', 'pyw', 'pyi'], syntaxHighlighting: true, structuralDiagnostics: true, executionEngine: false, note: 'تحرير وفحص بنيوي؛ لا يوجد مفسر Python مضمّن.'),
    LanguageCapabilities(language: 'JavaScript', extensions: ['js', 'mjs', 'cjs'], syntaxHighlighting: true, structuralDiagnostics: true, executionEngine: true, note: 'تنفيذ JavaScript داخل WebView؛ ليس Node.js.'),
    LanguageCapabilities(language: 'TypeScript', extensions: ['ts', 'tsx'], syntaxHighlighting: true, structuralDiagnostics: true, executionEngine: false, note: 'تلوين وفحص بنيوي فقط؛ يلزم مترجم TypeScript قبل التشغيل.'),
    LanguageCapabilities(language: 'Java', extensions: ['java'], syntaxHighlighting: true, structuralDiagnostics: true, executionEngine: false),
    LanguageCapabilities(language: 'Kotlin', extensions: ['kt', 'kts'], syntaxHighlighting: true, structuralDiagnostics: true, executionEngine: false),
    LanguageCapabilities(language: 'Swift', extensions: ['swift'], syntaxHighlighting: true, structuralDiagnostics: true, executionEngine: false),
    LanguageCapabilities(language: 'C', extensions: ['c', 'h'], syntaxHighlighting: true, structuralDiagnostics: true, executionEngine: false),
    LanguageCapabilities(language: 'C++', extensions: ['cc', 'cpp', 'cxx', 'hh', 'hpp', 'hxx'], syntaxHighlighting: true, structuralDiagnostics: true, executionEngine: false),
    LanguageCapabilities(language: 'Go', extensions: ['go'], syntaxHighlighting: true, structuralDiagnostics: true, executionEngine: false),
    LanguageCapabilities(language: 'Rust', extensions: ['rs'], syntaxHighlighting: true, structuralDiagnostics: true, executionEngine: false),
    LanguageCapabilities(language: 'PHP', extensions: ['php', 'phtml'], syntaxHighlighting: true, structuralDiagnostics: true, executionEngine: false),
    LanguageCapabilities(language: 'CSS', extensions: ['css'], syntaxHighlighting: true, structuralDiagnostics: true, executionEngine: true),
    LanguageCapabilities(language: 'HTML', extensions: ['html', 'htm'], syntaxHighlighting: true, structuralDiagnostics: true, executionEngine: true),
    LanguageCapabilities(language: 'XML', extensions: ['xml', 'xhtml', 'xsd', 'xsl'], syntaxHighlighting: true, structuralDiagnostics: true, executionEngine: false),
    LanguageCapabilities(language: 'SVG', extensions: ['svg'], syntaxHighlighting: true, structuralDiagnostics: true, executionEngine: true),
    LanguageCapabilities(language: 'JSON', extensions: ['json'], syntaxHighlighting: true, structuralDiagnostics: true, executionEngine: false),
    LanguageCapabilities(language: 'YAML', extensions: ['yaml', 'yml'], syntaxHighlighting: true, structuralDiagnostics: true, executionEngine: false),
    LanguageCapabilities(language: 'SQL', extensions: ['sql'], syntaxHighlighting: true, structuralDiagnostics: true, executionEngine: false),
    LanguageCapabilities(language: 'Bash', extensions: ['sh', 'bash', 'zsh'], syntaxHighlighting: true, structuralDiagnostics: true, executionEngine: false),
    LanguageCapabilities(language: 'Markdown', extensions: ['md', 'markdown', 'mdown'], syntaxHighlighting: true, structuralDiagnostics: false, executionEngine: false),
    LanguageCapabilities(language: 'Plain Text', extensions: ['txt', 'log'], syntaxHighlighting: false, structuralDiagnostics: false, executionEngine: false),
  ];

  static String extensionOf(String fileName) {
    final name = fileName.replaceAll('\\', '/').split('/').last;
    final dot = name.lastIndexOf('.');
    return dot <= 0 || dot == name.length - 1
        ? ''
        : name.substring(dot + 1).toLowerCase();
  }

  static LanguageCapabilities? capabilitiesForFile(String fileName) {
    final extension = extensionOf(fileName);
    for (final item in capabilities) {
      if (item.extensions.contains(extension)) return item;
    }
    return null;
  }

  static String? languageForFile(String fileName) =>
      capabilitiesForFile(fileName)?.language;

  static bool hasStructuralDiagnostics(String fileName) =>
      capabilitiesForFile(fileName)?.structuralDiagnostics ?? false;

  static bool hasExecutionEngine(String fileName) =>
      capabilitiesForFile(fileName)?.executionEngine ?? false;

  static LanguageEngine engineForFile(String fileName) {
    switch (extensionOf(fileName)) {
      case 'html':
      case 'htm':
        return LanguageEngine.webProject;
      case 'js':
      case 'mjs':
      case 'cjs':
      case 'css':
      case 'svg':
      case 'md':
      case 'markdown':
      case 'mdown':
      case 'xml':
      case 'xhtml':
      case 'xsd':
      case 'xsl':
      case 'yaml':
      case 'yml':
        return LanguageEngine.webCode;
      case 'json':
        return LanguageEngine.jsonViewer;
      default:
        return LanguageEngine.unsupported;
    }
  }

  static String? webModeForFile(String fileName) {
    switch (extensionOf(fileName)) {
      case 'js':
      case 'mjs':
      case 'cjs':
        return 'javascript';
      case 'css':
        return 'css';
      case 'svg':
        return 'svg';
      case 'md':
      case 'markdown':
      case 'mdown':
        return 'markdown';
      case 'xml':
      case 'xhtml':
      case 'xsd':
      case 'xsl':
        return 'xml';
      case 'yaml':
      case 'yml':
        return 'yaml';
      default:
        return null;
    }
  }
}
