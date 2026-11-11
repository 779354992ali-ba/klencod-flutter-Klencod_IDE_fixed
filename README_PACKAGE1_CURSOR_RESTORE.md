# Bisho IDE – Per-tab Cursor Restoration

## Included

- Persists each tab's selection base and extent offsets alongside its recovery snapshot.
- Restores the caret or selected range independently for every tab after app restart.
- Clamps stored offsets to the restored document length to avoid invalid selections when older snapshots or changed content are encountered.
- Continues to read older recovery snapshots, including the legacy `cursorOffset` field when present.
- Debounces persistence after cursor/selection movement as well as text edits.
- Keeps cursor movement from marking a document as modified.

## Validation

- Reviewed the changed editor-tab creation, recovery deserialization, controller listener, and snapshot serialization paths.
- Verified the ZIP archive and compared its entries with the previous complete package to ensure no prior files were dropped.
- Flutter/Dart SDK is unavailable in this packaging environment; `flutter test`, `dart analyze`, and APK compilation were not run.
