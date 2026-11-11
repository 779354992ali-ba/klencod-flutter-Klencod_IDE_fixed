# Bisho IDE – Tab Auto-Recovery Update

## Included

- Automatically snapshots open-tab contents after a short pause in typing (650 ms).
- Saves the active tab index when switching between tabs.
- Flushes pending tab state when the app becomes inactive, paused, or detached.
- Serializes overlapping preference writes and schedules a follow-up save when edits arrive during a write.
- Keeps recovery writes best-effort so storage errors do not interrupt editing.
- Retains the existing SAF, editor, preview, editing-assist, and preference features.

## Validation

- Reviewed the changed Dart source and verified the new lifecycle observer, debounce, and save hooks are present.
- Flutter/Dart SDK is unavailable in the packaging environment; `flutter test`, `dart analyze`, and APK compilation were not run.
