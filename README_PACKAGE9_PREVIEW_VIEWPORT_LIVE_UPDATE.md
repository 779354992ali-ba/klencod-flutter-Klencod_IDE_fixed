# Bisho IDE — Package 9: Preview Viewport and Incremental HTML Refresh

## What's included

- The phone-landscape, tablet, and desktop presets now set an actual fixed WebView layout width (844, 768, and 1280 CSS pixels respectively), rather than changing only the viewport meta tag.
- Wide preview sizes are hosted in a horizontal scroll surface so they remain usable on a narrow phone display.
- The responsive phone preset continues to use the available device width.
- When the preview widget receives updated HTML while retaining the same project and HTML file, the preview writes and reloads only that HTML file instead of copying every project asset again.
- HTML-only refreshes are debounced and serialized; stale queued updates are ignored. A full project reload remains available to synchronize CSS, images, scripts, and other assets from SAF.
- Switching the project or HTML file triggers a full project synchronization.

## Important behavior and limits

- The preview still uses the Android WebView and the existing local temporary project copy.
- Device presets simulate CSS viewport width, not complete physical device hardware, pixel density, browser chrome, or exact device height.
- HTML-only updates do not re-copy changed CSS, JavaScript, images, or other project assets. Use the full reload action after changing those files.
- The incremental update path is activated when the parent supplies a rebuilt `HtmlPreviewScreen` with new `htmlCode`; it does not establish a live connection to an editor controller by itself.
- No new runtime, compiler, or external service was added.

## Validation

The source was reviewed and the generated ZIP archive was checked for structural integrity and preservation of the previous package files. Flutter/Dart executables are not available in the build environment, so `flutter analyze`, `flutter test`, and APK assembly were not run.
