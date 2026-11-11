# Bisho IDE — Package 6: Symbol Index Hardening

This package improves the file-local symbol navigator without introducing a compiler or language server.

## Changes
- Masks line comments, block comments, HTML/XML comments, and quoted strings before scanning declarations. The masking preserves source length and newline positions so symbol offsets and line numbers remain aligned with the original file.
- Uses the active tab language when scanning, allowing Python/Bash/YAML-style `#` comments to be ignored without treating CSS ID selectors as comments.
- Adds lightweight declaration patterns for Rust `fn`, Kotlin `fun`, Swift `func`, Go `func` and `type Name struct/interface`, plus common `struct`, `union`, and `record` declarations.
- Adds regression tests for false symbols in comments/strings, language-specific declarations, hash comments, and CSS selectors.

## Scope and limitations
The index is still lexical and file-local. It is not a parser, compiler, LSP, cross-file symbol resolver, or guaranteed complete index. Complex multiline declarations, macros, conditional compilation, and language-specific raw-string edge cases may not be fully understood.

## Validation
The source and test changes were reviewed and the package archive was integrity-checked. Flutter/Dart executables are not available in the build environment, so `flutter test` and APK compilation were not run.
