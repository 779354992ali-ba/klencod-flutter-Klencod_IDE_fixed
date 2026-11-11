# Package 2 — File Symbol Navigation

This update adds a lightweight, file-local symbol index and a navigation dialog to Bisho IDE.

## Included
- Indexes common class, interface, type, function, method, and variable declarations.
- Recognizes basic HTML opening tags and CSS class/id selectors.
- Displays the symbol kind and source line in an editor dialog.
- Moves the active editor tab and caret to the selected declaration.
- Includes unit tests for declarations, offsets, markup, selectors, deduplication, and result limits.

## Scope and limitations
This is a lexical, line-oriented index. It is not a full parser, language server, or semantic symbol resolver. Nested declarations, multiline signatures, and complex language grammar may not be indexed. Existing editor features and local execution engines remain unchanged.

## Verification
The ZIP archive is checked for integrity and prior-package file retention. Flutter/Dart tests and APK builds require the Flutter SDK and are not claimed as executed in this environment.
