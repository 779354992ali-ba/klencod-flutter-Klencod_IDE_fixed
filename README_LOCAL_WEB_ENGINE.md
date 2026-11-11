# Bisho IDE – Local Web Engine / Package 1 Work Log

This archive continues the supplied Bisho IDE Flutter project. It does not create a new project.

## Preserved functionality

- Existing Flutter code editor, syntax highlighting, tabs, explorer, and project creation flow.
- Existing Storage Access Framework (SAF) file and directory operations.
- Existing local HTML WebView preview and resource-copying implementation.
- Existing JavaScript runner and CSS/SVG/JSON preview routes.

## Local preview improvements in this package

- Markdown is rendered locally with the Dart `markdown` package.
- XML is parsed locally with the Dart `xml` package and pretty-printed when valid.
- YAML is parsed locally with the Dart `yaml` package for syntax validation.
- JSON is parsed locally and pretty-printed when valid.
- JavaScript console capture includes log/info/warn/error/debug/trace and unhandled errors.
- The JavaScript output list is capped to the latest 500 messages.
- JavaScript is disabled in the WebView for non-JavaScript preview modes.
- Search and replace are available in the active editor tab. Search starts at the current cursor and wraps to the beginning.
- Project-wide text search traverses SAF directories recursively, opens matching files, and selects the first matching text.

## Safety and limits

- TypeScript (`.ts`/`.tsx`) is deliberately not advertised as executable. Syntax highlighting is not a TypeScript compiler. A genuine offline compiler/runtime integration is still required.
- Python, Lua, SQL execution, Dart execution, and Flutter build/run engines are not included by this package.
- Project-wide search is intentionally bounded to 500 eligible files, 1 MiB per file, and 200 matching files to reduce memory and UI pressure. It searches common text/code extensions and skips unreadable/oversized files.
- XML/YAML/JSON support here is validation and readable preview, not a full visual tree editor with collapsible nodes.

## Dependencies

The local preview dependencies are declared in `pubspec.yaml`: `markdown`, `xml`, and `yaml`. They are Dart/Flutter packages and do not require an API key or hosted service at runtime.

## Verification status

- ZIP integrity: checked after packaging.
- Source-level review: performed for changed files.
- Flutter analyze, Dart tests, Android build, and on-device runtime tests: not run in this environment because Flutter/Dart SDK and an Android build environment are unavailable here.


## Editor assistance update

The editor now adds indentation on a newly typed newline, supports a two-line block layout when Enter is pressed between matching delimiters, skips an existing closer instead of duplicating it, and removes the paired closer when Backspace removes its opener. See `lib/core/services/editor_editing_assist.dart` and its unit tests. This is an editing aid only; it does not add a language runtime.
