# Bisho IDE — Lightweight Syntax Diagnostics

This package adds a dependency-free structural delimiter checker to the editor's Problems panel.

## What it checks
- Unmatched opening parentheses, square brackets, and braces.
- Unexpected closing delimiters and mismatched delimiter types.
- Source line and column for each reported delimiter issue.
- Ignores delimiters inside common quoted strings, line comments, block comments, Python triple-quoted strings, and HTML/XML comments.
- Runs for the common source languages listed in `editor_syntax_diagnostics.dart`.
- Existing JSON, XML, and YAML parser validation remains in place.

## Important limitation
This is a lightweight editor aid, not a compiler, language server, type checker, or full parser. In particular, language-specific constructs such as JavaScript regular-expression literals, nested language interpolation, and some raw-string syntaxes can require a full language parser. A clean result does not prove that a program compiles or runs.

## Added files
- `lib/core/services/editor_syntax_diagnostics.dart`
- `test/editor_syntax_diagnostics_test.dart`

## Updated file
- `lib/main.dart` — integrates structural diagnostics into the existing Problems panel.

Flutter/Dart tests must be run in an environment with the Flutter SDK. They were not executed while preparing this package because the SDK was unavailable.
