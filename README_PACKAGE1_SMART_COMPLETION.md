# Bisho IDE — Smart Local Completion

This package adds a lightweight, offline completion-ranking service to the existing editor.

## Changes
- Adds `lib/core/services/editor_completion_engine.dart` with built-in keyword suggestions for Dart, JavaScript, TypeScript, Python, HTML, CSS, and SQL.
- Ranks exact prefix matches first, then word-boundary matches, substring matches, and finally subsequence matches.
- Removes duplicate suggestions and keeps stable ordering within each relevance group.
- Integrates the ranking service into the existing completion dialog without changing the existing snippet insertion workflow.
- Displays an explicit empty state when no candidate matches the typed prefix.
- Adds unit tests in `test/editor_completion_engine_test.dart`.

## Scope and limitations
This is local lexical completion, not semantic IntelliSense, a compiler, or a language server. It does not resolve project symbols, imports, types, or runtime APIs. TypeScript and Dart execution support is unchanged.

## Validation
The ZIP archive was checked for integrity and the project file set was compared with the previous Bracket Navigation package. Flutter/Dart tests and APK builds were not run because the Flutter and Dart SDK executables are unavailable in the build environment.
