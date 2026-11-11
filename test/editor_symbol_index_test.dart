import 'package:flutter_test/flutter_test.dart';
import 'package:bisho_ide/core/services/editor_symbol_index.dart';

void main() {
  group('EditorSymbolIndex', () {
    test('indexes common declarations and keeps exact line offsets', () {
      const source = 'class Cart {}\n\nconst total = 4;\nfunction checkout() {}\ndef render_page():\n    pass';
      final symbols = EditorSymbolIndex.scan(source);
      expect(symbols.map((s) => s.name), containsAll(['Cart', 'total', 'checkout', 'render_page']));
      expect(symbols.first.line, 1);
      expect(symbols.first.offset, 6);
      expect(symbols.last.line, 5);
    });

    test('indexes markup tags and CSS selectors', () {
      final html = EditorSymbolIndex.scan('<main>\n<section>');
      expect(html.map((s) => s.name), containsAll(['main', 'section']));
      final css = EditorSymbolIndex.scan('.card {\n#header {');
      expect(css.map((s) => s.name), containsAll(['.card', '#header']));
    });

    test('deduplicates symbols and respects result limit', () {
      final symbols = EditorSymbolIndex.scan('class A {}\nclass A {}\nclass B {}', maximumResults: 1);
      expect(symbols, hasLength(1));
    });

    test('ignores declarations inside comments and quoted strings', () {
      const source = '''// class Hidden {}
class Visible {}
const message = "function fake() {}";
/*
class AlsoHidden {}
*/
function realWork() {}''';
      final symbols = EditorSymbolIndex.scan(source, language: 'JavaScript');
      expect(symbols.map((s) => s.name), containsAll(['Visible', 'realWork']));
      expect(symbols.map((s) => s.name), isNot(contains('Hidden')));
      expect(symbols.map((s) => s.name), isNot(contains('fake')));
      expect(symbols.map((s) => s.name), isNot(contains('AlsoHidden')));
    });

    test('recognizes Rust, Kotlin, Swift and Go declarations', () {
      const source = 'fn calculate() {}\nfun render() {}\nfunc draw() {}\ntype Store struct {}';
      final symbols = EditorSymbolIndex.scan(source);
      expect(symbols.map((s) => s.name), containsAll(['calculate', 'render', 'draw', 'Store']));
    });

    test('finds code usages but skips comments and strings', () {
      const source = '''function calculate() {}
// calculate() is mentioned here
const label = "calculate";
calculate();
const result = calculate();''';
      final symbol = EditorSymbolIndex.scan(source, language: 'JavaScript').first;
      final usages = EditorSymbolIndex.findUsages(source, symbol, language: 'JavaScript');
      expect(usages.map((usage) => usage.line), [1, 4, 5]);
      expect(usages.first.isDefinition, isTrue);
      expect(usages.skip(1).every((usage) => !usage.isDefinition), isTrue);
    });

    test('finds punctuation-based selector usages literally', () {
      const source = '.card { color: red; }\n.card:hover { color: blue; }';
      final symbol = EditorSymbolIndex.scan(source, language: 'CSS').first;
      final usages = EditorSymbolIndex.findUsages(source, symbol, language: 'CSS');
      expect(usages, hasLength(2));
      expect(usages.first.isDefinition, isTrue);
    });

    test('uses language-aware hash comments without hiding CSS selectors', () {
      final python = EditorSymbolIndex.scan('# class Hidden\nclass Visible:', language: 'Python');
      expect(python.map((s) => s.name), ['Visible']);
      final css = EditorSymbolIndex.scan('#header {', language: 'CSS');
      expect(css.map((s) => s.name), ['#header']);
    });
  });
}
