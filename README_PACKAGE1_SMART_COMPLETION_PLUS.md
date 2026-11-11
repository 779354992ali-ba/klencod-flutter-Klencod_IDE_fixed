# Bisho IDE — Project-aware completion improvements

This update improves the existing local lexical completion engine without claiming semantic IntelliSense or a language server.

## Changes

- Completion suggestions now include identifiers already used in the current source file.
- The identifier scanner skips common quoted strings and line/block comments, including Python triple-quoted strings, HTML/XML comments, and SQL `--` comments.
- Completion results are bounded (50 in the editor) to keep the suggestion dialog responsive on mobile devices.
- Identifier scanning reuses compiled regular expressions instead of constructing them for every character.
- Corrected leading whitespace in several built-in keywords (`Future`, `finally`, and `keyof`) so prefix matching works as intended.
- Existing snippet and keyword suggestions remain available.

## Important limitation

This is source-local lexical completion. It does not resolve types, imports, scopes, members, overloads, or project-wide symbols and is not a substitute for a compiler, language server, or semantic IntelliSense.

## Validation

New unit tests cover local identifier extraction, skipping strings/comments, Python triple-quoted strings, SQL line comments, and result limits. Flutter/Dart test execution was not possible in the build environment because the Flutter and Dart executables are unavailable.
