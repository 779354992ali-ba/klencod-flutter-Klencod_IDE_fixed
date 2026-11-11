# Bisho IDE — Language Capability Registry

This package improves language recognition and capability reporting without pretending that an editor grammar is a compiler.

## What changed

- Added a central file-extension registry with language identity and explicit capability flags.
- Added safe extension extraction for paths, mixed-case extensions, hidden files, and extensionless names.
- Added mappings for common variants such as `.pyw`, `.pyi`, `.mjs`, `.cjs`, `.tsx`, `.kts`, `.cxx`, `.hpp`, `.xhtml`, and `.mdown`.
- Kept editor recognition separate from preview/runtime routing. TypeScript/TSX are recognized as TypeScript source, but are still not executable.
- Expanded the structural delimiter checker to recognize Ruby, Perl, R, C#, and Scala comment conventions in addition to the existing supported languages.
- Added tests for extension recognition, capability separation, paths, and added comment-aware diagnostics.

## Honest support boundaries

The existing `highlight` package and editor language map provide syntax coloring for the language modes already registered in `main.dart` (Dart, Python, JavaScript, TypeScript, Java, Kotlin, Swift, C/C++, CSS, XML/HTML, JSON, SQL, Bash, Go, Rust, PHP, YAML, and Markdown).

Structural diagnostics are lexical delimiter checks, not compiler diagnostics. They do not type-check code, resolve imports, validate APIs, or guarantee grammar correctness.

The actual local runtime remains limited to the existing web preview/runner features: HTML project preview, JavaScript in WebView (not Node.js), CSS/SVG preview, Markdown rendering, and JSON/XML/YAML data viewing/validation. Java, Kotlin, Swift, C/C++, Go, Rust, Dart, Python, PHP, SQL, and TypeScript do not gain executable compilers/interpreters in this package.

A genuinely universal local engine is not a single dependency: each language requires its own runtime/compiler, target architecture support, packaging, sandboxing, and validation. This package deliberately does not claim those capabilities.
