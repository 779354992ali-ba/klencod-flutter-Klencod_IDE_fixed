# Bisho IDE — Package 7: Symbol Usage Navigation

## Added
- Added a file-local lexical usage search for indexed symbols.
- Usage search ignores comments and quoted text using the existing language-aware masking pass.
- Identifier matching checks complete identifier boundaries; punctuation-based CSS selectors are matched literally.
- Added an editor action that lets the user choose a known symbol, inspect its definition and references, and jump to the selected occurrence.
- Added regression tests for JavaScript comments/strings and CSS selector occurrences.

## Scope and limitations
- Search is limited to the active file. It does not perform project-wide or cross-file reference analysis.
- Results are lexical matches, not semantic references. Shadowed variables, overloads, imports, and language-specific scopes are not resolved.
- No rename operation is included, to avoid unsafe text-wide edits.
- Flutter/Dart tests and APK build were not run in this environment because Flutter and Dart executables are unavailable.
