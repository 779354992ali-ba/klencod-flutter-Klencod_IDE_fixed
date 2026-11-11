# Bisho IDE — Editor Line Actions

This package adds four native editor operations while keeping the existing project structure and engines:

- Duplicate the current line or selected lines.
- Move the current line up or down while keeping the cursor column.
- Toggle line comments for Dart, JavaScript, TypeScript, Java, Kotlin, Swift, C/C++, Go, Rust, PHP, SQL, Python, Bash, YAML, CSS, HTML, XML, and Markdown.
- Use proper paired comment delimiters for CSS and markup languages.

Implementation:
- `lib/core/services/editor_line_actions.dart` contains pure text transformations.
- `lib/main.dart` exposes the operations in the editor toolbar and routes the results through the existing controller/history/autosave listener.
- `test/editor_line_actions_test.dart` covers duplication, movement, comment toggling, markup delimiters, and document boundaries.

The project still uses the previously documented local execution engines. This package does not claim to add a TypeScript compiler, Node.js runtime, or Dart VM.

Validation note: Flutter/Dart executables are not available in the packaging environment, so the Flutter test suite and APK build could not be run. The archive itself was checked for integrity and required project files.
