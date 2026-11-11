# Bisho IDE — Language Lexer Improvements

This update strengthens the lightweight structural scanner used by the editor. It does not claim to add compiler or runtime support.

## Implemented

- Nested block-comment handling for Rust, Kotlin, and Swift.
- Rust raw-string handling, including hash-delimited and byte raw-string prefixes.
- C++ raw-string handling with custom delimiters (up to the language's 16-character delimiter bound).
- Added regression tests ensuring brackets inside these lexical regions are ignored.

## Scope and limitations

The scanner still checks delimiter structure only. It is not a complete lexer/parser, type checker, formatter, language server, compiler, or interpreter. In particular, JavaScript regular-expression literals, language-specific preprocessor branches, macro expansion, and all dialect-specific quoting rules are not fully modeled. A file being recognized or highlighted does not mean it can execute.

Execution remains limited to the project's existing local web features. Dart, Python, Java, Kotlin, Swift, C/C++, Go, Rust, PHP, SQL, and TypeScript require separately packaged and tested runtimes/compilers before they can be advertised as runnable.
