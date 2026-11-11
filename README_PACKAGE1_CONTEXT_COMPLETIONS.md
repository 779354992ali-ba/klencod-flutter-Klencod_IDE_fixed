# Package 1 — Context-aware completions

This update extends the existing lightweight completion dialog with cursor-context candidates for HTML and CSS.

## HTML
- Typing `<` offers common semantic and structural element names.
- Typing a space inside an opening tag (for example `<img `) offers common attributes such as `src`, `alt`, `class`, `id`, ARIA labels, and form attributes.

## CSS
- Inside a declaration block, the completion dialog offers common CSS properties.
- After selected properties such as `display`, `position`, `flex-direction`, `text-align`, and `overflow`, it offers values relevant to that property.
- Other property values receive a small generic fallback set.

## Implementation
- `lib/core/services/editor_completion_engine.dart`: pure context detection and suggestion lists.
- `lib/main.dart`: passes the source text before the cursor into the existing ranking pipeline.
- `test/editor_completion_engine_test.dart`: tests HTML tag/attribute and CSS property/value contexts.

These are lexical editing suggestions, not a full HTML/CSS language server, validator, or compiler. Flutter/Dart tests and APK builds were not run in the available environment because the Flutter and Dart executables are not installed.
