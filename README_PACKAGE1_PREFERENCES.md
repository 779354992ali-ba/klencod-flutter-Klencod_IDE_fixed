# Bisho IDE – Editor Preferences Update

## Included in this update

- Editor font size is now restored after restarting the app (10–24 px range).
- Explorer visibility is restored after restarting the app.
- Bottom problems-panel visibility and its last resized height are restored.
- Preference writes are best-effort: a storage failure does not block editing or other IDE actions.
- Existing SAF project access, tabs, previews, editor assistance, and language handling are retained.

## Validation notes

- Source changes were reviewed and the package archive was integrity-checked.
- Flutter/Dart SDK is not installed in the packaging environment, so `flutter test`, `dart analyze`, and APK compilation were not run.
