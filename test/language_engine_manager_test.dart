import 'package:flutter_test/flutter_test.dart';
import 'package:bisho_ide/core/services/language_engine_manager.dart';

void main() {
  group('LanguageEngineManager', () {
    test('routes HTML files to the local project preview', () {
      expect(
        LanguageEngineManager.engineForFile('index.html'),
        LanguageEngine.webProject,
      );
    });

    test('routes web source and document formats to preview', () {
      for (final file in [
        'app.js',
        'site.css',
        'icon.svg',
        'guide.md',
        'data.xml',
        'config.yaml',
        'config.yml',
      ]) {
        expect(
          LanguageEngineManager.engineForFile(file),
          LanguageEngine.webCode,
          reason: file,
        );
      }
    });

    test('routes JSON to its structured viewer', () {
      expect(
        LanguageEngineManager.engineForFile('data.json'),
        LanguageEngine.jsonViewer,
      );
    });

    test('does not claim TypeScript has an execution engine yet', () {
      expect(
        LanguageEngineManager.engineForFile('app.ts'),
        LanguageEngine.unsupported,
      );
      expect(
        LanguageEngineManager.engineForFile('app.tsx'),
        LanguageEngine.unsupported,
      );
    });


    test('detects editor languages from common source extensions', () {
      final expected = <String, String>{
        'main.dart': 'Dart',
        'script.pyw': 'Python',
        'module.mjs': 'JavaScript',
        'types.tsx': 'TypeScript',
        'Main.kt': 'Kotlin',
        'main.rs': 'Rust',
        'server.go': 'Go',
        'header.hpp': 'C++',
        'header.h': 'C',
        'view.xhtml': 'XML',
        'notes.mdown': 'Markdown',
      };
      for (final entry in expected.entries) {
        expect(LanguageEngineManager.languageForFile(entry.key), entry.value,
            reason: entry.key);
      }
    });

    test('separates editing recognition from actual execution support', () {
      expect(LanguageEngineManager.languageForFile('app.ts'), 'TypeScript');
      expect(LanguageEngineManager.hasExecutionEngine('app.ts'), isFalse);
      expect(LanguageEngineManager.hasExecutionEngine('app.js'), isTrue);
      expect(LanguageEngineManager.hasExecutionEngine('main.py'), isFalse);
      expect(LanguageEngineManager.hasStructuralDiagnostics('main.py'), isTrue);
    });

    test('handles paths, hidden files and unknown extensions safely', () {
      expect(LanguageEngineManager.languageForFile('/src/lib/main.dart'), 'Dart');
      expect(LanguageEngineManager.languageForFile('.gitignore'), isNull);
      expect(LanguageEngineManager.languageForFile('file.unknown'), isNull);
    });

    test('matches extensions without case sensitivity', () {
      expect(
        LanguageEngineManager.engineForFile('README.MD'),
        LanguageEngine.webCode,
      );
    });
  });
}
