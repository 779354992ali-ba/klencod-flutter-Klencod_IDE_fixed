# Bisho IDE — Matching Bracket Navigation

This package adds a toolbar action that moves the editor caret to the matching
parenthesis, square bracket, or brace around the current cursor. It scans nested
delimiters and skips common strings and comments for supported source languages.

## Files
- Added `lib/core/services/editor_bracket_matcher.dart`.
- Added `test/editor_bracket_matcher_test.dart`.
- Updated `lib/main.dart` with the toolbar action and status feedback.

## Scope and limitations
This is a lightweight lexical matcher, not a complete language parser. It handles
common quoted strings and line/block/HTML comments, but language-specific raw
strings, interpolation, and JavaScript regular-expression literals can require
full language parsers. It does not change the status of TypeScript, Dart, or
Node.js runtime support.

Flutter tests were added but not executed because the Flutter/Dart SDK is not
available in the preparation environment.
